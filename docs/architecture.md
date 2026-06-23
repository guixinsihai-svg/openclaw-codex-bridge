# Architecture

OpenClaw Codex Bridge is designed as a local file-based bridge.

It keeps the first public version intentionally small: task files in, result files out, with a PowerShell wrapper in the middle.

## Components

```text
Telegram
  |
  v
OpenClaw or n8n
  |
  v
task id only: task-009
  |
  v
scripts/run_codex_task.ps1
  |
  v
tasks/task-009.md
  |
  v
controlled Codex execution
  |
  v
results/task-009-result.md
```

## Main directories

- `scripts/`: local helper scripts.
- `examples/`: safe sample task and result files.
- `docs/`: design and safety documentation.
- `tasks/`: local runtime task files, ignored by Git.
- `results/`: local runtime result files, ignored by Git.
- `logs/`: local runtime logs, ignored by Git.

## Data flow

1. Telegram receives a user request.
2. OpenClaw or n8n converts that request into a task file.
3. The automation layer sends only a task id to this bridge.
4. The bridge validates the task id format.
5. The bridge resolves paths inside the project directory.
6. The bridge reads the task markdown file.
7. A controlled Codex execution flow handles the task.
8. The bridge writes a result markdown file.
9. OpenClaw or n8n reads the result and decides whether it is accepted.

## Why file-based first

A file-based workflow is easy to inspect, easy to back up, and easy to debug.

For this project, that matters more than adding a database or web server too early. A task file also gives humans a clear audit trail: what was requested, what was executed, and what result was produced.

## Trust boundaries

The most important boundary is between external chat input and local command execution.

External systems should never pass arbitrary shell commands into this project. They should pass only a task id. The local bridge then decides what file to read and what safe command path to use.

## Future architecture

Later versions may add:

- task status files,
- lock files,
- timeout handling,
- retry rules,
- structured JSON metadata,
- n8n workflow examples,
- OpenClaw result polling examples,
- automated tests for path and task id validation.
