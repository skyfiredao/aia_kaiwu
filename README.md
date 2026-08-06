# aia_kaiwu: AI Coding Agent Workflow System

A workflow-oriented agent system that runs the same set of engineering skills and workflows across modern AI coding assistants (opencode, Cursor, Claude Code, VS Code + Copilot).

Where the host tool has native subagent orchestration, capabilities load as **real subagents**.

中文版说明：[README_zh.md](README_zh.md)。

## Why "kaiwu"

"aia_kaiwu" takes its name from [*Tiangong Kaiwu*](https://en.wikipedia.org/wiki/Tiangong_Kaiwu), the 1637 encyclopedia by Song Yingxing. That book catalogued every craft and production technique of the era: agriculture, weaving, metallurgy, ceramics, weaponry. Each craft was a distinct discipline with its own masters and its own protocol.

One capability per craft, each with a specific behavior contract in `skills/<slug>/SKILL.md`. Capability slugs use two prefixes: `task-*` for atomic skills, `job-*` for multi-step workflows.

## Design overview

Three-layer architecture (not a flat multi-agent list):

- **Layer 1, Router** (`AGENTS.md`): reads every user message; classifies intent semantically per section 3.0's routing table and dispatches to the right workflow/skill. No keyword table, no ask-before-dispatch; ambiguous intent routes to `@task-clarify`.
- **Layer 2, Workflow** (`skills/job-*.md`): multi-step chains that compose task skills, own interaction policy (approval gates or fully autonomous) and state handoffs, and may persist approved orchestration artifacts.
- **Layer 3, Task** (`skills/task-*.md`): atomic operations with concrete behavior contracts. Each does one thing well.

**Cheap-model friendly.** Router is a semantic classification table; workflows are numbered dispatch chains; execution tasks use machine-verifiable done predicates; read-only tasks return structured verdicts; budgets are bounded (`task-yugong` caps at 13 baskets).

The full design walkthrough is in [`INTRODUCTION.md`](INTRODUCTION.md), under "Design overview: three-layer architecture".

## Repository layout

```
.
├── AGENTS.md                              ← index + workflow discipline
├── CLAUDE.md → AGENTS.md                  ← symlink (Claude Code)
├── README.md                              ← this file
├── README_zh.md                           ← Chinese version
├── windows_setup.ps1                      ← Windows workspace setup script
├── skills/                                ← each contains SKILL.md
│   ├── task-single-plan/
│   ├── task-multi-build/
│   ├── task-general/
│   ├── task-explore/
│   ├── task-librarian/
│   ├── task-multimodal-looker/
│   ├── task-judge/
│   ├── task-clarify/
│   ├── task-challenge/
│   ├── task-checkpoint/
│   ├── task-quick-verify/
│   ├── task-debug/
│   ├── task-strategy/
│   ├── task-yugong/
│   ├── task-repo-analyze/
│   ├── task-distill-spec/
│   ├── task-doc-write/
│   ├── task-why-how-what/
│   ├── job-plan/
│   ├── job-build/
│   ├── job-verify/
│   ├── job-debug/
│   ├── job-align/
│   ├── job-review/
│   ├── job-pr-maintain/
│   ├── job-security-review/
│   ├── job-debug-deep/
│   ├── job-spiral-up/
│   └── job-scamper/
├── .opencode/
│   └── skills/                            ← symlinks → ../../skills/<slug>/
├── .claude/
│   └── agents/                            ← symlinks → ../../skills/<slug>/
└── .cursor/
    ├── rules/
    │   └── agents.mdc                     ← rules bridge (alwaysApply)
    └── agents/                            ← symlinks → ../../skills/<slug>/
```

Update `skills/<slug>/SKILL.md` or `AGENTS.md`, and the symlinks under `.claude/agents/`, `.cursor/agents/`, `.opencode/skills/*/SKILL.md`, and `CLAUDE.md → AGENTS.md` follow automatically.

## Installation

### Independent workspace pattern

Create a workspace directory that holds the agent config; put source repo(s) as subdirectories inside it. Open the workspace directory in your AI tool; it reads the agent config from the workspace root, and source repos in subdirectories stay untouched.

Layout:

```
workspace/
├── AGENTS.md               ← from aia_kaiwu
├── CLAUDE.md               ← from aia_kaiwu
├── skills/                 ← from aia_kaiwu (canonical capability definitions)
├── .claude/                ← from aia_kaiwu
├── .cursor/                ← from aia_kaiwu
├── .opencode/              ← from aia_kaiwu (opencode skill registration)
└── source-repo/            ← the actual git repo (unchanged)
```

Setup on **macOS / Linux**:

```bash
mkdir -p ~/workspace
cd ~/workspace

# Option A: copy (workspace evolves independently of aia_kaiwu source)
cp -R /path/to/aia_kaiwu/{AGENTS.md,CLAUDE.md,skills,.claude,.cursor,.opencode} .

# Option B: symlink (workspace tracks upstream via `git pull` in the aia_kaiwu clone)
ln -sf  /path/to/aia_kaiwu/AGENTS.md AGENTS.md
ln -sf  /path/to/aia_kaiwu/CLAUDE.md CLAUDE.md
ln -sfn /path/to/aia_kaiwu/skills    skills
ln -sfn /path/to/aia_kaiwu/.claude   .claude
ln -sfn /path/to/aia_kaiwu/.cursor   .cursor
ln -sfn /path/to/aia_kaiwu/.opencode .opencode

# Clone source repo(s) as subdirectory
git clone <source-repo-url> source-repo
```

Setup on **Windows** (PowerShell):

```powershell
# 1. Create the workspace and clone aia_kaiwu into it
mkdir C:\workspace -Force
cd C:\workspace
git clone <aia_kaiwu-repo-url> aia_kaiwu

# 2. Run the setup script (copies real files, generates tool-dir skill entries)
.\aia_kaiwu\windows_setup.ps1

# 3. Clone your source repo(s) as a subdirectory
git clone <source-repo-url> source-repo
```

If PowerShell execution policy blocks the script: `powershell -ExecutionPolicy Bypass -File .\aia_kaiwu\windows_setup.ps1`.

To pull upstream aia_kaiwu updates later, re-run `.\aia_kaiwu\windows_setup.ps1`; it pulls updates and replaces generated config.

> **Note:** The `aia_kaiwu\` clone is authoritative; the script replaces generated workspace copies.

Daily use: open the workspace root (`~/workspace` on macOS / Linux, `C:\workspace` on Windows) in your AI tool. Run git commands from inside `source-repo/`.

Multiple source repos can live under one workspace; they share the same agent config. To start fresh, create a new empty workspace directory; no uninstall needed.

## Per-tool auto-load status

| Tool                                     | Native `AGENTS.md` at root | Bridge / instruction file we ship  | Native subagent files we ship        | Parallel subagent orchestration?     |
| ---------------------------------------- | -------------------------- | ---------------------------------- | ------------------------------------ | ------------------------------------ |
| **opencode**                             | native                   | none                       | none (skills reached via `skill(name=...)` on demand) | `task` tool with parallel + background dispatch (platform built-ins only) |
| **Cursor**                               | native                   | `.cursor/rules/agents.mdc` | `.cursor/agents/*.md` | built-in, nested subagents        |
| **Claude Code** (Anthropic CLI)          | via bridge                 | `CLAUDE.md → AGENTS.md`             | `.claude/agents/*.md` | Task tool, parallel                |
| **VS Code + Copilot Chat**               | native (`chat.useAgentsMdFile`) | also honors `CLAUDE.md` via `chat.useClaudeMdFile` | auto-scans `.claude/agents/*.md` | via `runSubagent`, nested to 5 with setting |

Full per-tool setup detail follows.

**Minimum versions required:**

- **opencode**: any current version.
- **Cursor**: any current version.
- **Claude Code**: any current version.
- **VS Code + Copilot**: VS Code **1.99+**.

## Default state after activation

Once any of the tools above loads `AGENTS.md`, the assistant is in the **aia_kaiwu skill/workflow system by default**:

- The active skill is `task-yugong` (single scoped task, no delegation, grind until done).
- Internal delegation goes only to `task-*` and `job-*` sub-agents. The platform's built-in `plan`/`build`/`general`/`explore`/`librarian`/`multimodal-looker` are never used as a shortcut.
- Explicit user invocation overrides this. `@plan` calls opencode's platform plan; `@task-single-plan` calls this project's strict plan.
- If the message better fits another custom skill (`task-clarify` for ambiguous scope, `task-single-plan` for architecture, `task-explore` for search, etc.), the assistant routes there per the semantic routing table in `AGENTS.md` section 3.0.

Full rule spec: `AGENTS.md` section 3.0.

---

## opencode setup

opencode reads `AGENTS.md` at the workspace root as always-on instructions.

### What auto-loads

| File | Loaded when | Purpose |
|---|---|---|
| `AGENTS.md` (repo root) | Session start | Always-on operating rules, including section 3.0 default routing to `task-*` / `job-*` skills |
| `skills/task-*.md` and `skills/job-*.md` | On demand via `skill` tool | Full behavior contract for each skill or workflow, pulled in when the AI needs it |

### Verify it works

1. Open the workspace in an opencode-capable client.
2. Ask: "What are you following from AGENTS.md right now?"
3. Expect the AI to state: default state is `task-yugong` (single scoped task, no delegation), per AGENTS.md section 3.0.
4. Ask a scoped implementation task; expect the AI to run it under the `task-yugong` contract (todo list, verify each step, stop and report if scope grows).

### Known limitations

- No native `@task-<slug>` / `@job-<slug>` subagent dispatch. These names remain text-level skill selectors; the AI maps them to `skill(name="<slug>")` in the parent context.
- No `subagent_type="task-<slug>"` or `subagent_type="job-<slug>"` in the `task` tool. Sub-agents dispatched via `task` use opencode's platform built-ins (`plan`, `build`, `general`, `explore`, `librarian`, `multimodal-looker`), not the strict `task-*` / `job-*` contracts.
- Skills load on demand rather than always-on; long sessions may need a mid-session `skill(name="task-<slug>")` or `skill(name="job-<slug>")` re-invocation.

---

## Cursor setup

Cursor honors `AGENTS.md` at the workspace root natively as always-on rules.

### What auto-loads

| File | Loaded when | Purpose |
|---|---|---|
| `AGENTS.md` (repo root) | Session start | Always-on operating rules |
| `.cursor/rules/agents.mdc` | Session start (`alwaysApply: true`) | Bridge that references `@AGENTS.md` |
| `.cursor/agents/*.md` | On agent invocation | Native subagents for all capabilities |

Each `.cursor/agents/<slug>/SKILL.md` is a symlink to `skills/<slug>/SKILL.md`. YAML frontmatter carries `name`, `description`, `model`, and `is_background`.

### Verify it works

1. Open the repo in Cursor and start a chat.
2. Type `@`: the agent picker should list capability names alongside Cursor's built-ins.
3. Send `@task-judge run a two-axis audit on the current diff` and confirm the custom persona responds under its adversarial audit contract.

### Parallel and background dispatch

- **Parallel subagents**: the parent dispatches multiple named agents in one turn via the built-in Task facility; results return as separate bubbles in the chat.
- **Nested subagents**: subagents can themselves dispatch further subagents. Nesting is capped by Cursor at a small depth.
- **Cloud Agents**: `/in-cloud` pushes a task to Cursor's cloud infrastructure; completion is pushed to iOS, Slack, and Live Activities. Local ↔ Cloud handoff is a one-click Agents Window action.
- **Local hooks**: `.cursor/hooks.json` accepts `stop`, `subagentStop`, and `afterAgentResponse` hooks. Use these to wire desktop notifications on completion (Cursor has no built-in local-chat notification toggle).

### Handoff

- Parent → subagent handoff is automatic; parent builds a curated prompt for the subagent.
- Local ↔ Cloud is transparent through the Agents Window.
- Main chat ↔ side chat inherits context.
- `Resume agent <id>` continues a completed subagent with full history.

### Known limitations

- Subagents start with a curated prompt built by the parent, not the full parent transcript.
- Some hooks (`sessionStart`, `sessionEnd`, MCP hooks, Tab hooks, `workspaceOpen`) do not run inside Cloud Agents.
- Cloud Agents force Max Mode; local hook behavior does not mirror cloud behavior perfectly.

---

## Claude Code setup

Claude Code reads `CLAUDE.md` at the repo root as project instructions and also honors `AGENTS.md`.

### What auto-loads

| File | Loaded when | Purpose |
|---|---|---|
| `CLAUDE.md → AGENTS.md` (symlink) | Session start | Project instructions |
| `.claude/agents/*.md` | On agent invocation | Native subagents for all capabilities |

Each `.claude/agents/<slug>/SKILL.md` is a symlink to `skills/<slug>/SKILL.md`. YAML frontmatter uses Claude Code's schema: `name`, `description`, optional `tools` whitelist, optional `model`.

### Verify it works

1. `cd` into the repo and start `claude`.
2. Ask: "What agents can you dispatch to?"
3. Expect the capabilities listed as first-class subagents.
4. Dispatch: "Use the Task tool to run `@task-explore` and `@task-librarian` in parallel." Two subagent runs should appear side by side.

### Parallel and background dispatch

- **Parallel subagents**: the Task tool spawns subagents from one turn. Multiple Task calls in a single message run concurrently.
- **Background shell**: the Bash tool supports `run_in_background=true` for long shell commands with output polling. This is for shell tasks, not for subagent orchestration.
- **Cross-subagent handoff**: none. The subagent returns its final message to the parent; the parent orchestrates the next dispatch by calling Task again with the next skill.

### Known limitations

- No post-response handoff buttons; no auto-submit.
- No cross-session state handoff beyond the `CLAUDE.md` project context.
- No separate background-subagent callback primitive (background applies to shell commands only).

---

## VS Code + GitHub Copilot Chat setup

VS Code Copilot Chat auto-scans `.claude/agents/*.md` at the workspace root.

### What auto-loads

| File | Setting | Default |
|---|---|---|
| `AGENTS.md` (repo root) | `chat.useAgentsMdFile` | **on** |
| `CLAUDE.md` (repo root, symlink) | `chat.useClaudeMdFile` | **on** |
| `.claude/agents/*.md` (skill symlinks) | auto (default agent location) | on |

Verbatim from the VS Code docs:

> "VS Code also detects `.md` files in the `.claude/agents` folder,
> following the Claude sub-agents format. This enables you to use the
> same agent definitions across VS Code and Claude Code."

Reference: <https://code.visualstudio.com/docs/agent-customization/custom-agents>

### Verify it works

1. Open the repo in VS Code, sign in to Copilot Chat.
2. Open Chat view → agents dropdown → confirm all capabilities appear alongside built-in agents.
3. Select one (e.g. `@task-judge`) and send a trivial prompt to confirm the persona instructions are in effect.
4. If a skill does not appear, right-click Chat view → **Diagnostics** → look for parse errors on the `.claude/agents/*.md` files.

### Optional: enable `handoffs:` / `agents:` frontmatter

The Claude sub-agent format supported in `.claude/agents/` covers `name`, `description`, `tools`, and `disallowedTools`. It does **not** support VS Code-only extras: `handoffs:` (post-response one-click buttons), `agents:` (parallel subagent allow-list), `user-invocable`, `disable-model-invocation`, `target`, `mcp-servers`, or `hooks`.

If you want those, hand-write `.github/agents/<slug>.agent.md`:

```yaml
---
name: <slug>
description: <one-line description shown in the agents dropdown>
model:
  - Claude Sonnet 4.5 (copilot)
  - GPT-5.2 (copilot)
# CRITICAL: must include 'agent' in tools if using the agents: field below.
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
  - label: <button label>
    agent: <target-slug>
    prompt: <pre-filled prompt>
    send: false                    # true = auto-submit
    model: Claude Sonnet 4.5 (copilot)
---

<paste the full contents of skills/<slug>/SKILL.md body>
```

**The `agent`-in-`tools:` gotcha.** Direct quote from the VS Code docs:

> "If you specify `agents`, ensure the `agent` tool is included in the
> `tools` property."

If `agents:` is present but `agent` is NOT in `tools:`, the agent loads but silently cannot invoke any subagent.

### Optional: enable nested subagents

Nested subagent invocation (subagent A calls subagent B) is off by default.

| Setting | Default | Max depth when enabled |
|---|---|---|
| `chat.subagents.allowInvocationsFromSubagents` | `false` | **5** |

Reference: <https://code.visualstudio.com/docs/agents/subagents#_nested-subagents>

### Settings quick reference

| Setting | Default | Purpose |
|---|---|---|
| `chat.agent.enabled` | `true` | Master switch for agent mode |
| `chat.useAgentsMdFile` | `true` | Load repo-root `AGENTS.md` |
| `chat.useClaudeMdFile` | `true` | Load `CLAUDE.md` variants |
| `chat.useNestedAgentsMdFiles` | `false` (Experimental) | Also load `AGENTS.md` in subfolders |
| `chat.subagents.allowInvocationsFromSubagents` | `false` | Allow subagent-to-subagent invocation |
| `chat.notifyWindowOnResponseReceived` | (off) | OS notification on completion |
| `chat.agentFilesLocations` | (defaults) | Extra locations for custom agent files |
| `chat.instructionsFilesLocations` | (defaults) | Extra locations for instructions files |

Reference: <https://code.visualstudio.com/docs/agents/reference/ai-settings>

### Known limitations

- The Claude sub-agent format loaded from `.claude/agents/` supports personas but not `handoffs:` / `agents:`. Use `.github/agents/*.agent.md` wrappers for those.
- `chat.useNestedAgentsMdFiles` is Experimental.
- Handoffs fire only on user click after a response completes; they are not automatic transitions.
- The requested model for a subagent cannot exceed the cost tier of the main model; higher-tier requests fall back.
- Custom agents apply to Chat and agent-mode interactions only, not to inline code suggestions.


## Verifying the config is active

Ask the assistant:

> "What capabilities are available in this project, and what does
> `@task-challenge` do?"

If it lists the complete capability set, including `job-spiral-up`, and describes `task-challenge` as a plan critic, the config is loaded.

For **Cursor**, **Claude Code**, and **VS Code + Copilot**, also test native dispatch:

> "Dispatch `@task-explore` and `@task-librarian` in parallel: find where
> `foo()` is called in this repo, and find the official API docs for
> `bar`."

If two subagent bubbles appear side by side and complete independently, native subagent orchestration is working. In opencode, project capabilities load via the `skill` tool and execute sequentially in the parent context; test each capability separately instead.

If the model skips skill loading, tell it: "Follow AGENTS.md workflow, load the skill file first."

## Updating the config

`AGENTS.md` and `skills/<slug>/SKILL.md` are authoritative:

1. **Capability behavior / discipline / index entry** → edit `skills/<slug>/SKILL.md` (or the shared rules in `AGENTS.md` section 3). Symlinks under `.claude/agents/`, `.cursor/agents/`, `.opencode/skills/*/SKILL.md`, and `CLAUDE.md` follow automatically.
2. **Capability tools, model, handoff targets, or subagent list** → edit the frontmatter block at the top of `skills/<slug>/SKILL.md`. All native surfaces read the frontmatter through the symlinks.
3. **Add or remove a capability** → update `AGENTS.md` section 3.0 routing table and the capability tables in `README.md` / `INTRODUCTION.md`; add/remove `skills/<slug>/SKILL.md`; create/delete the matching projections under `.claude/agents/`, `.cursor/agents/`, and `.opencode/skills/`.
4. `.cursor/rules/agents.mdc` references `@AGENTS.md`; only edit it if you change its own pointer section.

## Skills and Workflows

Full behavior contract for each capability lives in [`skills/<slug>/SKILL.md`](skills/). Deep design walkthrough (purpose, when to enter, methodologies, hard rules, handoffs, and three end-to-end scenarios) lives in [`INTRODUCTION.md`](INTRODUCTION.md) Part 2 and Part 3.

**Atomic skills** (`task-*`):

| Skill | One-line purpose |
|---|---|
| [`task-clarify`](skills/task-clarify/SKILL.md) | Critique the user's request itself. Recommend one clarifying question. |
| [`task-single-plan`](skills/task-single-plan/SKILL.md) | Planner. Produce numbered atomic steps or a spec/PRD. |
| [`task-challenge`](skills/task-challenge/SKILL.md) | Adversarial critique of a written plan. |
| [`task-checkpoint`](skills/task-checkpoint/SKILL.md) | Mid-execution checkpoint. `continue` / `adjust plan` / `halt`. |
| [`task-quick-verify`](skills/task-quick-verify/SKILL.md) | Throwaway prototype answering one design question. |
| [`task-strategy`](skills/task-strategy/SKILL.md) | Multi-session decision-ticket map. One non-research ticket per session. |
| [`task-multi-build`](skills/task-multi-build/SKILL.md) | Multi-domain implementer with delegation to specialists. |
| [`task-yugong`](skills/task-yugong/SKILL.md) | **Default.** Single-scope task, no delegation, grind until done. |
| [`task-general`](skills/task-general/SKILL.md) | Coordinator for mixed work when no specialist fits. |
| [`task-explore`](skills/task-explore/SKILL.md) | Contextual grep in-repo. |
| [`task-librarian`](skills/task-librarian/SKILL.md) | External docs, OSS repos, first-party APIs; primary sources only. |
| [`task-multimodal-looker`](skills/task-multimodal-looker/SKILL.md) | Describe or extract from images, PDFs, diagrams. |
| [`task-repo-analyze`](skills/task-repo-analyze/SKILL.md) | Analyze repo structure, conventions, tooling, CI. Token-intensive; prompts user; persists to `spec/repo-analyze/`. |
| [`task-distill-spec`](skills/task-distill-spec/SKILL.md) | Distill an overview-level project spec (glossary, domain model, principles, business logic) from existing docs into a preloadable file. Compress/define only, never infer; static snapshot. |
| [`task-doc-write`](skills/task-doc-write/SKILL.md) | Write documentation in four modes (api, architecture, guide, readme) with professional or accessible style. |
| [`task-judge`](skills/task-judge/SKILL.md) | Two-axis audit (Standards + Spec, kept separate). |
| [`task-debug`](skills/task-debug/SKILL.md) | Six-phase evidence-first hard-bug diagnosis loop. |
| [`task-why-how-what`](skills/task-why-how-what/SKILL.md) | One grounded pass from a single vantage: reason a starting point through the Golden Circle (Why→How→What) anchored in first principles, produce one result, no cross-result verdict. Domain-general. |

**Workflows** (`job-*`, chain atomic skills):

| Workflow | One-line purpose |
|---|---|
| [`job-plan`](skills/job-plan/SKILL.md) | Clarify → plan → challenge → approve → persist plan artifacts to `spec/<slug>/`. |
| [`job-build`](skills/job-build/SKILL.md) | Execute approved plan under TDD with checkpoints every ~3 steps. |
| [`job-verify`](skills/job-verify/SKILL.md) | Mid-execution checkpoint against the approved plan. |
| [`job-debug`](skills/job-debug/SKILL.md) | First-pass bug diagnosis; auto-escalates to `job-debug-deep` for hard bugs. |
| [`job-align`](skills/job-align/SKILL.md) | Bring documentation back into alignment with code. |
| [`job-review`](skills/job-review/SKILL.md) | Pre-completion review: challenge → judge → sweep. |
| [`job-pr-maintain`](skills/job-pr-maintain/SKILL.md) | PR review lifecycle: fresh first-principles review of the diff → read human comments → fix → update description → reply. Posts only after user confirmation; GitHub writes require authorization. |
| [`job-security-review`](skills/job-security-review/SKILL.md) | End-to-end security audit chain (locate → judge + librarian → optional debug). |
| [`job-debug-deep`](skills/job-debug-deep/SKILL.md) | Six-phase hard-bug diagnosis end-to-end. |
| [`job-spiral-up`](skills/job-spiral-up/SKILL.md) | Single-session autonomous convergence for "loop until done", "keep going until complete", and equivalent requests; execution remains bounded. |
| [`job-scamper`](skills/job-scamper/SKILL.md) | Multi-angle solution builder: initial solution → SCAMPER-decompose across seven angles (discard unreasonable/seen) → dispatch task-why-how-what per angle → re-evaluate optimum by Pareto + logical self-consistency → until no new reasonable angle. Comprehensive, not fault-finding. |

## License

GPL-3.0. See [`LICENSE`](LICENSE).
