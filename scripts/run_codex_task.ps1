<#
.SYNOPSIS
Run one read-only Codex task from tasks/task-xxx.md.

.DESCRIPTION
This wrapper is the safe default path for OpenClaw Codex Bridge.

It accepts only a task id such as task-009, reads the matching UTF-8 markdown
file from tasks/, runs Codex CLI in non-interactive read-only mode, writes the
final assistant message to results/, and appends operational logs to logs/.

Use scripts/run_project_task.ps1 for tasks that intentionally need project
file writes. Do not open write permissions from this read-only wrapper.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^task-[0-9]{3,}$')]
    [string]$TaskId,

    [Parameter()]
    [string]$RootDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CodexPath = 'codex',

    [Parameter()]
    [ValidateRange(30, 86400)]
    [int]$TimeoutSeconds = 1800
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Resolve-ChildPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseDir,

        [Parameter(Mandatory = $true)]
        [string]$ChildPath
    )

    $baseFullPath = [System.IO.Path]::GetFullPath($BaseDir)
    $targetFullPath = [System.IO.Path]::GetFullPath((Join-Path $baseFullPath $ChildPath))
    $baseWithSeparator = $baseFullPath.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar

    if (
        -not $targetFullPath.Equals($baseFullPath, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $targetFullPath.StartsWith($baseWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        throw "Resolved path escaped the project directory: $ChildPath"
    }

    return $targetFullPath
}

function Quote-WindowsArgument {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Argument
    )

    if ($Argument.Length -eq 0) {
        return '""'
    }

    if ($Argument -notmatch '[\s"]') {
        return $Argument
    }

    $quoted = '"'
    $backslashCount = 0

    foreach ($char in $Argument.ToCharArray()) {
        if ($char -eq '\') {
            $backslashCount++
            continue
        }

        if ($char -eq '"') {
            $quoted += ('\' * (($backslashCount * 2) + 1))
            $quoted += '"'
            $backslashCount = 0
            continue
        }

        if ($backslashCount -gt 0) {
            $quoted += ('\' * $backslashCount)
            $backslashCount = 0
        }

        $quoted += $char
    }

    if ($backslashCount -gt 0) {
        $quoted += ('\' * ($backslashCount * 2))
    }

    $quoted += '"'
    return $quoted
}

function Join-ProcessArguments {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    return (($Arguments | ForEach-Object { Quote-WindowsArgument -Argument $_ }) -join ' ')
}

function Assert-SafeCodexArguments {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $blocked = @(
        '--dangerously-bypass-approvals-and-sandbox',
        '--dangerously-bypass-hook-trust',
        '--yolo',
        '--full-auto',
        'danger-full-access'
    )

    foreach ($argument in $Arguments) {
        foreach ($blockedValue in $blocked) {
            if ($argument.Equals($blockedValue, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Blocked unsafe Codex argument: $argument"
            }
        }
    }
}

function Add-LogLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
    Add-Content -LiteralPath $Path -Value "[$stamp] $Message" -Encoding UTF8
}

function Invoke-CodexExec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds
    )

    Assert-SafeCodexArguments -Arguments $Arguments

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = Join-ProcessArguments -Arguments $Arguments
    $startInfo.WorkingDirectory = $rootFullPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    [void]$process.Start()
    $process.StandardInput.Write($Prompt)
    $process.StandardInput.Close()

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result

        return [pscustomobject]@{
            ExitCode = 124
            TimedOut = $true
            Stdout = $stdout
            Stderr = $stderr
        }
    }

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        TimedOut = $false
        Stdout = $stdoutTask.Result
        Stderr = $stderrTask.Result
    }
}

$rootFullPath = [System.IO.Path]::GetFullPath($RootDir)
$taskPath = Resolve-ChildPath -BaseDir $rootFullPath -ChildPath (Join-Path 'tasks' "$TaskId.md")
$resultPath = Resolve-ChildPath -BaseDir $rootFullPath -ChildPath (Join-Path 'results' "$TaskId-result.md")
$logPath = Resolve-ChildPath -BaseDir $rootFullPath -ChildPath (Join-Path 'logs' "$TaskId.log")

if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) {
    throw "Task file not found: $taskPath"
}

if (Test-Path -LiteralPath $resultPath) {
    throw "Result file already exists. Refusing to overwrite: $resultPath"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resultPath), (Split-Path -Parent $logPath) | Out-Null

$taskText = Get-Content -LiteralPath $taskPath -Raw -Encoding UTF8

$prompt = @"
You are running through OpenClaw Codex Bridge.

Safety mode: read-only.

Rules for this run:
- Do not create, modify, delete, rename, publish, upload, or move files.
- Do not change accounts, credentials, environment variables, scheduled tasks, databases, OpenClaw, or n8n.
- Do not reveal secrets. If a task contains secrets, tell the user to remove them.
- If the task requires project file writes, say it must be run through scripts/run_project_task.ps1 with an explicit workspace.
- Answer in the language requested by the task. Chinese UTF-8 task files are supported.

Task id: $TaskId
Task file: $taskPath

----- task begins -----
$($taskText.Trim())
----- task ends -----
"@

$codexArgs = @(
    'exec',
    '--cd', $rootFullPath,
    '--sandbox', 'read-only',
    '--color', 'never',
    '--skip-git-repo-check',
    '--output-last-message', $resultPath,
    '-'
)

if ($PSCmdlet.ShouldProcess($TaskId, 'Run Codex CLI in read-only non-interactive mode')) {
    Add-LogLine -Path $logPath -Message "Starting read-only task. Result path: $resultPath"
    Add-LogLine -Path $logPath -Message "Codex command: $CodexPath $(Join-ProcessArguments -Arguments $codexArgs)"

    $run = Invoke-CodexExec -FilePath $CodexPath -Arguments $codexArgs -Prompt $prompt -TimeoutSeconds $TimeoutSeconds

    Add-LogLine -Path $logPath -Message "Codex exit code: $($run.ExitCode)"
    if ($run.TimedOut) {
        Add-LogLine -Path $logPath -Message "Codex timed out after $TimeoutSeconds seconds."
    }
    if (-not [string]::IsNullOrWhiteSpace($run.Stdout)) {
        Add-LogLine -Path $logPath -Message "Codex stdout begins."
        Add-Content -LiteralPath $logPath -Value $run.Stdout -Encoding UTF8
        Add-LogLine -Path $logPath -Message "Codex stdout ends."
    }
    if (-not [string]::IsNullOrWhiteSpace($run.Stderr)) {
        Add-LogLine -Path $logPath -Message "Codex stderr begins."
        Add-Content -LiteralPath $logPath -Value $run.Stderr -Encoding UTF8
        Add-LogLine -Path $logPath -Message "Codex stderr ends."
    }

    if ($run.ExitCode -ne 0 -and -not (Test-Path -LiteralPath $resultPath)) {
        $failedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
        $failureResult = @"
# Result for $TaskId

Started through OpenClaw Codex Bridge.

Status: failed
Finished at: $failedAt
Codex exit code: $($run.ExitCode)

The task file was validated, but Codex CLI did not produce a final message.
Check the log file for details:

$logPath
"@
        Set-Content -LiteralPath $resultPath -Value $failureResult -Encoding UTF8
    }

    if ($run.ExitCode -ne 0) {
        throw "Codex CLI failed with exit code $($run.ExitCode). See log: $logPath"
    }

    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        throw "Codex CLI completed but did not write result file: $resultPath"
    }

    Add-LogLine -Path $logPath -Message "Task completed."
    Write-Host "Task completed. Result written to: $resultPath"
}
