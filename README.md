# OpenClaw Codex Bridge

OpenClaw Codex Bridge is a small local bridge for handing tasks from OpenClaw to Codex CLI in a controlled way.

这个项目的目标很简单：让 OpenClaw 可以通过 Telegram 收到一个任务编号，把任务交给本机的 Codex CLI 非交互处理，再读取结果文件并做人工或自动验收。

## 当前状态

v0.2.0 把项目从“开源项目骨架”推进到“可运行 MVP 雏形”：

- 读取 `tasks/task-xxx.md`
- 调用 Codex CLI 的 `exec` 非交互模式
- 写入 `results/task-xxx-result.md`
- 写入 `logs/task-xxx.log`
- 拒绝覆盖已有结果文件
- 支持 UTF-8 中文任务单
- 默认 read-only 沙盒
- 需要项目写入时使用单独的 `scripts/run_project_task.ps1`

它仍然不是完整的 OpenClaw 或 n8n 插件，也不包含任何真实账号、Token、API Key 或 webhook 配置。

## 解决什么问题

在本地自动化里，Telegram、n8n、OpenClaw 和 Codex CLI 往往各管一段流程。如果直接把 Telegram 消息当成命令执行，风险很高；如果每次都手工复制任务，又很麻烦。

这个项目提供一个保守的中间层：

- Telegram 只负责提交任务编号，例如 `task-009`。
- 本地脚本只根据任务编号读取固定目录里的任务单。
- Codex CLI 只处理任务单内容，不接收 Telegram 传来的任意 PowerShell 命令。
- 结果写入固定位置，方便 OpenClaw 或人工验收。
- 默认不允许 Codex 修改项目文件。

## Quick Start

准备条件：

- Windows
- PowerShell 5.1 或 PowerShell 7+
- 本机已安装并已登录可用的 Codex CLI
- 能在命令行运行 `codex exec`

创建一个中文任务单：

```powershell
Set-Location D:\OpenSourceProjects\openclaw-codex-bridge
New-Item -ItemType Directory -Force -Path .\tasks
Copy-Item .\examples\task-chinese.md .\tasks\task-010.md
```

运行默认 read-only 任务：

```powershell
.\scripts\run_codex_task.ps1 -TaskId task-010
```

如果 `codex` 不在 `PATH` 里，可以显式传入本机 Codex CLI 路径：

```powershell
.\scripts\run_codex_task.ps1 `
  -TaskId task-010 `
  -CodexPath "C:\Path\To\codex.exe"
```

运行完成后查看：

```powershell
Get-Content .\results\task-010-result.md -Encoding UTF8
Get-Content .\logs\task-010.log -Encoding UTF8
```

如果结果文件已经存在，脚本会直接拒绝运行，避免覆盖旧结果。

## Windows 使用示例

只读检查当前桥接项目：

```powershell
Copy-Item .\examples\task-chinese.md .\tasks\task-011.md
.\scripts\run_codex_task.ps1 -TaskId task-011
```

让 Codex 修改某个明确项目目录时，不要使用默认脚本。改用 project task 脚本，并显式传入 workspace：

```powershell
Copy-Item .\examples\task-project.md .\tasks\task-012.md
.\scripts\run_project_task.ps1 `
  -TaskId task-012 `
  -WorkspacePath "D:\YourProject"
```

`run_project_task.ps1` 使用 `workspace-write`，Codex 的写入范围应该限制在 `-WorkspacePath` 指定的项目目录。不要把系统目录、用户主目录、下载目录、桌面或包含密钥的目录当作 workspace。

## 中文任务单

任务单请保存为 UTF-8 Markdown 文件，例如：

```text
tasks/task-010.md
```

任务编号必须符合：

```text
^task-[0-9]{3,}$
```

可以写中文内容，例如：

```markdown
# 任务：检查 README

请只读检查当前项目 README，说明哪些地方还不清楚。
不要修改文件。
请用中文回答。
```

脚本会用 UTF-8 读取任务单，并通过标准输入传给 Codex CLI，避免把中文任务文本拼接成 PowerShell 命令。

## OpenClaw 调用示例

OpenClaw 或 n8n 应该只传任务编号，不要传 PowerShell 命令。

推荐流程：

1. OpenClaw 或 n8n 把用户请求保存成 `tasks/task-010.md`。
2. 自动化层只把 `task-010` 传给本地脚本。
3. 本地脚本读取固定目录里的任务单。
4. Codex CLI 非交互执行。
5. OpenClaw 或人工读取 `results/task-010-result.md` 和 `logs/task-010.log`。

PowerShell 调用形态：

```powershell
.\scripts\run_codex_task.ps1 -TaskId task-010
```

需要项目写入时：

```powershell
.\scripts\run_project_task.ps1 `
  -TaskId task-012 `
  -WorkspacePath "D:\YourProject"
```

更多说明见 [examples/openclaw-command-example.md](examples/openclaw-command-example.md)。

## Documentation

- [OpenClaw command examples](docs/openclaw-command-examples.md)
- [n8n workflow example](docs/n8n-workflow-example.md)
- [Safety guide](docs/safety.md)
- [Architecture notes](docs/architecture.md)

## 安全警告

不要做这些事：

- 不要让 Telegram、OpenClaw、n8n 传任意 PowerShell 命令。
- 不要直接把远程聊天文本拼成 `codex.exe` 参数。
- 不要使用 `Invoke-Expression`、`-EncodedCommand`、`--yolo`、`danger-full-access`。
- 不要把 API Key、Token、密码、邮箱、Telegram ID、webhook secret 写进代码、任务单、日志或示例。
- 不要提交 `.env`。
- 不要默认开放项目写权限。

默认脚本 `run_codex_task.ps1` 使用 `read-only`。如果任务确实要改项目文件，应该使用 `run_project_task.ps1`，并传入明确、经过人工确认的 workspace 路径。

更详细的说明见 [docs/safety.md](docs/safety.md)。

## 项目结构

```text
openclaw-codex-bridge/
  scripts/
    run_codex_task.ps1
    run_project_task.ps1
  tasks/
  results/
  logs/
  examples/
  docs/
```

`tasks/`、`results/`、`logs/` 是本地运行时目录，默认被 `.gitignore` 排除。

## 当前限制

- 还没有完整的 OpenClaw 插件代码。
- 还没有完整的 n8n workflow 示例。
- 还没有自动化测试套件。
- 还没有任务队列、锁、重试、并发控制。
- 还没有日志脱敏工具。
- Codex CLI 的安装、登录和模型配置仍由本机用户自己负责。

## 后续路线图

- 增加最小测试脚本，验证任务编号校验、拒绝覆盖和路径边界。
- 增加 n8n 示例 workflow，但不包含真实密钥。
- 增加任务状态文件，例如 `pending`、`running`、`done`、`failed`。
- 增加日志脱敏工具。
- 增加 OpenClaw 读取结果的完整示例说明。

## 申请 Codex for Open Source 时的项目价值描述

如果未来申请 Codex for Open Source，可以诚实、保守地描述为：

OpenClaw Codex Bridge 是一个面向本地自动化用户的小型开源桥接项目，重点不是炫技，而是降低把聊天入口、自动化系统和 AI 编程工具串起来时的安全风险。项目通过任务编号、任务单文件、固定输出目录和安全文档，把“从 Telegram 到 Codex CLI”的流程变得更可审计、更容易复现，也更适合个人开发者和小团队维护。

不要声称项目已经有大量用户、星标或下载量。申请是否成功取决于平台规则和项目实际质量，本项目不能保证一定通过。

## Smoke Test

运行最小结构检查：

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\smoke-test.ps1
```
