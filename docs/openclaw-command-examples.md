# OpenClaw Command Examples

## Purpose

This document shows example command patterns for using OpenClaw with OpenClaw Codex Bridge.

It is not a full OpenClaw plugin. It does not include OpenClaw source code, n8n workflows, Telegram bot setup, account configuration, tokens, or deployment steps.

The goal is to show how OpenClaw can safely delegate a small, auditable task to Codex Bridge without turning user chat text into a direct shell command.

## Basic Flow

The safe delegation flow is:

1. User sends a message to OpenClaw.
2. OpenClaw creates a task file such as `tasks/task-013.md`.
3. Codex Bridge runs Codex CLI with the task file content.
4. Codex writes a result file such as `results/task-013-result.md`.
5. OpenClaw verifies the result before showing it to the user or taking any next action.

OpenClaw should pass only a validated task id, such as `task-013`, to the bridge script. It should not pass arbitrary PowerShell text from Telegram, LINE, a web form, or any remote chat source.

## Safe Read-Only Task Example

A read-only task is the default and safest mode. Use it when Codex only needs to inspect files and report findings.

Example user request:

```text
Inspect this project and summarize the top-level file structure.
Do not modify files.
```

Example task file created by OpenClaw:

```markdown
# Task: Inspect project structure

Please inspect the current repository structure.
Summarize the main folders and important files.
Do not modify, delete, move, rename, or create any files.
Do not read secrets or environment files.
```

Example bridge command:

```powershell
.\scripts\run_codex_task.ps1 -TaskId task-013
```

Expected result:

- `results/task-013-result.md` exists.
- The result summarizes the repository structure.
- No project files were changed.

## Project Write Task Example

Use a project write task only when the user clearly asks Codex to modify a specific project directory.

The write boundary must be explicit. Codex should only be allowed to write inside the project directory passed as `-WorkspacePath`.

Example user request:

```text
Add a short documentation link to the README in D:\YourProject.
```

Example task file created by OpenClaw:

```markdown
# Task: Update README documentation link

In the project workspace, update only README.md.
Add one link to the project documentation section.
Do not modify files outside the provided workspace.
Do not modify environment files.
Do not include tokens, passwords, webhook URLs, emails, or account ids.
```

Example bridge command:

```powershell
.\scripts\run_project_task.ps1 `
  -TaskId task-014 `
  -WorkspacePath "D:\YourProject"
```

Important rules:

- `-WorkspacePath` must point to the intended project directory.
- Do not use a system directory, user home directory, desktop, downloads folder, or full disk root as the workspace.
- Do not give write access to unrelated repositories or directories containing secrets.
- Review the result and `git status` before any push or release.

## Verification Checklist

Before OpenClaw treats a task as complete, it should verify:

- The expected result file exists.
- The expected output is present in the result file.
- The result does not contain sensitive data such as API keys, tokens, passwords, webhook secrets, emails, Telegram ids, account ids, or private customer data.
- No unexpected files changed.
- `git status` is clean or contains only the expected files.
- If a push happened in a separate approved workflow, the GitHub page is checked after the push.

Verification should happen before OpenClaw sends a final answer back to the user or starts a follow-up action.

## Unsafe Commands to Avoid

Do not turn Telegram, LINE, web form, or OpenClaw text directly into PowerShell commands.

Avoid patterns like:

```powershell
Invoke-Expression $UserMessage
```

```powershell
powershell -Command $TelegramText
```

```powershell
codex exec $UserMessage
```

Also avoid:

- Passing tokens, passwords, API keys, webhook secrets, emails, Telegram ids, or account ids through task text, command arguments, logs, examples, or committed files.
- Dangerous parameters or modes such as `--yolo`, `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `Invoke-Expression`, or `-EncodedCommand`.
- Full disk write access.
- Write access to user profile folders, system folders, cloud sync folders, browser profile folders, or directories that contain secrets.
- Automatically pushing to GitHub, creating releases, changing scheduled tasks, editing environment variables, or changing account settings without a separate explicit approval step.

The bridge should remain a narrow file-based handoff: validated task id in, fixed result file out, and human or OpenClaw verification before the next action.
