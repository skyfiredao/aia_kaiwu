# 介绍：如何在软件工程中使用开物 (Kaiwu) 编码代理工作流系统

本文档介绍 *aia_kaiwu* 代理工作流系统的设计理念、角色、方法论和典型用法。目标读者是想要理解**这套系统是什么、为什么这么设计、怎么用于真实开发工作**的软件工程师。安装说明见 [`README_zh.md`](README_zh.md)。

## 前言

*aia_kaiwu* 取名自宋应星 1637 年的[《天工开物》](https://zh.wikipedia.org/wiki/%E5%A4%A9%E5%B7%A5%E5%BC%80%E7%89%A9)，这部书系统记录了当时的全部工艺。每一门都是独立的工艺门类，有自己的师承、工具与做法。每个角色一门手艺，行为契约明确写在 `skills/<role>.md`。角色 slug 分两个前缀。`task-*` 是单步 skill，`job-*` 是多步 workflow。

文档分三部分。第一部分定义塑造角色行为的命名方法论。第二部分列出原子 skill 和多步 workflow 的进入条件与 handoff。第三部分走三个真实开发场景到底。第一部分按顺序读；第二、三部分理解第一部分后可任意翻。

---

## 设计总览：三层架构

不同于传统扁平的多 agent 配置（所有能力平铺在同一层），本项目把三个不同关注点分成三层：

| 层 | 文件模式 | 职能 | 数量 |
|---|---|---|---|
| 1. 路由 | `AGENTS.md` | 读用户每条消息；按第 3.0 节的语义分类表分发到对应 workflow / skill。没有关键字表、没有 ask-before-dispatch；不明确的意图路由到 `@task-clarify`。 | 1 |
| 2. Workflow | `skills/job-*.md` | 把 task skill 串成端到端业务流，负责审批门和状态交接，并可持久化已批准的编排产物。生产代码行为留在被调用的 task。 | 8 |
| 3. Task | `skills/task-*.md` | 原子操作的具体行为契约（Purpose / Hard constraints / Output shape / Handoff）。每个 task 做好一件事。 | 14 |

组合方式：

- 用户发消息 → **Layer 1 (`AGENTS.md`)** 按 3.0 节的语义分类表分类意图
- 多步意图 → 分发到 **Layer 2 (`job-*`)** workflow，workflow 再按定义好的链调 **Layer 3 (`task-*`)** skill
- 单步原子意图 → 直接分发到 **Layer 3 (`task-*`)** skill
- 意图不明 → 路由到 `@task-clarify`。router 仍然做 dispatch；澄清通过 skill 调用完成，不在 router 层对话

### 为什么是三层而不是平铺

- 22 个 agent 平铺一层会强迫用户（和 AI）背下 ~20 项能力的适用时机。分层把"当前在什么 workflow"（job）、"在做什么操作"（task）、"怎么决定"（router）分开。
- Workflow 是可复用的业务流（plan-approve-build-review、安全审计、硬 bug 诊断、代码-文档对齐）。Task 保持职能收窄。Router 按工具能力自适应。
- 生产代码规则只在 task 里定义。Workflow 只增加审批门、步骤顺序、状态交接和已批准计划产物的持久化规则，不放宽 task 规则。Router 只负责派发。

### 为什么本设计对便宜模型友好

大部分操作不需要顶级模型。三层结构让便宜模型也能高效低成本地完成工作：

- **Router（第一层）** 本质是语义分类表查表（3.0 节）。AI 把用户意图匹配到表中一行，任何合格的 LLM 都做得可靠。
- **Workflow（第二层）** 是编号的分发链（`call task-A → task-B → gate → task-C`）。不用开放推理；照编号步骤走。
- **执行类 Task（第三层）** 使用明确的机器可判 predicate（测试通过、exit code 0、期望输出、HTTP 状态匹配等）作为 done 判据。只读 task 使用结构化判词和带来源的证据。
- **有界预算**（`task-yugong` 单会话上限 13 basket；no-progress 检测阻断打转）防止跑飞的循环带来成本失控。
- **歧义走 `@task-clarify`**：一次通过 skill 调用产出的聚焦澄清问题，比五轮 router 层来回猜测便宜得多。

综合来看，一个便宜模型读这套配置，可以完整跑通 workflow（plan → build → verify → review），成本上限清晰、成功判据明确，**匹配甚至超过**没有结构约束的顶级模型自由发挥。成本降低、执行加速、AI 在正确条件上停下而不是无限磨。

### 文件布局

- `skills/task-*.md`（14 个）：原子 skill
- `skills/job-*.md`（8 个）：多步 workflow
- 工具注册（`.claude/agents/*.md`、`.cursor/agents/*.md`、`.opencode/skills/*/SKILL.md`）统一 symlink 指向 `skills/` 里 22 个规范文件，所有支持的工具看到同一份行为契约。

### 各宿主工具的能力矩阵

现代 AI 编码工具已经内置了真正的 agent 编排。本配置关心的三项能力，各工具当前状态如下：

| 能力                                                | opencode           | Cursor             | Claude Code                                                                    | VS Code + Copilot                            |
| --------------------------------------------------- | ------------------ | ------------------ | ------------------------------------------------------------------------------ | -------------------------------------------- |
| 单轮内并发派发 subagent                             | 部分（平台内置 `plan`/`build`/`general`/`explore`/`librarian`/`multimodal-looker` 通过 `task` 工具可并发；`task-*` / `job-*` 项目角色通过 `skill(name=...)` 加载，在**共享上下文中顺序执行**） | 是（内置 `explore`/`bash`/`browser`；自定义 `.cursor/agents/*.md`；嵌套 2 层） | 是（`.claude/agents/*.md`；Task 工具并发调用） | 是（自动扫 `.claude/agents/*.md`；`agent/runSubagent` + `.agent.md` wrapper；开启配置项后嵌套 5 层） |
| 后台任务带完成回调 / 通知                           | 是（subagent 派发时 `run_in_background=true`；完成后 `<system-reminder>` 通知） | 是（后台 subagent + `stop`/`subagentStop` hook；Cloud Agent + iOS 推送 / Slack / Live Activity） | 部分（Bash 支持 `run_in_background=true`；无独立后台 subagent 回调） | 是（`chat.notifyWindowOnResponseReceived`；Copilot CLI 后台 session；Hooks Preview） |
| Agent 模式 / 人格间的自动状态交接                   | 是（父 → 子 subagent 带 continuation session id；`task(task_id=…)` 恢复完整上下文） | 是（父 → 子；本地 ↔ 云；主聊天 ↔ 侧栏聊天带上下文；可按 ID 恢复子 subagent） | 部分（子 subagent 返最终结果给父；父来编排下一次派发） | 是（`handoffs:` frontmatter 可选 `send: true` 自动提交；Session Target 下拉；Continue in Cloud；Plan → Agent） |

AI 运行时必须遵守的行为差异（每工具 dispatch 机制、workflow 链语义、opencode built-in 消歧、手工 handoff 兜底规则）在 `AGENTS.md` 第 3.0.1 节。每工具的安装步骤和完整配置见 [`README.md`](README.md)。

---

## 第一部分：方法论

命名方法论是行为的原子单位。每种方法论都有明确的触发条件、硬规则、反模式和一个具体的微观例子。先扫下面的表格，然后逐节读。

| 方法论 | 归属角色 | 一句话概括 |
|---|---|---|
| 第一性原理推导 | `task-single-plan` | 从不可再简约的约束推导计划，而不是从惯例。 |
| 第一性原理分解 | `task-clarify` | 把请求分解到根本问题，再回答。 |
| 端到端垂直切片 | `task-single-plan` | 每个计划步骤穿过所有层，形成一条完整但窄的通道。 |
| 扩展 → 迁移 → 收缩 | `task-single-plan` | 影响面广的改动分三步走。 |
| 对抗式审查 | `task-judge`、`task-challenge`、`job-plan`、`job-review`、`job-security-review` | 用对手视角审代码，不为设计辩护。每条 finding 给出具体失败模式。 |
| Fowler 代码坏味基线 | `task-judge`、`job-review`、`job-security-review` | 仓库无本地约定时应用标准坏味清单。 |
| TDD 纪律 | 跨角色（`task-multi-build`、`job-build`） | 红→绿→重构，一次一个行为，测试住在 seam 上。 |
| 循环工程 | `task-yugong`、`job-build` | 单一有界任务，不委派，迭代到验证通过。scope 变大就停下汇报。 |
| 六阶段证据优先回路 | `task-debug`、`job-debug`、`job-debug-deep` | 硬 bug 诊断分六阶段；反馈回路先于任何假设。 |
| SHA1 debug 前缀与会话记录文件 | `task-debug`、`job-debug-deep` | 每条 debug 日志带会话唯一的 SHA1 标签，一次 grep 清理。 |
| 战争迷雾制图 | `task-strategy` | 只写能精确描述的部分；其余留在雾里，直到能命名。 |
| 双分支原型法 | `task-quick-verify` | 一次性原型走两条分支之一：逻辑向终端 app 或 UI 变体集。 |
| 第一手来源研究 | `task-librarian`、`job-security-review`、`job-debug-deep` | 只用官方文档、源码、first-party API。不用二手来源。每条断言必须引用。 |
| 执行中检查点 | `task-checkpoint`、`job-build`、`job-verify` | 每 ~3 步或大动作前只读检查一次。判词是 `continue` / `adjust plan` / `halt`。 |

### 第一性原理推导

写计划前先列出方案必须满足的不可再简约的约束。约束包括数据结构、领域规则、性能预算、外部合约、安全要求。再从这些约束推导计划。不能从"我们通常这么干"或"上次那个类似功能的形状"来推。

惯例积累了很多失去理由的决定。从约束推导会重新验证这些决定是否仍然适合*本*问题。如果推出来的计划碰巧与惯例一致，那是被验证过的一致，不是假设的一致。

任何非平凡的规划会话（`task-single-plan`）。也包括你听见自己说"我们一直这么做"却说不出理由时。

循环论证的常见形式，"我们这么做因为我们这么做"或"惯例说 X，所以 X 是对的"。如果推导绕回惯例本身，说明没做过推导。

有需求要加一个"用户偏好"接口。惯例说 REST GET `/users/:id/preferences`。从约束推导。偏好每次翻页都读（性能预算亚 100ms）、按用户隔离（认证边界）、客户端缓存 5 分钟（可接受陈旧度）。推导出来发现，把偏好作为一小块 JSON 内联到用户 profile 返回，比单独一个接口更符合约束；惯例做法会多一次 roundtrip。

### 第一性原理分解

用户typed 的请求只是一个候选方案。把它分解到根本问题。用户真正要解决的是什么、什么是硬约束、什么是被伪装成需求的偏好。如果从根本问题能直接落出一个更简单的方案，把它作为一个可选解列出来。

用户表达的是他自己认为想要的，被"他认为什么可能"这层过滤过。AI 的活是在生成代码前浮现真实需求。实现候选方案时明明有更简单的方案能解决同一根本问题，双方的时间都被浪费。

任何模糊的、超过一轮对话的请求（`task-clarify`）。永远不要把"用户要求了 X"当作充分理由去实现 X，除非 X 从根本问题里明显能推导出来。

顺从式响应就是"你要 X，我建 X"。这是浅层 LLM 助手的做法，优化的是"看起来乐于助人"，代价是"不实用"。

用户说"加个 feature flag 关闭导出按钮"。分解出的问题是"什么问题？"，多半是"导出很慢，用户重复点击，把服务器拖垮"。根本问题可能靠"导出**期间**禁用按钮"（客户端状态）就解决了，不需要 feature flag。`task-clarify` 把两种解读列出来，问用户具体是哪个。

### 端到端垂直切片

每个计划步骤穿过系统所有层（schema、API、UI、测试）形成一条完整但窄的通道，尺寸能装进一个新鲜的 context window，独立可 demo。后续切片把通道加宽。

水平切片（先做所有 schema，再做所有 API，最后所有 UI）在你还不知道形状之前就锁定了形状。垂直切片每步产出一根端到端可跑的线；每根线告诉你下一根该怎么做。

任何多步计划（`task-single-plan`）。特别是引入跨层新功能时。

"先设计 schema，再设计 API，再设计 UI。" 等 UI 揭示 schema 是错的时候，schema 已经在 prod 里了。

"用户对帖子评论"功能。水平计划写 6 个 migration、4 个接口、3 个 UI 组件、12 个测试。垂直计划写 1 个 migration、1 个接口、1 个 UI 元素、1 个测试，够显示一条硬编码评论；下一个切片加评论撰写；再下加编辑；再下加嵌套。每个切片都可上线。

### 扩展 → 迁移 → 收缩

对影响面广的改动（重命名共享字段、共享符号改类型、拆分共享函数），按三个顺序阶段进行：

- **扩展**：新形式与旧形式并存。
- **迁移**：按爆炸半径分批把调用点从旧改到新。
- **收缩**：所有调用者都迁完后，删掉旧形式。

一次性全局改动会一次动所有地方；中途失败后代码库处于不一致状态。扩展-迁移-收缩保证每个中间状态都能跑、可回退。

任何调用点数量超过单个 session 能自信 touch 的重构（`task-single-plan` 会把这个顺序编进计划）。

"sed 一把梭全局改了 commit"。行得通的时候没事，行不通的时候，解开失败状态比分批迁移贵 10 倍。

把数据库列 `created` 重命名为 `created_at`：

- **扩展**：添加 `created_at`；写触发器让两列同步。
- **迁移**：分批把 reader 改成读新列（先改 query builder，再改报表，再改 dashboard）。
- **收缩**：删触发器，删旧列，删同步代码。

### 对抗式审查

用对手视角审对象，不是辩护者视角。不给它"为什么这样是好的"找理由；给它"它在什么情况会失败"找证据。每条 finding 命名一个具体失败模式（导致炸的输入、导致 race 的时序、被漏掉的需求），而不是笼统担忧。每次审查至少从三个正交角度攻击（比如正确性、性能、安全、可维护性、spec 漂移）。

辩护者什么都找不到，因为他的 prior 是"这东西没问题"。对手能找到真实缺陷，因为他的 prior 是"这东西会炸"。发现数与字数的比才是指标；"看起来没问题"不是审查结论。

- 实现后的代码审计（`task-judge`）
- 执行前的计划评审（`task-challenge`）
- 任何看起来官方但缺乏挑战的产物需要被推一把的场合

客套式模糊，如"你可以考虑…"、"也可以这样说…"。如果审查者说不出一个具体失败模式，这次审查等于什么都没找到。

审 login 接口。辩护者说"看起来干净、测试到位"。对手说"如果 `email` 长度 10 MB 会怎样？"（DoS 内存耗尽）→ 具体 finding。"如果两个请求同一微秒到达用不同密码呢？"（race）→ 具体 finding。"用户不存在的响应和密码错误的响应是同一个吗？"（timing 侧信道枚举用户）→ 具体 finding。

### Fowler 代码坏味基线

Martin Fowler 的《Refactoring》第 3 章列了一组"代码坏味"，稳定指向设计问题。`task-judge` 的 Standards 轴在仓库对某点无本地约定时应用这份清单。所有坏味都是判断题，不是硬违反；有明确的仓库标准优先。

**常用坏味：**

- **神秘命名**：改个名；改不出来诚实的名字，说明设计糊。
- **重复代码**：抽出共享形状。
- **依恋情结**：把方法搬到它依恋的数据上。
- **数据泥团**：把重复出现的字段组合成一个类型。
- **基本类型偏执**：给领域概念自己的一个小类型。
- **重复的 switch**：换成多态或共享 map。
- **散弹式修改**：一起变的东西集中到一个模块。
- **发散式变化**：一个模块因为多个原因变，就拆。
- **夸夸其谈通用性**：删没用的参数和抽象。
- **消息链**：用一个方法把这串调用藏起来。
- **中间人**：切掉透传，直接调真正的目标。
- **被拒绝的遗赠**：拒继承，改组合。

命名过的坏味是审查者和被审查者之间的共同词汇。"这是依恋情结"比"这看着别扭"更容易辩护、辩论、重构。

`task-judge` 的 Standards 轴审查中，仓库无对应规则时。

把坏味当硬规则。每种坏味都有合法例外；审查者的活是标出来，不是要求消除。

### TDD 纪律

严格的测试驱动开发：

1. 写一个失败的测试，描述期望的行为。
2. 跑测试，确认失败**原因正确**（不是语法/import/setup 错误）。
3. 写最小生产代码让测试通过。
4. 用测试作安全网重构。这个重构限定在步骤 3 刚写的代码，不扩到邻居。

适用于新功能、bug 修复（先写复现 bug 的回归测试）、API 变更。

**两条硬子规则：**

- **测试住在 seam 上**，不针对内部。seam 是观察行为但不伸手进去的公共接口。写测试前先命名 seam。
- **垂直切片**：一个测试、一个实现、一个循环。永远不要先写所有测试再写所有实现（"水平切片"）；那验证的是想象的行为，在你理解实现之前就锁死了形状。

**要拒绝的反模式：**

- **耦合实现的测试**：mock 内部协作者、测试私有方法、通过侧信道验证。特征是行为没变但你重构测试就挂。
- **同义反复测试**：`expect(add(a, b)).toBe(a + b)`。构造上必然通过；永远不可能和代码不一致。期望值必须来自独立的真源。
- **水平切片**：同上。

跨所有执行角色（`task-multi-build`、`task-yugong`）。明确豁免的场景包括一次性试探/实验脚本、纯配置修改、文档、依赖版本升级。

加一个 `discount()` 函数。错误做法是先写 10 个测试覆盖每层折扣，再实现。正确做法反过来。先写一个 10% off 的测试，看它失败，实现，重构；下一轮加 20% 层；再下加可叠加逻辑；每轮都产出可运行的代码。

### 循环工程

`task-yugong`（愚公，移山的老人）的默认执行模式。拿一个界定清楚的任务，在完整纪律下磨到验证通过。主任务不委派。每步最多重试 3 次。如果任务比预期大，**停下汇报**给用户；绝不悄悄扩张范围。

大多数真实工作不是多域的，也不受益于委派。委派带来协调成本、责任归属模糊、专家输出冲突的风险。一个专注的执行者能完成一个协调团队用同样时间才辩完的活。

任何单一 scope 明确的具体任务。用户给一个执行任务没指名角色时，`task-yugong` 是**默认角色**。


- **悄悄扩张范围**：任务变大；`task-yugong` 继续干，做完了用户没要求的东西。
- **反射式委派**：派了不需要的子 agent。协调成本 > 直接执行。

用户说"login 页面在移动 Safari 上有 2 像素错位；修一下"。`task-yugong` 复现、找到 flexbox 值错、修、加截屏回归测试、在 iOS Safari 验证、汇报。如果过程中发现错位是一个损坏的 CSS 设计 token 造成，还影响另外 40 页。`task-yugong` 停下汇报这个发现，不会悄悄把 40 页都修。

### 六阶段证据优先回路

`task-debug` 用六个有序阶段诊断硬 bug。它保持只读，负责建立证据并给出 instrumentation、测试和修复方案；可写执行体负责应用。跳阶段只有在明确正当理由下才允许。

- **第 1 阶段：建反馈回路。** 构造一条命令，这个 bug 在时它红、修好时它绿。回路必须能报红（跑到真正的 bug 代码路径）、确定性（同一判词每次）、快（秒级）、可 agent 单独跑（不用人盯）。**没建回路前不允许进入假设阶段。**
- **第 2 阶段：复现 + 最小化。** 跑回路看它红。确认是用户提到的那个具体症状，不是附近另一个。一次砍一个元素做最小化；剩下的每个元素必须有承重。
- **第 3 阶段：假设。** 测任何假设前先列出 3-5 个可证伪的假设并排序。给用户看排序列表；领域知识常常瞬间重排。
- **第 4 阶段：植入观察。** 先 debugger/REPL。需要写文件时，给可写执行体一份针对性 instrumentation 方案。一次只改一个变量。
- **第 5 阶段：修 + 回归测试。** 在正确 seam 上给出回归测试和最小修复方案。执行体**先写回归测试再修**。
- **第 6 阶段：清理 + post-mortem。** 重读执行体证据，确认原始复现不再复现、回归测试通过、debug instrumentation 清干净。

第 1 阶段（反馈回路）是整个 skill 的本质；后续阶段一旦回路存在都是机械化步骤。没有回路的调试是猜。

抵抗了首次修复的硬 bug 或性能回归、"有时会挂"的 flaky 行为、无明显原因的症状链。


- **散弹式调试**：一次改三个东西，希望其中一个起作用。
- **log-then-grep**：全打出来事后 grep，被信号淹没。
- **修了不写测试**：没有回归测试锁住这个 bug 会再出现。

一个测试在 CI 上偶尔挂：

- **第 1 阶段**：本地 `--repeat 100` 复现，观察到 3 次挂。
- **第 2 阶段**：把测试砍到最小仍然 3/100 挂。
- **第 3 阶段**：假设 (a) 共享可变状态、(b) 时区依赖断言、(c) 数据库排序不确定。
- **第 4 阶段**：植入观察状态；观察。
- **第 5 阶段**：用锁修具体的 race；加一个逼出 race 条件的回归测试。
- **第 6 阶段**：验证、清理、写文档。

### SHA1 debug 前缀与会话记录文件

需要写文件做 instrumentation 的 `task-debug` 会话会给出一个 SHA1。可写执行体使用前 8 位作为 `[DEBUG-a3f9c2e1]`，并把脱敏后的会话数据记入 `spec/debug/<sha1_short>.md`。

debug 日志本该是临时的。没有 tag 时清理只能靠肉眼扫。有会话级 tag 后，清理只要一次 grep，`grep -rn "[DEBUG-a3f9c2e1]" | xargs sed -i '/DEBUG-a3f9c2e1/d'`。不会有 debug 日志意外活过一次会话。

任何需要 debug 日志的 `task-debug` 会话。每条建议的日志必须带 tag。


- **无归属的 `console.log("here")`** 留在代码库。debug 噪音就是这么积累的。
- **跨会话重用 tag**：`[DEBUG]` 没有会话标识的前缀，在多并发 debug 时不可清理。

debug 会话 SHA1 前缀 `a3f9c2e1` 时，开发者加 `console.log("[DEBUG-a3f9c2e1] user id at entry:", userId)` 和 `console.log("[DEBUG-a3f9c2e1] cache hit:", cached)`。修好、回归测试通过后，一次 grep 就把这两行删干净。`spec/debug/a3f9c2e1.md` 可选留作 post-mortem。

### 战争迷雾制图

`task-strategy` 把大型多会话工作画成一张 issue tracker 上的地图。核心规则是**不能精确描述的东西不上图**。清晰票据之外是雾；在 `Not yet specified` 下松散地记下来，等前沿推进后再让它升级成票据。票据类型包括 `research`（`task-librarian` 解决）、`prototype`（`task-quick-verify` 解决）、`grilling`（`task-clarify` 解决）、`task`（解锁决策的手工活）。

过早给模糊区域上规格会凭空发明 scope。承认迷雾是诚实的；这防止团队基于"以后会变的假设"行动。研究或原型解决后，雾会变成清晰票据。

工作大到装不进一次 agent session、通往目标路径模糊、执行前还有多个决策待决。


- **过度规划**：写 50 个覆盖未知的票据。多数会错、多数会重写、白费力气。
- **冲向目的地**：无视雾，直接盖你猜的方案。
- **一次会话解超过一张非 research 票据**：拔苗助长，也违背地图渐进演化的意义。

任务是"把 app 从框架 A 迁到框架 B"。`task-strategy` 命名目的地（"app 在 B 上跑起来，功能对等"），然后画出能精确描述的部分。清晰的票据有 `[task] 在 A 旁边搭起 B`、`[research] B 支持我们的 SSO adapter 吗？`、`[prototype] 移植一个屏幕并测量`、`[grilling] A 里那些 B 没对应的功能是否要弃用？`。其他都留在雾里。每次会话拿一张票。

### 双分支原型法

`task-quick-verify` 写一次性代码回答一个设计问题，从两条分支里挑一条：

- **logic 分支**：一个终端交互 app 推动状态机跑难以推理的边界。
- **UI 分支**：同一路由上多套彻底不同的变体，URL 参数切换 + 浮动切换栏。

第一天就是一次性的。一命令启动。无持久化。无测试。无打磨。决定验证过之后 fold 回真实代码。原型不进 main；只有当前用户消息明确要求时才创建废弃分支或 commit。

具体的廉价产物能比任何数量的讨论都快回答很多设计问题。两条分支覆盖了设计不确定性的两种主导形状（行为 vs 视觉）。

"这样感觉对吗？"（UI 分支）"这个状态机在边界情况到底该怎么走？"（logic 分支）任何会议开一堆但没有进展的设计问题。


- **原型蔓延**：加测试、加持久化、加打磨。原型不小心变成生产。
- **原型合并进 main**：把一次性形状锁成永久。

UI 分支：三套候选 onboarding 流全部住在 `/onboard?v=1|2|3`；浮动切换栏切换。用户在走廊测试里点全部三个。胜出者 fold 进 `/onboard`；切换栏删掉。

logic 分支：终端 app 模拟支付重试循环的状态机，跑 200 条合成交易；三个边界情况浮现，是规范没预料到的。

### 第一手来源研究

`task-librarian` 把每条断言追回它的所属源，包括官方文档、源码、规范、first-party API。永远不是二手写法。输出里每条断言都有 URL 或具体的 repo path 引用（`owner/repo:file:line`）。断言类型区分：

- `[verified via docs]`：来自官方文档
- `[verified via source]`：读了实际源码得到
- `[common pattern]`：野生大量观察到的样式，带一个代表性链接
- `[unverified, training snapshot]`：只来自模型训练数据，无实时核实

二手写法会漂移、误引、脱离上下文。第一手来源是库维护者自己写的基本事实。URL 或 file:line 引用让断言可独立核对。

"库 X 怎么用？"、"框架 Y 的最佳实践是什么？"、"OSS 仓库 Z 怎么实现这个？"


- **博客引用**：随便一个 dev.to 帖子被当成权威。
- **无引用断言**："通常是这样做" 没有出处。
- **发明 API 签名**：描述一个实际源码里不存在的 API。这是浅层 LLM 助手做的事；`task-librarian` 拒绝。

问题："在 Next.js 15 里怎么用 React Server Components 配合数据库？" `task-librarian` 读 Next.js 15 App Router 官方文档，引用具体 URL 和章节，去 Next.js 源码 repo 交叉验证 `unstable_cache` 的实际行为，引用源码文件和行号，无法验证的部分标为 `[unverified, training snapshot]` 让调用者知道要另行核实。

### 执行中检查点

`task-checkpoint`只读地跑在执行过程中，不在事前也不在事后。它验证进行中的工作仍与已批准的计划一致，可以安全继续。判词是 `continue` / `adjust plan` / `halt` 之一。

**何时触发：**

- 多步计划每 ~3 步。
- 任何大动作前（schema migration、部署、`git push`）。
- 执行者报告漂移或异常摩擦时。

执行漂移从执行内部看不见。一个位于执行循环之外的检查点角色能在"我们在第 4 步了但计划假设第 3 步测试应该已经完成"这类漂移之前发现问题。廉价干预打败昂贵返工。

**何时不用。** 计划未存在之前（那是 `task-clarify` 的活）。所有工作完成之后（那是 `task-judge` 的活）。每一步都查（过度检查，协调成本 > 收益）。


- **橡皮图章检查点**：`task-checkpoint` 每次都说 "continue" 而没真读 diff。没用。
- **晚检查点**：等到计划漂了 10 步才检。检查点的意义就是**早**发现漂移。

`task-multi-build` 在一个 12 步 auth 重构计划的第 6 步。`task-checkpoint` 读第 3 步（上次检查点）以来的 diff，发现执行者引入了一个计划没批准的新依赖，返回 `adjust plan`。计划更新，明确处理新依赖（或者移除依赖）后继续。

---

## 第二部分：角色

角色按工作阶段分组。每张角色卡列出目的、何时进入、内嵌方法论、handoff 目标、以及**何时不用**这个角色。

### 2.1 决策与规划

在写代码之前决定**做什么**、**按什么顺序**的角色。

#### `task-clarify`

- **目的**：批判用户请求本身，不是代码。列出隐藏假设、模糊之处、可能的 AI 失败模式；只推荐一个最有价值的澄清问题。
- **何时进入**：请求模糊、比一轮能处理的要大、或者藏着用户自己没注意到的矛盾。
- **方法论**：第一性原理分解
- **硬规则**：未获用户批准不推进。不出计划。不动实现。
- **Handoff**：`task-single-plan`（用户澄清后）
- **不用于**：已经精确的请求。直接跳过去 `task-single-plan` 浪费一轮。

#### `task-single-plan`

- **目的**：产出一次执行会话能完成的书面计划（大工作则出 spec/PRD）。只读，不改文件。
- **何时进入**：多步工作（≥3 步）、有架构选择、跨多个模块、scope 不明显。
- **方法论**：第一性原理推导、端到端垂直切片、扩展 → 迁移 → 收缩
- **硬规则**：写完计划就停。等审批。
- **Handoff**：`task-challenge`（评审）→ `task-multi-build` 或 `task-yugong`（执行）。极大的跨会话工作先交给 `task-strategy`。
- **不用于**：跨多次会话、目的地模糊的工作（用 `task-strategy`）。

#### `task-challenge`

- **目的**：挑一份书面计划在清晰度、完整度、可验证性三个维度上的毛病。每步查三项。
  - 文件命名了吗？
  - 可观察结果写了吗？
  - 验证步骤定义了吗？
- **何时进入**：书面计划存在（聊天里、文件里、或 `task-single-plan` 产出）需要严格评审再进入实现。
- **方法论**：对抗式审查
- **硬规则**：不改计划自己；只返回 findings。不做掩盖真缺陷的客套模糊。
- **Handoff**：`task-single-plan`（修订）或 `task-multi-build` / `task-yugong`（批准后执行）。
- **不用于**：评审实现好的代码（那是 `task-judge`）。

#### `task-quick-verify`

- **目的**：写一次性代码回答一个设计问题，当廉价具体产物比再讨论更快能给出答案时。
- **何时进入**："这样感觉对吗？" / "该长什么样？" / "这个状态机在边界情况到底怎么走？"
- **方法论**：双分支原型法
- **硬规则**：第一天就是一次性的。无测试、无打磨、无持久化。commit 到废弃分支不进 main。
- **Handoff**：`task-single-plan`（把验证的决定 fold 进真计划）或 `task-multi-build`（集成）。
- **不用于**：建生产功能。看起来忍不住合并进 main 时，记住这个分支是废弃的。

#### `task-strategy`

- **目的**：把大的多会话工作画成一张共享决策票据地图。每次会话解一张票，直到通往目的地的路径清晰。
- **何时进入**：工作大到装不进单次 agent session、通往目的地路径模糊、执行前还有多个决策待决。
- **方法论**：战争迷雾制图
- **硬规则**：绝不冲向目的地。每次会话解不超过一张非 research 票据。
- **Handoff**：`task-librarian`（research 票）、`task-quick-verify`（prototype 票）、`task-clarify`（grilling 票）、`task-single-plan`（task 票准备好执行规划时）。
- **不用于**：能装进一次会话的小任务。`task-strategy` 的开销只在真正的多会话工作里值得。

### 2.2 执行

写代码、产出产物的角色。

#### `task-multi-build`

- **目的**：多域实施者，主动向专家委派。跨多个模块执行改动；宿主支持原生 subagent 时并行派发独立专家。
- **何时进入**：任务跨多个模块或系统，能从委派 `task-explore` / `task-librarian` / `task-judge` / `task-multimodal-looker` 中受益。
- **方法论**：TDD 纪律、执行中检查点（每 ~3 步派）
- **硬规则**：不做类型抑制、不吞异常、不做未确认的破坏性 git 动作、不做 bug 修复过程中未请求的重构。
- **Handoff**：`task-judge`（实现后审计）。
- **不用于**：单一 scope 任务。用 `task-yugong`。多域协调成本只在工作真正跨域时值得。

#### `task-yugong`（愚公，默认角色）

- **命名由来**：愚公移山的寓言里，愚公一点一点地移山。这是"有界、耐心、不委派"的劳动典范，毅力最终换来外力相助。这个角色是默认执行者。拿一个界定清楚的任务，磨、验证，scope 变大就停。
- **目的**：拿一个界定清楚的任务，在完整工程纪律下磨到验证通过。用户没指名角色时，默认就是它。
- **何时进入**：任何单一 scope 的具体实现任务。
- **方法论**：循环工程、TDD 纪律
- **硬规则**：主任务不委派。每步最多重试 3 次。任务比预期大就**停下汇报**；绝不悄悄扩张。
- **Handoff**：无（结束就完）。中途可咨询 `task-checkpoint`，结尾可咨询 `task-judge`。
- **不用于**：真正需要专家委派的多域任务（用 `task-multi-build`）。

#### `task-general`

- **目的**：跨不相关系统的只读混合任务协调器，没有专家角色覆盖时的兜底。拆解并派发专家；只有宿主支持原生 subagent 时才并行。
- **何时进入**：任务混合研究和执行，跨几个不相关系统，没有单一专家角色能覆盖。
- **硬规则**：不吞属于 `task-explore`、`task-librarian`、`task-judge`、`task-multimodal-looker` 或 `task-debug` 的专家活；交给他们。
- **Handoff**：各子任务对应的专家角色；聚合结论后交回用户。
- **不用于**：能装进单一角色的任务。`task-general` 是兜底，不是首选。

### 2.3 搜索与研究

不改文件、只搜集信息的角色。

#### `task-explore`

- **目的**：本仓库内的上下文 grep。回答"X 在哪定义？"、"哪个文件处理 Y？"、跨切面模式搜索。
- **何时进入**：用户问某物在哪定义、哪个文件处理什么；无法从内存回答的跨切面模式搜索。
- **硬规则**：不改文件。不做超出搜索结果的推测。不概述没打开的文件。第一遍搜索完就停，除非用户要求继续。
- **Handoff**：`task-multi-build` / `task-yugong`（修改找到的东西）或 `task-single-plan`（基于发现制定计划）。
- **不用于**：外部研究（用 `task-librarian`）。

#### `task-librarian`

- **目的**：外部参考，包括 docs、OSS repo、官方 API、最佳实践研究。
- **何时进入**：不熟悉的库/框架、"X 的最佳实践是什么？"、"OSS Y 怎么做这个？"、需要 web 或外部 repo 的研究。
- **方法论**：第一手来源研究
- **硬规则**：不做无标注推测。不发明真实源码里没有的 API 签名。
- **Handoff**：`task-single-plan`（设计集成）或 `task-multi-build`（直接应用）。可以作为 background agent 派出去，父 agent 继续干别的。
- **不用于**：仓内搜索（用 `task-explore`）。

#### `task-multimodal-looker`

- **目的**：描述或提取用户分享的图片、PDF、截图、图表里的信息。
- **何时进入**：用户分享了视觉媒体；父 agent 需要媒体里的具体信息。
- **硬规则**：先回答用户具体问题。低置信度读物明确标出。绝不编造媒体里看不到的文字。当前工具打不开分享的媒体就直说。
- **Handoff**：需要提取信息的下一个角色。
- **不用于**：纯文本输入。

### 2.4 审查与诊断

在三个不同时点检查工作缺陷的角色。

#### `task-checkpoint`（执行过程中）

- **目的**：执行中检查点。验证进行中的工作仍与已批准计划一致，可以安全继续。
- **何时进入**：多步计划每 ~3 步、任何大动作前（schema migration、部署、`git push`）、执行者报告漂移时。
- **方法论**：执行中检查点
- **硬规则**：只读。跑在执行过程中，不在事前或事后。判词是 `continue` / `adjust plan` / `halt`。
- **Handoff**：执行者（`continue`）、`task-single-plan`（`adjust plan`）、用户（`halt`）。
- **不用于**：事前评审计划（用 `task-challenge`）或事后审计（用 `task-judge`）。

#### `task-judge`（执行之后）

- **目的**：只读高权威双轴审计。
- **何时进入**：跨系统的架构选择、同一 bug 首次修复失败 ≥2 次后、完成重大改动准备宣告 done 前、安全/性能判断题。
- **方法论**：对抗式审查、Fowler 代码坏味基线
- **双轴保持独立，永不合并、不重排**（原生 subagent 工具可并行）：
  - **Standards**：代码是否符合本仓 coding standards 加 Fowler 代码坏味基线？
  - **Spec**：代码是否符合原始 issue / PRD 要求？
- **硬规则**：不改文件。不做没有具体建议的"你可以考虑..."。永不跨轴合并 findings；一个轴可以通过而另一个失败。
- **Handoff**：`task-multi-build` / `task-yugong`（应用修复）或用户（架构批准）。
- **不用于**：进行中的工作（用 `task-checkpoint`）。

#### `task-debug`（硬 bug）

- **目的**：用六阶段证据优先回路诊断硬 bug 和性能回归。
- **何时进入**：抵抗过一次修复的硬 bug 或性能回归、"有时会挂"的 flaky、无明显原因的症状链、执行者搞不定要做第二次修复前。
- **方法论**：六阶段证据优先回路、SHA1 debug 前缀与会话记录文件
- **硬规则**：没建能报红的回路前不允许进入假设。不做散弹调试。debug 日志必须带 SHA1 前缀。宣告 done 前必须重跑原始复现。
- **Handoff**：`task-multi-build` / `task-yugong`（应用修复）或 `task-judge`（如果根因是架构问题）。
- **不用于**：直接首次修复能解决的 bug；`task-debug` 只处理硬的。

---

### 2.5 Workflow

把 `task-*` skill 串成端到端业务流的多步 workflow。每个 workflow 文件是路由/组合谱；硬约束都在被调用的 skill 里。

#### `job-plan`

- **目的**: 把模糊或多步请求走完 `task-clarify` → `task-single-plan` → `task-challenge` → 用户批准 → 持久化 plan artifacts（`plan.md` 必写；`design.md` / `guide.md` / `README.md` 按需写）到 `spec/<slug>/`。
- **入场时机**: 请求模糊、≥ 2 步、涉及架构选择，或用户说"先做个计划"、"plan first"。
- **链路参考**: [`AGENTS.md`](AGENTS.md) 第 5.2 节
- **调度规则**: 模糊请求不许跳过 `task-clarify`。第 6 步（用户批准）之前不许推进。批准前不许写 `spec/<slug>/`。写入时不许生造 step 3 未产出的可选 artifact（design/guide/README）。
- **交接**: `job-build`（持久化完成后；执行器从磁盘读 `spec/<slug>/plan.md`）。
- **不适用**: 单步任务（直接走 `task-yugong` 或具体 skill）。

#### `job-build`

- **目的**: 按 TDD 纪律执行已批准的计划，每 ~3 步用 `task-checkpoint`。执行体是单模块 `task-yugong` 或跨模块 `task-multi-build`。
- **入场时机**: 已有批准的计划（走完 `job-plan` 或用户直接提供）；用户说"实现"、"执行"、"落实"。
- **链路参考**: [`AGENTS.md`](AGENTS.md) 第 5.2 节
- **调度规则**: 遇到 checkpoint `halt` 未经用户重置不推进。scope 变大绝不悄悄扩张，停下汇报。大状态转换前必须先 checkpoint。
- **交接**: `job-review`（所有计划步骤完成后）。
- **不适用**: 无计划的即兴实现（先走 `job-plan`）。

#### `job-verify`

- **目的**: 通过 `task-checkpoint` 按已批准计划检查执行中工作（continue / adjust plan / halt）。
- **入场时机**: 执行中"跑到哪了"、执行体出现偏移，或被 `job-build` 每 ~3 步自动派发。
- **链路参考**: [`AGENTS.md`](AGENTS.md) 第 5.2 节
- **调度规则**: 不在这里做完成后审查。本 workflow 不动文件。
- **交接**: `continue` 回执行体（`task-yugong` / `task-multi-build`）；`adjust plan` → `job-plan`；`halt` → 用户。
- **不适用**: 完成后的综合审查（用 `job-review`）。

#### `job-debug`

- **目的**: bug 一次修的诊断路径（`task-debug` 六阶段的 Phase 1-3）；硬/flaky/串行症状 bug 升级到 `job-debug-deep`。
- **入场时机**: 用户报 bug、测试挂、行为反常；首次尝试。
- **链路参考**: [`AGENTS.md`](AGENTS.md) 第 5.2 节
- **调度规则**: 第 1 阶段的反馈回路绝不跳过。修复前必须先写回归测试。第 3 阶段确认是硬 bug 就升级，不硬撑。绝不用 `sleep()` 掩盖竞态。
- **交接**: `task-yugong`（直接修）；`job-debug-deep`（升级）。
- **不适用**: 已经首次修失败的 bug（直接走 `job-debug-deep`）。

#### `job-align`

- **目的**: 只读代码-文档对齐。`task-explore` 枚举文档中描述实现的地方 → 分类 stale/missing/drift → 用户批准方向 → 持久化已批准报告 → `task-yugong` / `task-multi-build` 应用编辑 → `task-judge` 再扫。
- **入场时机**: "文档过时"、"对齐一下"、"文档和代码不一致"，或多轮重构后主动跑。
- **链路参考**: [`AGENTS.md`](AGENTS.md) 第 5.2 节
- **调度规则**: 不动 spec/PRD 类"意图"文档除非用户明确同意。不做整批文本 diff，逐条改保留语义。
- **交接**: 无（干净重扫后终止）。
- **不适用**: 从零起草新文档（那是常规实现任务）。

#### `job-review`

- **目的**: 收尾前的完成审查。链路是 `task-challenge`（计划 vs 实际 diff 逐条核对）→ `task-judge`（Standards 轴 + Spec 轴）→ `task-explore`（已知 bug 特征与残留扫描）→ 聚合结论。
- **入场时机**: 声明任务完成前；开 PR 或合并 PR 前；feature 分支发布前；执行类角色报告收尾之后。
- **链路参考**: [`AGENTS.md`](AGENTS.md) 第 5.2 节
- **调度规则**: 只读。Standards 与 Spec 两条轴分开归属，绝不合并。只要还有 `[blocker]`，绝不给 `SHIP`。本角色内不"顺手改一下"。
- **交接**: 由 `task-multi-build` 或 `task-yugong` 承接 `[blocker]` 和 `[should-fix]` 项。
- **不适用**: 执行过程中的检查（那是 `task-checkpoint`，它跑在执行**中**，本 workflow 跑在执行**后**）。

#### `job-security-review`

- **目的**: 端到端安全审计。链路是 `task-explore`（定位安全敏感面）→ 独立的 `task-judge` 与 `task-librarian` 检查（宿主支持时并行）→ 必要时用 `task-debug` 深挖不清楚的漏洞路径 → 聚合结论。
- **入场时机**: 上线带安全面的代码前（认证、会话、加密、密钥/令牌处理、输入校验、反序列化）；开涉及安全代码的 PR 前；发版周期性巡检；发现安全相关 bug、需先把利用面画清楚再动手修的时候。
- **链路参考**: [`AGENTS.md`](AGENTS.md) 第 5.2 节
- **调度规则**: 只读。子智能体的发现按来源分列，不跨源合并或重排。`[blocker]` 必须给出具体失效模式。最终结论就一句 `SHIP` / `FIX-THEN-SHIP` / `DO-NOT-SHIP`。
- **交接**: 由 `task-multi-build` 或 `task-yugong` 承接 `[blocker]` 和 `[should-fix]` 项。
- **不适用**: 非安全类的一般正确性审查（用 `job-review`）。

#### `job-debug-deep`

- **目的**: 硬 bug 诊断的端到端流程。驱动 `task-debug` 走完六阶段证据优先回路；第 3 阶段按需派发 `task-librarian` 拉外部知识；第 4 阶段发现根因是架构问题时升级到 `task-judge`；第 5 阶段把修复交给 `task-yugong`（单模块）或 `task-multi-build`（跨模块）；第 6 阶段校验清理。
- **入场时机**: 一次简单修没搞定的硬 bug 或性能回归；"有时候会挂"的 flake；一串没有明显起因的症状；对同一个 bug 准备做第二次修复前。
- **链路参考**: [`AGENTS.md`](AGENTS.md) 第 5.2 节
- **调度规则**: 没有能报红的反馈回路就绝不进假设阶段。debug 日志必须带 SHA1 前缀、并配套 `spec/debug/<sha1_short>.md` 记录。回归测试要在**修改之前**写在正确的 seam 上。绝不用 `sleep()` 掩盖竞态；第 6 阶段清理绝不能跳。
- **交接**: `task-yugong`（单模块修复）或 `task-multi-build`（跨模块修复）；可选在第 6 阶段末尾再做一次 `task-judge` 审查。
- **不适用**: 首次尝试就能修好的简单 bug（直接走 `job-debug` 或 `task-yugong`）。

---

## 第三部分：场景

三个真实开发情景到底。每个都展示角色按什么顺序触发，方法论如何在每一步塑造行为。

### 场景 A：模糊请求，中等规模任务

**请求**（用户，不精确）"给 app 加认证。"

**链**：`task-clarify → task-single-plan → task-challenge → task-multi-build → task-checkpoint（检查点） → task-judge`

**走一遍：**

1. **`task-clarify`** 批判请求本身。第一性原理分解问"认证"解决什么问题。候选包括 (a) 防止未授权访问，(b) 个性化体验，(c) 按用户计费。列出假设（"SSO 需要吗？密码重置需要吗？SSO 提供商？"）、歧义（"session 还是 JWT？移动端？"）、AI 失败模式（"会用 OAuth 过度设计，其实一个简单 session cookie 就够"）。推荐唯一最有价值的澄清问题"用户按账户付费，还是就是不让陌生人看私有数据？"
2. 用户答："就是不让陌生人看私有数据。email + 密码。不用 SSO。"
3. **`task-single-plan`** 产出书面计划。第一性原理推导问不可再简约的约束是 (a) email + 密码、(b) session-based（未提移动端）、(c) 密码重置走邮件、(d) 已有框架的 session 中间件。端到端垂直切片排 6 个原子步骤，每步端到端可 demo，包括 `users` 表 migration、注册接口、登录接口、session 中间件、登出接口、密码重置流程。每步命名了 touch 的文件和预期可观察结果。停。等审批。
4. **`task-challenge`** 用对抗式审查姿势批。发现第 3 步没指定哈希算法；第 4 步没说 session 过期后怎样；第 3 步没限速（暴力破解风险）；计划没有回滚故事。返回 findings；计划被修订。
5. 用户批准修订后的计划。
6. **`task-multi-build`** 执行。TDD 纪律要求每一步都先在 seam 上写失败的行为测试、看它以正确原因失败、实现、重构。背景派 `task-librarian` 从 OWASP 文档确认 bcrypt cost factor 具体推荐值（第一手来源研究）。派 `task-explore` 找可复用的现有中间件。
7. **`task-checkpoint`** 在第 3 步后触发（约 1/3 处）。只读检查点。读上次 commit 以来的 diff；确认执行者按 `task-challenge` 要求加了限速。判词是 `continue`。
8. 第 6 步后，`task-multi-build` 汇报功能完成，测试全过。
9. **`task-judge`** 跑双轴对抗式审计。Standards 轴发现一处基本类型偏执（用裸字符串代表密码而不是领域类型）；判断题，不是硬违反。Spec 轴确认 `task-challenge` 提出的每处歧义都在代码里解决了。判词是批准，附一条 `[should-fix]`（基本类型偏执）。交给 `task-multi-build` 做小 follow-up。

**触发的方法论**：分解、推导、垂直切片、对抗审查（两次）、TDD、第一手来源、检查点、Fowler 坏味。

### 场景 B：目的地模糊的长周期项目

**请求**（技术负责人，大 scope）"把 web app 从框架 A 迁到框架 B。"

**链**：`task-clarify → task-strategy（画图） → 票据（research / prototype / grilling / task） → task-strategy（工作图，一次会话解一张） → task-single-plan（每张 task 票）→ task-multi-build → task-checkpoint → task-judge`

**走一遍：**

1. **`task-clarify`** 分解请求。
   - **根本问题**：多半是"框架 A EOL / 性能天花板 / 招人困难"。
   - **歧义**："迁"可以指全面重写、增量式绞杀、只做新模块。
   - **推荐**："命名终点线。'迁完了'具体是什么？B 上做到功能对等，还是新功能上 B、老功能留 A？"
2. 用户答："全部对等。所有新功能必须在 B 上。老功能碰到就迁，但那些故意休眠的功能我们要一个计划。"
3. **`task-strategy`** 画 wayfinder 地图。战争迷雾制图，命名目的地（"所有功能在 B 上跑、功能对等、生产环境没有 A"）。然后画能精确的部分。
   - `[task] 在 A 旁边搭起 B（dual-stack build）。`
   - `[research] B 支持我们的 SSO adapter 吗？对着 SSO 厂商文档核实。`
   - `[research] B 支持我们的数据可视化库吗？对着库的 B 兼容矩阵核实。`
   - `[prototype] 移植一个代表性屏幕。测 LCP、bundle size、开发者速度。`
   - `[grilling] 那 12 个没人用、也没人有权删的休眠功能怎么办？`
   - `[task] 切换策略：路由层绞杀 vs 按功能 feature flag。`
   其他都留在 `Not yet specified`。
4. 第 2 次会话：`task-strategy` 挑第一张 `[research] SSO adapter`。派 `task-librarian`。librarian 读 SSO 厂商的 B 兼容文档（第一手来源研究），交叉对照厂商的公开 SDK repo，发现一个坑（session refresh 在不同 adapter 间行为不同）。票据结案带 findings；`Decisions so far` 追加一行。会话结束。
5. 第 3 次会话跑 `[prototype] 移植一个代表性屏幕`。派 `task-quick-verify`。UI 分支用不同 B 路由模式建三个版本，测 LCP，把切换栏放在演示里让团队点。胜出者记进决策日志。票据结案。
6. 第 4 次会话：`[grilling] 休眠功能`。派 `task-clarify` 追问用户。用户同意对 12 个中的 8 个做正式弃用投票。
7. 票据解决过程中，雾变成新的清晰票据，如 `[task] 按 librarian 发现迁 SSO 层`、`[task] 采用原型胜出的路由模式`、`[task] 弃用批准的 8 个功能`。
8. 每张 task 票据在新的会话里被拿起时，走 **`task-single-plan`**（单会话计划）→ **`task-challenge`**（评审）→ **`task-multi-build`**（执行）→ **`task-checkpoint`**（检查点）→ **`task-judge`**（审计）。
9. 每次会话后，`task-strategy` 用票据结论更新地图，并把新可精确的雾升级成新票据。

**触发的方法论**：分解、战争迷雾制图、第一手来源、双分支原型，加上每张 task 票据的完整场景 A 链。

**关键纪律**：每次会话解不超过一张非 research 票据。"顺便再解一张小的"的诱惑破坏整张图的演化，是要拒绝的。

### 场景 C：首次修复失败的硬 bug

**请求**（开发者，抓狂）"checkout 测试在 CI 上偶尔挂。我加了 `sleep(1)` 修了一次，还是间歇挂。"

**链**：`task-yugong（首次修复尝试，失败）→ task-debug（六阶段诊断）→ task-multi-build（真修复，TDD）→ task-judge（如果是架构问题就审）`

**走一遍：**

1. **`task-yugong`** 是用户第一次说"修这个测试"时的默认角色。它试了 `sleep(1)`。表面修好了，flakiness 又回来了。`task-yugong` 正确地停下汇报，而不是加 `sleep(2)`。它没有通过打补丁掩盖症状来悄悄扩张 scope。
2. 用户说"还是 flaky"。这是 `task-debug` 的触发信号。
3. **`task-debug` 第 1 阶段**：建反馈回路。本地用 `--repeat 200` 跑测试。观察到 200 次里 4 次失败。回路能报红、可确定性够（4/200 可重现）、快（30 秒）、可 agent 单独跑。记下反馈回路命令。
4. **`task-debug` 第 2 阶段**：复现 + 最小化。确认失败是用户提到的具体症状（第 87 行那个具体 assertion），不是附近另一个。把测试砍到仍然 3/200 挂的最小函数体。剩下的每个元素都有承重。
5. **`task-debug` 第 3 阶段**（假设）。生成 4 个可证伪的排序假设：
   - (a) 数据库事务隔离导致 read-your-writes 在并发测试跑时失败。若串行化测试套件后 flakiness 消失，则假设成立。
   - (b) assertion 里的 `Date.now()` 跨了秒边界。若冻结时间后 flakiness 消失，则假设成立。
   - (c) checkout 服务在模块级变量里缓存了东西。可证伪的做法是测试间清模块缓存。
   - (d) 一个共享 test fixture 被无关的测试改动了。可证伪的做法是单独跑这个测试。
   给用户看排序列表。用户按领域知识重排："我们最近给 checkout 服务加了 Redis 缓存" → (c) 升到 #1。
6. **`task-debug` 第 4 阶段**（植入观察）。给出 SHA1 会话 `a3f9c2e1`、脱敏后的 `spec/debug/a3f9c2e1.md` 内容，以及一条针对性日志 `console.log("[DEBUG-a3f9c2e1] checkout cache state:", cache)`。可写执行体应用方案并返回 cache 证据。证据确认假设 (c)，上一次测试的模块级缓存活到了同一进程里的下一次测试。
7. **`task-multi-build` 第 5 阶段**（修 + 回归测试）。在正确 seam 上写回归测试（test-suite 级 `afterEach` 断言缓存清空）。看它以正确原因失败，然后修 checkout 服务暴露 `resetCache()` 方法（或者更好，用依赖注入让缓存 per-instance）。测试套件转绿。
8. **`task-debug` 第 6 阶段**（验证清理 + post-mortem）。重读执行体证据。`grep -rn "[DEBUG-a3f9c2e1]"` 返回零条匹配，debug 记录已整理或删除，原始 `--repeat 500` 回路报告 0 次失败。它为将来的 commit 或 PR message 给出正确假设"修复 flaky checkout 测试，由模块级 Redis 缓存跨测试运行残留导致。"
9. 如果在第 4 阶段发现根因是架构错误（比如共享可变状态在整个代码库大量使用），`task-debug` 会先交给 **`task-judge`** 出架构判断，再由判断圈定修复范围。

**触发的方法论**：循环工程（正确停下而不是加 `sleep`）、六阶段回路、SHA1 标签、TDD（用于回归测试）、对抗式审计（如果升级）。

**关键纪律**：flaky 测试里的 `sleep()` 是红旗，说明底层 race 从未诊断过。下一个触发的角色是 `task-debug`，不是 `sleep(2)`。

---

## 结尾

**如何开始用这些角色：**

- 读 `AGENTS.md` 第 3.0 节了解语义路由，第 4 节查看角色卡。需要显式指定时输入 `@task-<role>` 或 `@job-<workflow>`；否则描述任务让路由器选择。
- 不确定用哪个角色时，找第三部分里最接近的场景，跟着链走。
- 某个方法论用起来陌生时，回第一部分再读那节，找一个小的真实任务试。

**下一步去哪：**

- `README.md`：安装和分工具配置。
- `AGENTS.md`：AI 每次 session 开始时读的操作规则。第 3.0 节是默认状态和语义路由表；第 3.1-3.10 节是 always-on 纪律；第 5 节是编排模式。
- `skills/task-<role>.md` 和 `skills/job-<workflow>.md`：每个角色或工作流的完整行为契约、输出模板、硬约束。
