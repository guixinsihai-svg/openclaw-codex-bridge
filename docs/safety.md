# Safety Design

This project exists because local AI automation can become risky if chat messages are treated as commands.

The safe design is simple: Telegram should create or reference a task, not control PowerShell.

## Core boundary

OpenClaw Codex Bridge has two execution paths:

- `scripts/run_codex_task.ps1`: default read-only task runner.
- `scripts/run_project_task.ps1`: explicit project workspace-write task runner.

Use the read-only runner first. Use the project-write runner only when a human has reviewed the task and selected a specific workspace path.

## Read-only tasks

Read-only tasks are for inspection, explanation, summarization, planning, and diagnostics.

`run_codex_task.ps1`:

- reads only `tasks/task-xxx.md`,
- runs `codex exec` with `--sandbox read-only`,
- passes the task through UTF-8 standard input,
- writes the final result to `results/task-xxx-result.md`,
- writes operational logs to `logs/task-xxx.log`,
- refuses to overwrite an existing result file.

If a task asks Codex to modify files, the read-only runner should not be used. Create a separate project task and run `run_project_task.ps1` with an explicit workspace.

## Project-write tasks

Project-write tasks are for intentional edits inside one reviewed project directory.

`run_project_task.ps1`:

- requires `-WorkspacePath`,
- runs `codex exec` with `--sandbox workspace-write`,
- sets Codex working directory to the workspace,
- does not pass `--add-dir`,
- does not allow `danger-full-access`,
- does not accept arbitrary shell commands from remote input,
- refuses to overwrite an existing result file.

The wrapper itself still writes result and log files inside this bridge project. Codex-generated file edits should stay inside the workspace passed by the user.

Do not use project-write mode for system folders, user profile roots, credential folders, database folders, or broad directories such as `C:\Users\name`.

## Do not let Telegram send arbitrary PowerShell commands

Telegram messages are untrusted input. A Telegram message must never become a PowerShell command such as:

```powershell
Invoke-Expression $telegramText
powershell.exe -Command $telegramText
Start-Process powershell -ArgumentList $telegramText
```

This is dangerous because one message could delete files, expose secrets, change system settings, or run unexpected programs.

Telegram, OpenClaw, or n8n should pass only a task id like:

```text
task-009
```

Recommended validation pattern:

```text
^task-[0-9]{3,}$
```

Do not allow:

- full file paths from chat,
- relative paths like `..\secret`,
- shell commands,
- command arguments,
- URLs as execution targets,
- base64 encoded commands,
- arbitrary workspace paths from chat without human review.

## Do not directly expose codex.exe to remote input

OpenClaw, n8n, a Telegram bot, or a webhook should not directly call `codex.exe` with user-provided text.

Use the local wrapper scripts instead. The wrapper should validate the task id, read a fixed task file, choose a fixed sandbox mode, and write to a fixed result file.

Do not expose these flags to remote users:

- `--dangerously-bypass-approvals-and-sandbox`
- `--yolo`
- `--full-auto`
- `--sandbox danger-full-access`
- `--add-dir`
- `--ignore-rules`
- `--ignore-user-config`

If a future version adds more options, keep them as local operator choices, not chat-controlled arguments.

## Do not use dangerous PowerShell patterns

Avoid patterns like:

- `Invoke-Expression`
- `-EncodedCommand`
- `-ExecutionPolicy Bypass`
- `Remove-Item -Recurse -Force` from automation input
- `Start-Process` with user-controlled arguments
- any command that builds a shell string from Telegram text

If a command must be added later, use fixed arguments and validate all paths before use.

## Do not commit secrets

Never write these values into code, logs, examples, screenshots, public issues, or committed task files:

- API Key
- Token
- Password
- Telegram Bot Token
- Telegram user id
- email address
- webhook secret
- session cookie
- database password

Use local `.env` files or a secret manager for real deployments. Keep `.env` files out of Git.

The repository `.gitignore` excludes `.env`, `.env.*`, key files, `secrets/`, `tasks/`, `results/`, and `logs/` by default.

## Path safety

The bridge resolves task, result, and log paths under the bridge project directory and rejects paths that escape the project root.

Good:

```text
tasks/task-009.md
results/task-009-result.md
logs/task-009.log
```

Bad:

```text
..\..\Users\name\.ssh\id_rsa
C:\Windows\System32\config
```

For project-write mode, `-WorkspacePath` must be a real directory selected by the local operator. Do not let a remote message choose it freely.

## Recommended execution model

Use this flow:

1. Telegram sends normal text.
2. OpenClaw or n8n creates `tasks/task-009.md`.
3. OpenClaw or n8n calls the bridge with only `task-009`.
4. The bridge validates `task-009`.
5. The bridge reads `tasks/task-009.md` as UTF-8.
6. The bridge runs a controlled local Codex workflow.
7. The bridge writes `results/task-009-result.md`.
8. OpenClaw, n8n, or a human reads the result and log.

## Human approval points

Require human review before any task that:

- deletes files,
- modifies credentials,
- changes environment variables,
- edits scheduled tasks,
- modifies database schema,
- publishes content,
- uploads files,
- logs in to external services,
- creates or changes GitHub repositories,
- opens write access to a project workspace.

## Current script status

The included scripts are MVP templates. They are meant to be readable and conservative, not a complete production job runner.

Before production use, review your local Codex CLI path, authentication, workspace paths, logs, and approval process.
