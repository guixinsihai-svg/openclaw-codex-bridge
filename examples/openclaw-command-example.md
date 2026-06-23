# OpenClaw command handoff example

This example shows the intended command shape. It does not contain real account data, tokens, webhook URLs, or bot ids.

## Safe idea

OpenClaw or n8n should save the full user request into a local task file:

```text
tasks/task-010.md
```

Then it should call the bridge with only the task id:

```powershell
.\scripts\run_codex_task.ps1 -TaskId task-010
```

## Project-write task

If a human has approved a specific project workspace, use:

```powershell
.\scripts\run_project_task.ps1 `
  -TaskId task-012 `
  -WorkspacePath "D:\YourProject"
```

The workspace path should be configured locally by the operator. Do not let Telegram text choose arbitrary paths.

## Unsafe idea

Do not build commands like this:

```powershell
powershell.exe -Command $telegramMessage
codex exec $telegramMessage
Invoke-Expression $telegramMessage
```

Chat text is untrusted input. The bridge should receive a task id, not a shell command.
