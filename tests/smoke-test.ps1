# Detect the project root: script lives in tests/, so go up one level
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$checks = @(
    "README.md",
    "LICENSE",
    ".gitignore",
    "CHANGELOG.md",
    "scripts\run_codex_task.ps1",
    "scripts\run_project_task.ps1",
    "docs\architecture.md",
    "docs\safety.md",
    "docs\oss-application-notes.md",
    "examples\task-chinese.md",
    "examples\task-project.md",
    "examples\openclaw-command-example.md"
)

$missing = @()

foreach ($check in $checks) {
    if (-not (Test-Path -LiteralPath $check -PathType Leaf)) {
        $missing += $check
    }
}

if ($missing.Count -gt 0) {
    Write-Host "Smoke test failed. Missing files:"
    foreach ($item in $missing) {
        Write-Host "- $item"
    }
    exit 1
}

Write-Host "Smoke test passed."
