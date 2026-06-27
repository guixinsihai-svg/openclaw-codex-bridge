# n8n Workflow Example

## 1. Purpose

This document provides a minimal n8n integration example for the OpenClaw Codex Bridge project. It is **not** a production-ready workflow and should be reviewed thoroughly before any real use.

## 2. Basic Flow

The recommended flow is:

1. An n8n trigger (e.g., Manual Trigger or Webhook) receives a task request.
2. The trigger creates a task-xxx.md file in the `tasks/` directory of the bridge project.
3. The bridge PowerShell script is called to process the task.
4. The result file is read from the `results/` directory.
5. The result is sent back to the user via Telegram, email, or another channel.

## 3. Minimal Node Design

A minimal n8n workflow could consist of the following nodes:

- **Manual Trigger** or **Webhook** node starts the workflow.
- **Set** node builds the task content (e.g., task id and instructions).
- **Write Binary File** or **Execute Command** node creates `tasks/task-xxx.md`.
- **Execute Command** node runs `run_codex_task.ps1` with the task id.
- **Read Binary File** or **Execute Command** node reads `results/task-xxx-result.md`.
- **Telegram** or **Email** node sends the result to the user.

No real API keys, tokens, or credentials should be embedded in the workflow file.

## 4. Example Command

When calling the bridge script, use a command similar to:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\OpenClawCodexBridge\run_codex_task.ps1" task-001
```

**Important:** Replace the path and task id with your own values. The project directory may differ based on your local setup.

## 5. Safety Notes

- Do **not** pass raw Telegram or webhook text directly into PowerShell arguments.
- Always validate task IDs against the pattern `^task-[0-9]{3,}$`.
- Keep file write access limited to the bridge project directory.
- Do **not** expose API keys, tokens, passwords, or email addresses in any workflow export.
- Do **not** run the bridge script with full disk write access or dangerous Codex flags.
- Test with read-only tasks before enabling project-write workflows.
- Do **not** use `Invoke-Expression`, `-EncodedCommand`, or `--yolo` / `danger-full-access`.

## 6. Production Warning

This example is intentionally minimal and should be reviewed before production use. In a real deployment, add input validation, rate limiting, error handling, and logging.
