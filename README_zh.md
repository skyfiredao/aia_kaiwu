# aia_kaiwu: AI 编码代理工作流系统

一套工作流化的代理系统，在多个现代 AI 编码助手（opencode、Cursor、Claude Code、VS Code + Copilot）里跑同一套工程技能与工作流。

在宿主工具**有**原生 subagent 编排能力的地方，能力装成**真正的 subagent**；[`AGENTS.md`](AGENTS.md) 第 5.1 节里的手动多 agent 编排作为可移植的兜底。

English version: [README.md](README.md)。

## 命名由来："开物"

"aia_kaiwu" 取名自宋应星 1637 年的[《天工开物》](https://zh.wikipedia.org/wiki/%E5%A4%A9%E5%B7%A5%E5%BC%80%E7%89%A9)。这部书系统记录了当时的全部工艺：农、织、冶、陶、械。每一门都是独立的工艺门类，有自己的师承与做法。

每个能力一门手艺，行为契约写在 `skills/<slug>.md`。能力 slug 分两个前缀：`task-*` 是原子技能，`job-*` 是多步工作流。

## 设计总览

三层架构（非扁平多 agent 列表）：

- **Layer 1，路由**（`AGENTS.md`）：读用户每条消息；按第 3.0 节的语义分类表分发到对应工作流或技能。没有关键字表、没有 ask-before-dispatch；不明确的意图路由到 `@task-clarify`。
- **Layer 2，工作流**（`skills/job-*.md`）：把原子技能串成端到端业务流，负责交互策略（审批门或自主预授权）和状态交接，并可持久化已批准的编排产物。
- **Layer 3，Task**（`skills/task-*.md`）：原子操作的具体行为契约。每个 task 做好一件事。

**对便宜模型友好。** Router 是语义分类表；工作流是编号分发链；执行类技能使用机器可判 done predicate；只读技能返回结构化判词；预算有界（`task-yugong` 单会话上限 13 basket）。

完整设计走查见 [`INTRODUCTION_zh.md`](INTRODUCTION_zh.md) 的“设计总览：三层架构”。

## 目录结构

```
.
├── AGENTS.md                              ← 索引 + 工作纪律
├── CLAUDE.md → AGENTS.md                  ← 软链接（Claude Code）
├── README.md                              ← 英文版说明
├── README_zh.md                           ← 本文件
├── windows_setup.ps1                      ← Windows 工作区安装脚本
├── skills/                                ← 单一权威能力定义
│   ├── task-single-plan.md
│   ├── task-multi-build.md
│   ├── task-general.md
│   ├── task-explore.md
│   ├── task-librarian.md
│   ├── task-multimodal-looker.md
│   ├── task-judge.md
│   ├── task-clarify.md
│   ├── task-challenge.md
│   ├── task-checkpoint.md
│   ├── task-quick-verify.md
│   ├── task-debug.md
│   ├── task-strategy.md
│   ├── task-yugong.md
│   ├── job-plan.md
│   ├── job-build.md
│   ├── job-verify.md
│   ├── job-debug.md
│   ├── job-align.md
│   ├── job-review.md
│   ├── job-security-review.md
│   ├── job-debug-deep.md
│   └── job-spiral-up.md
├── .opencode/
│   └── skills/
│       └── <slug>/SKILL.md                ← 软链接 → ../../../skills/<slug>.md
├── .claude/
│   └── agents/                            ← 软链接 → ../../skills/*.md
└── .cursor/
    ├── rules/
    │   └── agents.mdc                     ← rules 桥接（alwaysApply）
    └── agents/                            ← 软链接 → ../../skills/*.md
```

改 `skills/<slug>.md` 或 `AGENTS.md`，`.claude/agents/`、`.cursor/agents/`、`.opencode/skills/*/SKILL.md`、`CLAUDE.md → AGENTS.md` 下的软链接会自动同步。

## 安装

### 独立工作区

建一个独立目录做 workspace，agent 配置文件放在 workspace 根目录，源代码 repo 作为 workspace 的子目录。AI 工具打开 workspace 根目录，就能读到 agent 配置；对源代码的操作发生在子目录里，源代码 repo 一个 agent 配置文件都不加。

目录结构：

```
workspace/
├── AGENTS.md               ← 来自 aia_kaiwu
├── CLAUDE.md               ← 来自 aia_kaiwu
├── skills/                 ← 来自 aia_kaiwu（能力契约的规范文件）
├── .claude/                ← 来自 aia_kaiwu
├── .cursor/                ← 来自 aia_kaiwu
├── .opencode/              ← 来自 aia_kaiwu（opencode skill 注册目录）
└── source-repo/            ← 真正的源代码 repo（原样不动）
```

**macOS / Linux** 设置：

```bash
mkdir -p ~/workspace
cd ~/workspace

# 方式 A：拷贝（workspace 脱离 aia_kaiwu 源，独立演化）
cp -R /path/to/aia_kaiwu/{AGENTS.md,CLAUDE.md,skills,.claude,.cursor,.opencode} .

# 方式 B：symlink（workspace 跟随 aia_kaiwu 源 git pull 自动更新）
ln -sf  /path/to/aia_kaiwu/AGENTS.md AGENTS.md
ln -sf  /path/to/aia_kaiwu/CLAUDE.md CLAUDE.md
ln -sfn /path/to/aia_kaiwu/skills    skills
ln -sfn /path/to/aia_kaiwu/.claude   .claude
ln -sfn /path/to/aia_kaiwu/.cursor   .cursor
ln -sfn /path/to/aia_kaiwu/.opencode .opencode

# 源代码 repo clone 到子目录
git clone <source-repo-url> source-repo
```

**Windows** (PowerShell) 设置：

```powershell
# 1. 建 workspace 目录，把 aia_kaiwu clone 进去
mkdir C:\workspace -Force
cd C:\workspace
git clone <aia_kaiwu-repo-url> aia_kaiwu

# 2. 执行 setup 脚本（拷贝真实文件，生成工具目录里的技能内容）
.\aia_kaiwu\windows_setup.ps1

# 3. 源代码 repo clone 到子目录
git clone <source-repo-url> source-repo
```

如果 PowerShell 执行策略拦截脚本：`powershell -ExecutionPolicy Bypass -File .\aia_kaiwu\windows_setup.ps1`。

以后拉 aia_kaiwu 上游更新，重跑 `.\aia_kaiwu\windows_setup.ps1`。脚本会自动拉取更新并替换生成配置。

> **注意：** `aia_kaiwu\` clone 是权威来源；脚本会替换 workspace 中生成的副本。

日常使用：AI 工具打开 workspace 根目录（macOS / Linux 是 `~/workspace`，Windows 是 `C:\workspace`）。手动 git 操作时 cd 到 `source-repo/`。

一个 workspace 下可以放多个源代码 repo，共享同一份 agent 配置。换一份直接新建一个空 workspace 目录即可，不需要卸载。

## 各工具自动加载情况

| 工具                                       | 原生识别根目录 `AGENTS.md` | 我们提供的桥接 / 指令文件            | 我们提供的原生 subagent               | 并行 subagent 编排？                   |
| ------------------------------------------ | -------------------------- | ------------------------------------ | ------------------------------------- | -------------------------------------- |
| **opencode**                               | 原生                     | 无                      | 无（通过 `skill(name=...)` 按需调用技能） | `task` 工具支持并发 + 后台派发（只对平台内置 agent） |
| **Cursor**                                 | 原生                     | `.cursor/rules/agents.mdc`| `.cursor/agents/*.md` | 内置，可嵌套 subagent               |
| **Claude Code**（Anthropic CLI）           | 走桥接                     | `CLAUDE.md → AGENTS.md`               | `.claude/agents/*.md` | Task 工具并发                        |
| **VS Code + Copilot Chat**                 | 原生（`chat.useAgentsMdFile`）| 同时通过 `chat.useClaudeMdFile` 认 `CLAUDE.md` | 自动扫描 `.claude/agents/*.md` | 通过 `runSubagent`，开启配置项后可嵌套 5 层 |

各工具完整配置说明见下面各节。

**最低版本要求：**

- **opencode**：任意较新版本。
- **Cursor**：任意较新版本。
- **Claude Code**：任意较新版本。
- **VS Code + Copilot**：VS Code **1.99+**。

## 激活后的默认状态

上面任何一个工具加载 `AGENTS.md` 之后，助手默认就在 **aia_kaiwu 技能与工作流系统**里：

- 当前技能是 `task-yugong`（单一有界任务、不委派、坚持到验证通过）。
- 内部派发只走 `task-*` 和 `job-*` 子 agent。平台自带的 `plan` / `build` / `general` / `explore` / `librarian` / `multimodal-looker` 不会被当作快捷方式使用。
- 用户显式指定会覆盖默认：`@plan` 走 opencode 平台的 plan agent；`@task-single-plan` 走本项目严格版 plan。
- 如果消息更适合另一个自定义技能（`task-clarify` 处理歧义、`task-single-plan` 做架构、`task-explore` 找代码等），助手按 `AGENTS.md` 第 3.0 节的语义路由表切换。

完整规则：`AGENTS.md` 第 3.0 节。

---

## opencode 配置

opencode 原生把根目录的 `AGENTS.md` 作为 always-on 指令加载。

### 自动加载的文件

| 文件 | 加载时机 | 用途 |
|---|---|---|
| `AGENTS.md`（根目录） | 会话启动 | Always-on 操作规则，包括第 3.0 节的默认路由到 `task-*` / `job-*` 技能 |
| `skills/task-*.md` 和 `skills/job-*.md` | 按需通过 `skill` 工具 | 每个技能或工作流的完整行为契约，AI 需要时才拉进上下文 |

### 验证生效

1. 在支持 opencode 协议的客户端打开这个 workspace。
2. 问："你现在在按 AGENTS.md 的什么规则做事？"
3. 期望 AI 回答：默认状态是 `task-yugong`（单一有界任务，不委派），出自 AGENTS.md 第 3.0 节。
4. 给一个界定清楚的实现任务；期望 AI 按 `task-yugong` 契约执行（先出 todo，每步验证，scope 变大就停下汇报）。

### 已知限制

- 没有原生 `@task-<slug>` / `@job-<slug>` 子 agent 派发。这些名字仍可作为文本级技能指定，由 AI 在父上下文映射成 `skill(name="<slug>")`。
- `task` 工具里没有 `subagent_type="task-<slug>"` 或 `subagent_type="job-<slug>"`。通过 `task` 派发的子 agent 用的是 opencode 平台内置 agent（`plan`、`build`、`general`、`explore`、`librarian`、`multimodal-looker`），不带 `task-*` / `job-*` 的严格契约。
- 能力按需加载而不是 always-on；长会话可能需要中途重新 `skill(name="task-<slug>")` 或 `skill(name="job-<slug>")`。

---

## Cursor 配置

Cursor 原生把根目录的 `AGENTS.md` 作为 always-on 规则加载。

### 自动加载的文件

| 文件 | 加载时机 | 用途 |
|---|---|---|
| `AGENTS.md`（根目录） | 会话启动 | Always-on 操作规则 |
| `.cursor/rules/agents.mdc` | 会话启动（`alwaysApply: true`） | 引用 `@AGENTS.md` 的桥接 |
| `.cursor/agents/*.md` | agent 被调用时 | 所有能力对应的原生 subagent |

每个 `.cursor/agents/<slug>.md` 是指向 `skills/<slug>.md` 的软链接。YAML frontmatter 带 `name`、`description`、`model`、`readonly`、`is_background`。

### 验证生效

1. 在 Cursor 里打开这个仓库，开个 chat。
2. 输入 `@`: agent picker 应显示所有能力名称，和 Cursor 内置的排在一起。
3. 发 `@task-judge run a two-axis audit on the current diff`，确认自定义人格 按对抗式审查契约响应。

### 并发和后台派发

- **并行 subagent**：父 agent 用内置 Task 一次派多个命名 agent，结果作为chat 里的独立气泡返回。
- **嵌套 subagent**：subagent 可以再派 subagent，Cursor 限制了一个较浅的嵌套深度。
- **Cloud Agents**：`/in-cloud` 把任务推到 Cursor 的云端，完成后推送到 iOS、Slack、Live Activities。本地 ↔ 云通过 Agents Window 一键切换。
- **本地 hooks**：`.cursor/hooks.json` 接受 `stop`、`subagentStop`、`afterAgentResponse` 等钩子。想要本地 chat 完成后的桌面通知，用 hook接（Cursor 没有内置的本地 chat 通知开关）。

### 交接

- 父 → 子 subagent 自动交接；父 agent 会为子 agent 编排一份 curated prompt。
- 本地 ↔ 云通过 Agents Window 透明切换。
- 主聊天 ↔ 侧聊天继承上下文。
- `Resume agent <id>` 用完整历史 resume 已完成的 subagent。

### 已知限制

- Subagent 拿到的是父 agent 编排的 curated prompt，不是完整父会话记录。
- 部分 hook（`sessionStart`、`sessionEnd`、MCP hooks、Tab hooks、`workspaceOpen`）在 Cloud Agents 里不跑。
- Cloud Agents 强制 Max Mode；本地 hook 行为和云端不完全一致。

---

## Claude Code 配置

Claude Code 把根目录的 `CLAUDE.md` 作为项目指令加载，同时也认 `AGENTS.md`。

### 自动加载的文件

| 文件 | 加载时机 | 用途 |
|---|---|---|
| `CLAUDE.md → AGENTS.md`（软链接） | 会话启动 | 项目指令 |
| `.claude/agents/*.md` | agent 被调用时 | 所有能力对应的原生 subagent |

每个 `.claude/agents/<slug>.md` 是指向 `skills/<slug>.md` 的软链接。YAML frontmatter 用 Claude Code 的 schema：`name`、`description`、可选`tools` 白名单、可选 `model`。

### 验证生效

1. `cd` 到仓库，启动 `claude`。
2. 问："你可以派发哪些 agent？"
3. 期望列出所有能力作为一级 subagent。
4. 派发："用 Task 工具并行跑 `@task-explore` 和 `@task-librarian`。" 应该出现两个并排的 subagent 执行。

### 并发和后台派发

- **并行 subagent**：Task 工具从一次调用里派 subagent。一条消息里多次Task 调用就是并发执行。
- **后台 shell**：Bash 工具支持 `run_in_background=true` 跑长命令，可轮询输出。这是 shell 任务的后台，不是 subagent 编排的后台。
- **跨 subagent 交接**：没有原生机制。Subagent 把最终消息返回给父 agent，父 agent 再调 Task 派下一个技能。

### 已知限制

- 无响应后的交接按钮；无自动提交。
- 除了 `CLAUDE.md` 项目上下文之外，没有跨会话状态交接。
- 没有单独的后台 subagent 回调机制（后台只针对 shell 命令）。

---

## VS Code + GitHub Copilot Chat 配置

VS Code Copilot Chat 自动扫描根目录下的 `.claude/agents/*.md`。

### 自动加载的文件

| 文件 | 配置项 | 默认 |
|---|---|---|
| `AGENTS.md`（根目录） | `chat.useAgentsMdFile` | **on** |
| `CLAUDE.md`（根目录软链接） | `chat.useClaudeMdFile` | **on** |
| `.claude/agents/*.md`（技能软链接） | 自动（默认 agent 目录） | on |

VS Code 官方文档原文：

> "VS Code also detects `.md` files in the `.claude/agents` folder,
> following the Claude sub-agents format. This enables you to use the
> same agent definitions across VS Code and Claude Code."

Reference: <https://code.visualstudio.com/docs/agent-customization/custom-agents>

### 验证生效

1. 在 VS Code 里打开仓库，登录 Copilot Chat。
2. 打开 Chat 视图 → agents 下拉 → 确认所有能力和内置 agent 一起出现。
3. 选一个（比如 `@task-judge`），发一条简单 prompt，确认人格指令生效。
4. 如果某个技能没出现，Chat 视图右键 → **Diagnostics**，查`.claude/agents/*.md` 的解析错误。

### 可选：启用 `handoffs:` / `agents:` frontmatter

`.claude/agents/` 支持的 Claude sub-agent 格式覆盖 `name`、`description`、`tools`、`disallowedTools`。它**不支持** VS Code 专属字段：`handoffs:`（响应后一键按钮）、`agents:`（并行 subagent 白名单）、`user-invocable`、`disable-model-invocation`、`target`、`mcp-servers`、`hooks`。

想用这些，手写 `.github/agents/<slug>.agent.md`：

```yaml
---
name: <slug>
description: <一句话描述，会显示在 agent picker 里>
model:
  - Claude Sonnet 4.5 (copilot)
  - GPT-5.2 (copilot)
# 关键：如果下面用了 agents:，tools: 必须包含 'agent'
tools:
  - agent
  - edit
  - read
  - search/codebase
  - search/usages
  - web/fetch
agents:
  - <other-slug>
user-invocable: true
disable-model-invocation: false
target: vscode
handoffs:
  - label: <按钮文字>
    agent: <目标技能>
    prompt: <预填的 prompt>
    send: false                    # true = 自动提交
    model: Claude Sonnet 4.5 (copilot)
---

<粘贴 skills/<slug>.md 正文>
```

**`agent`-in-`tools:` 坑。** VS Code 官方文档原文：

> "If you specify `agents`, ensure the `agent` tool is included in the
> `tools` property."

如果 `agents:` 存在但 `tools:` 里没有 `agent`，agent 会加载但无法调用任何subagent，且不报错。

### 可选：启用嵌套 subagent

subagent A 调 subagent B 默认关闭：

| 配置项 | 默认 | 开启后最大深度 |
|---|---|---|
| `chat.subagents.allowInvocationsFromSubagents` | `false` | **5** |

Reference: <https://code.visualstudio.com/docs/agents/subagents#_nested-subagents>

### 配置速查

| 配置项 | 默认 | 用途 |
|---|---|---|
| `chat.agent.enabled` | `true` | Agent mode 主开关 |
| `chat.useAgentsMdFile` | `true` | 加载根目录 `AGENTS.md` |
| `chat.useClaudeMdFile` | `true` | 加载 `CLAUDE.md` |
| `chat.useNestedAgentsMdFiles` | `false`（Experimental） | 也加载子目录里的 `AGENTS.md` |
| `chat.subagents.allowInvocationsFromSubagents` | `false` | 允许 subagent 调 subagent |
| `chat.notifyWindowOnResponseReceived` | （off） | 完成时 OS 通知 |
| `chat.agentFilesLocations` | （默认） | 自定义 agent 文件的额外位置 |
| `chat.instructionsFilesLocations` | （默认） | 指令文件的额外位置 |

Reference: <https://code.visualstudio.com/docs/agents/reference/ai-settings>

### 已知限制

- `.claude/agents/` 加载的 Claude sub-agent 格式支持人格，不支持`handoffs:` / `agents:`。想要就写 `.github/agents/*.agent.md` 包装。
- `chat.useNestedAgentsMdFiles` 是 Experimental。
- Handoffs 是响应完成后**用户点击**才触发；不是自动切换。
- Subagent 请求的 model 不能超过主 model 的 cost tier，超了会降级。
- 自定义 agent 只对 Chat 和 agent mode 生效，不影响内联代码建议。


## 验证配置是否生效

问助手一句：

> "这个项目里有哪些能力？`@task-challenge` 是干什么的？"

如果它能列出完整能力集合（包括 `job-spiral-up`），并把 `task-challenge` 描述为计划批评者，说明配置已加载。

对 **Cursor**、**Claude Code**、**VS Code + Copilot** 还要额外测原生 subagent 派发：

> "并行 `@task-explore` 和 `@task-librarian`：在本仓库找 `foo()` 的调用点；同时找 `bar` 库的官方 API 文档。"

如果聊天里出现两个并排的 subagent 气泡各自独立完成，说明原生 subagent 编排生效。opencode 的项目能力通过 `skill` 工具载入，在父上下文顺序执行，应分别测试每个能力。

## 更新配置

`AGENTS.md` 和 `skills/<slug>.md` 是权威：

1. **改能力行为 / 纪律 / 索引条目** → 直接改 `skills/<slug>.md`（或改 `AGENTS.md` 第 3 节里的共享纪律）。`.claude/agents/`、`.cursor/agents/`、`.opencode/skills/*/SKILL.md`、`CLAUDE.md` 下的软链接会自动同步。
2. **改能力的可用工具、model、handoff 目标、可调 subagent 白名单** → 改 `skills/<slug>.md` 顶端的 frontmatter。各家原生工具都通过软链接读同一份 frontmatter。
3. **加或删一个能力** → 先改 `AGENTS.md` 第 3.0 节路由表和第 4 节能力索引；增删 `skills/<slug>.md`；在 `.claude/agents/`、`.cursor/agents/`、`.opencode/skills/` 里对应地增删投影。
4. `.cursor/rules/agents.mdc` 里是 `@AGENTS.md` 引用，只有当你要改它自己的指路片段时才需要动它。

## 技能与工作流

每个能力的完整行为契约在 [`skills/<slug>.md`](skills/)。设计深度导览（目的、进入条件、方法论、硬约束、handoff、以及三个端到端场景）在 [`INTRODUCTION_zh.md`](INTRODUCTION_zh.md) 第二部分和第三部分。

**原子技能**（`task-*`）：

| 技能 | 一句话定位 |
|---|---|
| [`task-clarify`](skills/task-clarify.md) | 批判用户请求本身，推一个最有价值的澄清问题。 |
| [`task-single-plan`](skills/task-single-plan.md) | 只读规划者。产出编号原子步骤或 spec/PRD。 |
| [`task-challenge`](skills/task-challenge.md) | 对抗式审查一个写好的计划。 |
| [`task-checkpoint`](skills/task-checkpoint.md) | 执行中检查点。`continue` / `adjust plan` / `halt`。 |
| [`task-quick-verify`](skills/task-quick-verify.md) | 一次性原型回答一个设计问题。 |
| [`task-strategy`](skills/task-strategy.md) | 多会话决策票据地图。每会话 1 张非 research 票。 |
| [`task-multi-build`](skills/task-multi-build.md) | 多领域实施者，向专家委派。 |
| [`task-yugong`](skills/task-yugong.md) | **默认**。单一 scope 任务，不委派，磨到验证通过。 |
| [`task-general`](skills/task-general.md) | 无专家匹配时的只读混合任务协调器。 |
| [`task-explore`](skills/task-explore.md) | 本仓库内的上下文 grep。 |
| [`task-librarian`](skills/task-librarian.md) | 外部文档、OSS repo、第一方 API；只用第一手来源。 |
| [`task-multimodal-looker`](skills/task-multimodal-looker.md) | 从图片、PDF、图表里描述或抽取信息。 |
| [`task-judge`](skills/task-judge.md) | 双轴审查（Standards + Spec，两轴独立不合并）。 |
| [`task-debug`](skills/task-debug.md) | 只读六阶段证据优先硬 bug 诊断回路。 |

**工作流**（`job-*`，串接原子技能）：

| 工作流 | 一句话定位 |
|---|---|
| [`job-plan`](skills/job-plan.md) | clarify → plan → challenge → approve → 持久化 plan artifacts 到 `spec/<slug>/`。 |
| [`job-build`](skills/job-build.md) | 在 TDD 下执行已批准计划，每 ~3 步 checkpoint。 |
| [`job-verify`](skills/job-verify.md) | 按已批准计划做执行中检查。 |
| [`job-debug`](skills/job-debug.md) | 首轮 bug 诊断；硬 bug 自动升级到 `job-debug-deep`。 |
| [`job-align`](skills/job-align.md) | 文档与代码对齐。 |
| [`job-review`](skills/job-review.md) | 完成前审查：challenge → judge → sweep。 |
| [`job-security-review`](skills/job-security-review.md) | 端到端安全审计链（locate → judge + librarian → 可选 debug）。 |
| [`job-debug-deep`](skills/job-debug-deep.md) | 端到端六阶段硬 bug 诊断。 |
| [`job-spiral-up`](skills/job-spiral-up.md) | 响应“循环直到结束”“一直到结束”“不要停，直到完成”“无限循环”等表达；开始时一次预授权，执行始终有界。 |

## 许可证

GPL-3.0，见 [`LICENSE`](LICENSE)。
