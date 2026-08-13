# aia_kaiwu: AI 编码代理工作流系统

一套工作流化的代理系统，在多个现代 AI 编码助手（opencode、Cursor、Claude Code、VS Code + Copilot）里跑同一套工程技能与工作流。

能力是 **Agent Skills**（`SKILL.md` 目录）：每个宿主按 `description` 自动发现，用 `/<slug>` 调用，或在相关时自动应用。

English version: [README.md](README.md)。

## 命名由来："开物"

"aia_kaiwu" 取名自宋应星 1637 年的[《天工开物》](https://zh.wikipedia.org/wiki/%E5%A4%A9%E5%B7%A5%E5%BC%80%E7%89%A9)。这部书系统记录了当时的全部工艺：农、织、冶、陶、械。每一门都是独立的工艺门类，有自己的师承与做法。

每个能力一门手艺，行为契约写在 `skills/<slug>/SKILL.md`。能力 slug 分两个前缀：`task-*` 是原子技能，`job-*` 是多步工作流。

## 设计总览

三层架构（非扁平多 agent 列表）：

- **Layer 1，路由**（`AGENTS.md`）：读用户每条消息；按语义分类表分发到对应工作流或技能。没有关键字表、没有 ask-before-dispatch；不明确的意图路由到 `/task-clarify`。
- **Layer 2，工作流**（`skills/job-*/SKILL.md`）：把原子技能串成端到端业务流，负责交互策略（审批门或全自动）和状态交接，并可持久化已批准的编排产物。
- **Layer 3，Task**（`skills/task-*/SKILL.md`）：原子操作的具体行为契约。每个 task 做好一件事。

这套三层结构借鉴了 **prompt graph engineering** 的核心方法：把系统建成一张提示词节点的图——技能是节点，语义路由表和工作流链是显式的边，「结构（怎么路由）」与「内容（每个技能怎么做）」彼此分离、可各自独立演化。

**对便宜模型友好。** Router 是语义分类表；工作流是编号分发链；执行类技能使用机器可判 done predicate；分析类技能返回结构化判词；预算有界（`task-yugong` 在无法给出实质不同的下一次尝试时 Quit）。

## 目录结构

```
.
├── AGENTS.md                              ← 索引 + 工作纪律
├── CLAUDE.md                              ← 文本文件：`@AGENTS.md` 引用（Claude Code）
├── README.md                              ← 英文版说明
├── README_zh.md                           ← 本文件
├── INTRODUCTION.md                        ← 设计深度导览
├── INTRODUCTION_zh.md                     ← 中文版
├── windows_setup.ps1                      ← Windows 工作区安装脚本
└── skills/                                ← 权威 SKILL.md 目录（唯一入库内容；工具目录由安装步骤生成）
    ├── task-single-plan/
    ├── task-multi-build/
    ├── task-general/
    ├── task-explore/
    ├── task-librarian/
    ├── task-multimodal-looker/
    ├── task-judge/
    ├── task-clarify/
    ├── task-challenge/
    ├── task-checkpoint/
    ├── task-quick-verify/
    ├── task-debug/
    ├── task-strategy/
    ├── task-yugong/
    ├── task-repo-analyze/
    ├── task-distill-spec/
    ├── task-doc-write/
    ├── task-why-how-what/
    ├── job-plan/
    ├── job-build/
    ├── job-verify/
    ├── job-debug/
    ├── job-align/
    ├── job-review/
    ├── job-pr-maintain/
    ├── job-security-review/
    ├── job-debug-deep/
    ├── job-spiral-up/
    └── job-scamper/
```

改 `skills/<slug>/SKILL.md` 或 `AGENTS.md`。`.claude/`、`.cursor/`、`.opencode/` 三个工具目录不属于本仓库；安装步骤和 `windows_setup.ps1` 会在你的工作区里生成它们的 `skills/` 投影。`CLAUDE.md` 引用 `@AGENTS.md`。

## 安装

### 独立工作区

建一个独立目录做 workspace，agent 配置文件放在 workspace 根目录，源代码 repo 作为 workspace 的子目录。AI 工具打开 workspace 根目录，就能读到 agent 配置；对源代码的操作发生在子目录里，源代码 repo 一个 agent 配置文件都不加。

目录结构：

```
workspace/
├── AGENTS.md               ← 来自 aia_kaiwu
├── CLAUDE.md               ← 来自 aia_kaiwu（引用 @AGENTS.md）
├── skills/                 ← 来自 aia_kaiwu（其 skills/ 的拷贝或软链接）
├── .claude/skills          ← skills/ 的投影（macOS/Linux 软链接，Windows 复制）
├── .cursor/skills          ← skills/ 的投影（macOS/Linux 软链接，Windows 复制）
├── .opencode/skills        ← skills/ 的投影（macOS/Linux 软链接，Windows 复制）
└── source-repo/            ← 真正的源代码 repo（原样不动）
```

**macOS / Linux** 设置：

```bash
mkdir -p ~/workspace
cd ~/workspace

# 1. aia_kaiwu 的权威文件（拷贝可独立演化，或 symlink 跟随 git pull）
cp -R /path/to/aia_kaiwu/{AGENTS.md,CLAUDE.md,skills} .
#   symlink 方式：
#   ln -sf /path/to/aia_kaiwu/AGENTS.md AGENTS.md
#   ln -sf /path/to/aia_kaiwu/CLAUDE.md CLAUDE.md
#   ln -sfn /path/to/aia_kaiwu/skills  skills

# 2. 生成各工具的 skill 投影（各一个软链接 → skills/）
for t in .claude .cursor .opencode; do mkdir -p "$t"; ln -sfn ../skills "$t/skills"; done

# 3. 源代码 repo clone 到子目录
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

## 激活之后

上面任何一个工具加载 `AGENTS.md` 之后，助手就在 **aia_kaiwu 技能与工作流系统**里运行：

- 非问题指令先进 `task-yugong`（单一有界任务、不委派、坚持到验证通过）；命中更具体的路由行时由它接管。
- 内部派发只走 `task-*` / `job-*` 子 agent，不走宿主自带的快捷 agent。
- 如果消息更适合另一个自定义技能（`task-clarify` 处理歧义、`task-single-plan` 做架构、`task-explore` 找代码等），助手按 `AGENTS.md` 的语义路由表切换。

完整规则：`AGENTS.md`。

---

## opencode 配置

opencode 原生把根目录的 `AGENTS.md` 作为 always-on 指令加载。

### 自动加载的文件

| 文件 | 加载时机 | 用途 |
|---|---|---|
| `AGENTS.md`（根目录） | 会话启动 | Always-on 操作规则，包括默认路由到 `task-*` / `job-*` 技能 |
| `skills/*/SKILL.md` | 按需通过 `skill` 工具 | 每个技能或工作流的完整行为契约 |

### 验证生效

1. 在支持 opencode 协议的客户端打开这个 workspace。
2. 问："你现在在按 AGENTS.md 的什么规则做事？"
3. 期望 AI 回答：非问题指令先进 `task-yugong`（单一有界任务，不委派）。
4. 给一个界定清楚的实现任务；期望 AI 按 `task-yugong` 契约执行（先出 todo，每步验证，scope 变大就停下汇报）。

---

## Cursor 配置

Cursor 原生把根目录的 `AGENTS.md` 作为 always-on 规则加载。

### 自动加载的文件

| 文件 | 加载时机 | 用途 |
|---|---|---|
| `AGENTS.md`（根目录） | 会话启动 | Always-on 操作规则 |
| `.cursor/skills/*/SKILL.md` | agent 被调用时 | 所有能力对应的 Agent Skills |

`.cursor/skills` 是指向 `skills/` 的单个软链接。各能力的 YAML frontmatter 带 `name`、`description`、`model`、`is_background`。

### 验证生效

1. 在 Cursor 里打开这个仓库，开个 chat。
2. 输入 `/`: 技能列表应显示所有能力名称，和 Cursor 内置的排在一起。
3. 发 `/task-judge run a two-axis audit on the current diff`，确认自定义人格 按对抗式审查契约响应。

---

## Claude Code 配置

Claude Code 把根目录的 `CLAUDE.md` 作为项目指令加载，同时也认 `AGENTS.md`。

### 自动加载的文件

| 文件 | 加载时机 | 用途 |
|---|---|---|
| `CLAUDE.md`（`@AGENTS.md` 引用） | 会话启动 | 项目指令 |
| `.claude/skills/*/SKILL.md` | agent 被调用时 | 所有能力对应的 Agent Skills |

`.claude/skills` 是指向 `skills/` 的单个软链接。各能力的 YAML frontmatter 用 Claude Code 的 schema：`name`、`description`、可选`tools` 白名单、可选 `model`。

### 验证生效

1. `cd` 到仓库，启动 `claude`。
2. 问："你可以派发哪些 agent？"
3. 期望列出所有能力作为一级 subagent。
4. 派发："用 Task 工具并行跑 `/task-explore` 和 `/task-librarian`。" 应该出现两个并排的 subagent 执行。

---

## VS Code + GitHub Copilot Chat 配置

VS Code Copilot Chat 自动扫描根目录下的 `.claude/skills/*/SKILL.md`。需 VS Code 1.99+（用于 `chat.useAgentsMdFile`）。

### 自动加载的文件

| 文件 | 配置项 | 默认 |
|---|---|---|
| `AGENTS.md`（根目录） | `chat.useAgentsMdFile` | **on** |
| `CLAUDE.md`（根目录，`@AGENTS.md` 引用） | `chat.useClaudeMdFile` | **on** |
| `.claude/skills/*/SKILL.md`（Agent Skills） | 自动（Agent Skills 目录） | on |

VS Code Copilot 自动发现 `.claude/skills/` 下的 Agent Skills（`SKILL.md` 目录），与 Claude Code 共享。

Reference: <https://code.visualstudio.com/docs/agent-customization/agent-skills>

### 验证生效

1. 在 VS Code 里打开仓库，登录 Copilot Chat。
2. 打开 Chat 视图 → agents 下拉 → 确认所有能力和内置 agent 一起出现。
3. 选一个（比如 `/task-judge`），发一条简单 prompt，确认人格指令生效。
4. 如果某个技能没出现，Chat 视图右键 → **Diagnostics**，查`.claude/skills/*/SKILL.md` 的解析错误。

## 验证配置是否生效

问助手一句：

> "这个项目里有哪些能力？`/task-challenge` 是干什么的？"

如果它能列出完整能力集合（包括 `job-spiral-up`），并把 `task-challenge` 描述为计划批评者，说明配置已加载。

对 **Cursor**、**Claude Code**、**VS Code + Copilot** 还要额外测 skill 调用：

> "并行 `/task-explore` 和 `/task-librarian`：在本仓库找 `foo()` 的调用点；同时找 `bar` 库的官方 API 文档。"

每个 Agent Skill 按 `description` 或 `/<slug>` 加载。opencode 里能力通过 `skill` 工具载入、在父上下文顺序执行，应分别测试每个能力。

如果模型跳过了技能加载，告诉它："按 AGENTS.md 流程执行，先加载 skill 文件。"

## 技能与工作流

每个能力的完整行为契约在 [`skills/<slug>/SKILL.md`](skills/)。设计深度导览（目的、进入条件、方法论、硬约束、handoff、以及三个端到端场景）在 [`INTRODUCTION_zh.md`](INTRODUCTION_zh.md)。

**原子技能**（`task-*`）：

| 技能 | 一句话定位 |
|---|---|
| [`task-clarify`](skills/task-clarify/SKILL.md) | 批判用户请求本身，推一个最有价值的澄清问题。 |
| [`task-single-plan`](skills/task-single-plan/SKILL.md) | Planner。产出编号原子步骤或 spec/PRD。 |
| [`task-challenge`](skills/task-challenge/SKILL.md) | 对抗式审查一个写好的计划。 |
| [`task-checkpoint`](skills/task-checkpoint/SKILL.md) | 执行中检查点。`continue` / `adjust plan` / `halt`。 |
| [`task-quick-verify`](skills/task-quick-verify/SKILL.md) | 一次性原型回答一个设计问题。 |
| [`task-strategy`](skills/task-strategy/SKILL.md) | 多会话决策票据地图。每会话 1 张非 research 票。 |
| [`task-multi-build`](skills/task-multi-build/SKILL.md) | 多领域实施者，向专家委派。 |
| [`task-yugong`](skills/task-yugong/SKILL.md) | 单一 scope 任务，不委派，磨到验证通过。 |
| [`task-general`](skills/task-general/SKILL.md) | 无专家匹配时的混合任务协调器。 |
| [`task-explore`](skills/task-explore/SKILL.md) | 本仓库内的上下文 grep。 |
| [`task-librarian`](skills/task-librarian/SKILL.md) | 外部文档、OSS repo、第一方 API；只用第一手来源。 |
| [`task-multimodal-looker`](skills/task-multimodal-looker/SKILL.md) | 从图片、PDF、图表里描述或抽取信息。 |
| [`task-repo-analyze`](skills/task-repo-analyze/SKILL.md) | 分析仓库结构、约定、工具链、CI。消耗 token 较多，会先提示用户；输出持久化到 `spec/repo-analyze/`。 |
| [`task-distill-spec`](skills/task-distill-spec/SKILL.md) | 从现有文档蒸馏出 overview 级项目 spec（术语表、领域模型、设计原则、业务逻辑）为可预加载文件。只压缩只定义、绝不推断；静态快照。 |
| [`task-doc-write`](skills/task-doc-write/SKILL.md) | 四种模式（api、architecture、guide、readme）撰写专业文档，区分专业和科普两种风格。 |
| [`task-judge`](skills/task-judge/SKILL.md) | 双轴审查（Standards + Spec，两轴独立不合并）。 |
| [`task-debug`](skills/task-debug/SKILL.md) | 六阶段证据优先硬 bug 诊断回路。 |
| [`task-why-how-what`](skills/task-why-how-what/SKILL.md) | 单一视角的一次接地推演：把一个起点用黄金圈（Why→How→What）+ 第一性原理想透，产出一份结果，不做跨结果裁决。领域通用。 |

**工作流**（`job-*`，串接原子技能）：

| 工作流 | 一句话定位 |
|---|---|
| [`job-plan`](skills/job-plan/SKILL.md) | clarify → plan → challenge → approve → 持久化 plan artifacts 到 `spec/<slug>/`。 |
| [`job-build`](skills/job-build/SKILL.md) | 在 TDD 下执行已批准计划，每 ~3 步 checkpoint。 |
| [`job-verify`](skills/job-verify/SKILL.md) | 按已批准计划做执行中检查。 |
| [`job-debug`](skills/job-debug/SKILL.md) | 首轮 bug 诊断；硬 bug 自动升级到 `job-debug-deep`。 |
| [`job-align`](skills/job-align/SKILL.md) | 文档与代码对齐。 |
| [`job-review`](skills/job-review/SKILL.md) | 完成前审查：challenge → judge → sweep。 |
| [`job-pr-maintain`](skills/job-pr-maintain/SKILL.md) | PR 评审生命周期：对 diff 从第一性原理重新 review → 读人类评论 → 修复 → 更新描述 → 回复。确认后才 post；GitHub 写操作需授权。 |
| [`job-security-review`](skills/job-security-review/SKILL.md) | 端到端安全审计链（locate → judge + librarian → 可选 debug）。 |
| [`job-debug-deep`](skills/job-debug-deep/SKILL.md) | 端到端六阶段硬 bug 诊断。 |
| [`job-spiral-up`](skills/job-spiral-up/SKILL.md) | 响应"循环直到结束""一直到结束""不要停，直到完成""无限循环"等表达；单会话内自主跑到 `Done`。 |
| [`job-scamper`](skills/job-scamper/SKILL.md) | 多角度方案构建：初始方案 → SCAMPER 七角度拆解（舍弃不合理/重复）→ 每角度派 task-why-how-what → 用二八 + 逻辑自洽重估最优 → 直到无新合理角度。追求全面，不是找茬。 |

## 许可证

GPL-3.0，见 [`LICENSE`](LICENSE)。
