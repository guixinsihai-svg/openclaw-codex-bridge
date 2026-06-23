# Changelog

All notable changes to this project will be documented in this file.

## v0.2.0 - 2026-06-23

MVP bridge runner update.

Added:

- Runtime directories: `tasks/`, `results/`, and `logs/`.
- Read-only Codex task runner in `scripts/run_codex_task.ps1`.
- Project workspace-write runner template in `scripts/run_project_task.ps1`.
- UTF-8 Chinese task example in `examples/task-chinese.md`.
- Project-write task example in `examples/task-project.md`.
- OpenClaw command handoff example in `examples/openclaw-command-example.md`.
- README Quick Start, Windows examples, Chinese task notes, safety warnings, and OpenClaw invocation examples.

Changed:

- `scripts/run_codex_task.ps1` now calls Codex CLI non-interactively instead of using a placeholder body.
- The default runner uses `--sandbox read-only`.
- Result files are not overwritten.
- Safety docs now separate read-only tasks from project-write tasks.

Security notes:

- No API Key, Token, password, account id, webhook secret, or real user identity is included.
- No OpenClaw, n8n, scheduled task, environment variable, GitHub repository, or external form was modified.
- Dangerous Codex modes such as `--yolo` and `danger-full-access` are intentionally not used.

Remaining:

- Add automated tests for task id validation, path boundaries, and overwrite refusal.
- Add a minimal n8n workflow example without secrets.
- Add a log redaction helper before using this with sensitive internal tasks.

## v0.1.0 - 2026-06-23

Initial public project skeleton.

Added:

- Project README with purpose, workflow, safety boundaries, limits, and roadmap.
- MIT License.
- Windows and PowerShell friendly `.gitignore`.
- Safe PowerShell script template for task-id based execution.
- Chinese task and result examples.
- Architecture documentation.
- Safety documentation.
- Open source application notes for future Codex for Open Source consideration.
