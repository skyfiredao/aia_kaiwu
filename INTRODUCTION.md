# INTRODUCTION: How to Use the Kaiwu Agent Workflow System in Software Engineering

This document introduces the design philosophy, roles, methodologies, and typical usage of the *aia_kaiwu* agent workflow system. It is aimed at software engineers who want to understand **what the system does, why it is designed this way, and how to use it in real development work**. For installation instructions see `README.md`.

## Preface

*aia_kaiwu* borrows its name from [*Tiangong Kaiwu*](https://en.wikipedia.org/wiki/Tiangong_Kaiwu), the 1637 encyclopedia by Song Yingxing that catalogued every craft and production technique of the era. Each craft in that book was a discipline with its own masters, tools, and protocol. One role per craft, each with an explicit behavior contract embedded in `skills/<role>.md`. Role slugs use two prefixes. `task-*` denotes single-step skills, `job-*` denotes multi-step workflows.

The document has three parts. Part 1 defines the named methodologies that shape role behavior. Part 2 lists atomic skills and multi-step workflows with their entry conditions and handoffs. Part 3 walks three realistic development situations end-to-end. Read Part 1 in order; Part 2 and Part 3 can be scanned in any order once Part 1 is understood.

---

## Design overview: three-layer architecture

Unlike a flat multi-agent config where every capability sits at the same level, this project layers three distinct concerns:

| Layer | File pattern | Role | Count |
|---|---|---|---|
| 1. Router | `AGENTS.md` | Reads every user message; classifies intent semantically per section 3.0's routing table and dispatches to the right workflow or skill. No keyword table, no ask-before-dispatch; ambiguous intent routes to `@task-clarify`. | 1 |
| 2. Workflow | `skills/job-*.md` | Multi-step chains that compose task skills, own approval gates and state handoffs, and may persist approved orchestration artifacts. Production-code behavior stays in invoked tasks. | 8 |
| 3. Task | `skills/task-*.md` | Atomic operations with concrete behavior contracts (Purpose / Hard constraints / Output shape / Handoff). Each task does one thing well. | 14 |

Composition:

- User sends a message → **Layer 1 (`AGENTS.md`)** classifies intent semantically via section 3.0's routing table.
- Multi-step intent → dispatch to a **Layer 2 (`job-*`)** workflow, which then calls one or more **Layer 3 (`task-*`)** skills in a defined chain.
- Single atomic intent → dispatch directly to a **Layer 3 (`task-*`)** skill.
- Ambiguous intent → dispatch to `@task-clarify`. The router still routes; clarification happens through skill invocation, not through router-level dialog.

### Why three layers, not one flat list

- A flat 22-agent list forces users (and the AI) to memorize when each of ~20 capabilities applies. Layering separates *what workflow* (job) from *what action* (task) from *how to decide* (router).
- Workflows are reusable business flows (plan-approve-build-review, security audit, hard-bug diagnosis, doc-code alignment). Tasks stay focused on one discipline. The router adapts routing to the tool.
- Production-code rules live in tasks. Workflows add only orchestration rules such as approval gates, sequencing, state handoff, and persistence of approved plan artifacts; they never loosen task rules. The router contains only dispatch logic.

### Why this design fits cheap models well

Frontier models are not required for most operations here. The three-layer design makes cheap models effective and cost-efficient:

- **Router (Layer 1)** is a semantic classification table (section 3.0). The AI matches the user's intent to a table row, a task any capable LLM handles reliably.
- **Workflows (Layer 2)** are numbered dispatch chains (`call task-A → task-B → gate → task-C`). No open-ended reasoning; just follow the numbered steps.
- **Execution tasks (Layer 3)** use explicit machine-verifiable predicates (test passing, exit code 0, expected output present, HTTP status match, etc.) for done gates. Read-only tasks use structured verdicts and cited evidence.
- **Bounded budgets** (`task-yugong` caps a session at 13 baskets; no-progress detection halts thrashing) prevent runaway loops that rack up cost.
- **Ambiguity handled by `@task-clarify`**: one focused clarifying question via skill invocation is cheaper than five rounds of ambiguity chasing and does not require the router to ask.

Net effect. A cheap model reading this config can execute complete workflows (plan → build → verify → review) with tight cost caps and clear success predicates, matching or beating a frontier model set loose without structure. Cost drops; execution speed rises; the AI stops on the right conditions instead of grinding indefinitely.

### File layout

- `skills/task-*.md` (14): atomic skills
- `skills/job-*.md` (8): multi-step workflows
- Tool registration (`.claude/agents/*.md`, `.cursor/agents/*.md`, `.opencode/skills/*/SKILL.md`) uniformly symlinks the same 22 canonical files, so every supported tool sees the same behavior contracts.

### Capability matrix per host tool

Modern coding assistants ship real agent orchestration. Current per-surface status for the three capabilities this config cares about:

| Capability                                                | opencode           | Cursor             | Claude Code                                                                    | VS Code + Copilot                            |
| --------------------------------------------------------- | ------------------ | ------------------ | ------------------------------------------------------------------------------ | -------------------------------------------- |
| Parallel subagents from one chat turn                     | Partial (platform built-in `plan`/`build`/`general`/`explore`/`librarian`/`multimodal-looker` via `task` tool may run in parallel; `task-*` / `job-*` project roles load via `skill(name=...)` and run **sequentially** in shared context) | Yes (built-in `explore`/`bash`/`browser`; custom `.cursor/agents/*.md`; nested up to 2 levels) | Yes (`.claude/agents/*.md`; Task tool parallel invocation) | Yes (auto-loads `.claude/agents/*.md`; `agent/runSubagent` + `.agent.md` wrappers; nested to 5 with setting) |
| Background tasks with completion callback / notification  | Yes (`run_in_background=true` on subagent dispatch; `<system-reminder>` completion notifications) | Yes (background subagents + `stop`/`subagentStop` hooks; Cloud Agents + iOS push / Slack / Live Activities) | Partial (Bash `run_in_background=true` for shell tasks; no separate background subagent callback) | Yes (`chat.notifyWindowOnResponseReceived`; Copilot CLI background sessions; Hooks Preview) |
| Automatic state handoff between agent modes / personas    | Yes (parent → subagent with continuation session ids; `task(task_id=…)` resumes with full context) | Yes (parent → subagent; local ↔ cloud move; main ↔ side chat with context; resumable subagents by ID) | Partial (subagent returns final result to parent; parent orchestrates next dispatch) | Yes (`handoffs:` frontmatter with optional `send: true` auto-submit; Session Target dropdown; Continue in Cloud; Plan → Agent) |

The runtime behavioral difference the AI must observe (per-tool dispatch, workflow chain semantics, opencode built-in disambiguation, manual handoff fallback rule) is defined in `AGENTS.md` section 3.0.1. Per-tool install steps and full setup detail live in [`README.md`](README.md).

---

## Part 1: Methodologies

Named methodologies are the atomic units of behavior. Each has a precise trigger, a hard rule, an anti-pattern, and a concrete micro-example. Skim the table below, then read each section.

| Methodology | Owner role(s) | One-line summary |
|---|---|---|
| First-Principles Derivation | `task-single-plan` | Derive the plan from irreducible constraints, not from convention. |
| First-Principles Decomposition | `task-clarify` | Decompose the request to the root problem before answering. |
| Tracer-Bullet Vertical Slicing | `task-single-plan` | Each plan step cuts a narrow but complete path through every layer. |
| Expand → Migrate → Contract | `task-single-plan` | Wide-blast changes go in three sequential batches. |
| Adversarial Review | `task-judge`, `task-challenge`, `job-plan`, `job-review`, `job-security-review` | Review as an attacker, not an advocate. Every finding names a concrete failure mode. |
| Fowler Smell Baseline | `task-judge`, `job-review`, `job-security-review` | Standard smell list applied when repo has no local convention. |
| TDD Discipline | cross-cutting (`task-multi-build`, `job-build`) | Red → green → refactor, one behavior at a time, tests live at seams. |
| Loop Engineering | `task-yugong`, `job-build` | One clearly-scoped task, no delegation, iterate until verified. Stop and report if scope grows. |
| Six-Phase Evidence-First Loop | `task-debug`, `job-debug`, `job-debug-deep` | Bug diagnosis in six ordered phases; feedback loop before any hypothesis. |
| SHA1 Debug Session Prefix and Record File | `task-debug`, `job-debug-deep` | Every debug log line carries a session-unique SHA1 tag for one-grep cleanup. |
| Fog-of-War Mapping | `task-strategy` | Chart what you can state precisely; leave the rest as fog until it can be named. |
| Dual-Branch Prototyping | `task-quick-verify` | Throwaway prototype in one of two branches: logic-heavy terminal app, or UI variant set. |
| Primary-Source-Only Research | `task-librarian`, `job-security-review`, `job-debug-deep` | Docs, source code, first-party APIs only. No secondary write-ups. Every claim cited. |
| Mid-Execution Checkpoint | `task-checkpoint`, `job-build`, `job-verify` | Read-only checkpoint every ~3 steps or before any major state transition. Verdict is `continue` / `adjust plan` / `halt`. |

### First-Principles Derivation

**What it is.** Before writing a plan, list the irreducible constraints the solution must satisfy. These include data shape, domain rule, performance budget, external contract, security requirement. Then derive the plan from those constraints. Do not derive it from "we usually do X" or from the shape of the last similar feature.

**Why it works.** Convention accumulates decisions whose justifications are lost. Deriving from constraints re-checks whether those decisions still fit *this* problem. If your derived plan matches convention, the match is verified rather than assumed.

**When to invoke.** Every non-trivial planning session (`task-single-plan`). Also whenever you catch yourself saying "we always do it this way" and cannot name the constraint that justifies it.

**Anti-pattern.** Circular justification: "we do X because we do X" or "convention says X, so X is correct". If the derivation loops back to the convention itself, no derivation happened.

**Micro-example.** A request comes in to add a "user preferences" endpoint. Convention says REST GET `/users/:id/preferences`. Deriving from constraints. Preferences are read on every page load (performance budget sub-100ms), preferences are per-user (auth boundary), the client caches them (staleness tolerance 5 min). The derivation reveals that a small JSON blob returned inline with the user profile fits the constraints better than a separate endpoint; the convention would have caused an extra roundtrip.

### First-Principles Decomposition

**What it is.** The request the user typed is one candidate solution. Decompose it to the root problem. Ask what outcome the user actually needs, what constraints are real, what is stylistic preference dressed as requirement. If a simpler solution falls out of the root problem, name it as an alternative reading.

**Why it works.** Users express what they think they want, filtered by what they think is possible. The AI's job is to surface the real requirement before generating code, because implementing a candidate solution when a simpler one solves the same problem wastes both parties' time.

**When to invoke.** Every ambiguous or larger-than-one-turn request (`task-clarify`). Never treat "the user asked for X" as sufficient justification for X when X does not obviously derive from the root problem.

**Anti-pattern.** Compliance-only: "you asked for X, I built X". This is what shallow LLM assistants do. It optimizes for looking helpful and against being useful.

**Micro-example.** User says "Add a feature flag to disable the export button". Decomposition asks what the actual problem is. Probably "export takes too long and users click it repeatedly, overloading the server". The root problem might be solved by disabling the button *during* export (client-side state), not by a feature flag. `task-clarify` surfaces both readings and asks which one the user meant.

### Tracer-Bullet Vertical Slicing

**What it is.** Each plan step cuts a narrow but complete path through every layer of the system (schema, API, UI, tests), sized to fit one fresh context window and demoable on its own. Later slices widen the path.

**Why it works.** Horizontal slicing (all schema first, all API second, all UI last) locks in shape before you know what shape you need. Vertical slicing produces a working end-to-end thread at every step; each thread teaches you what the next thread must do.

**When to invoke.** Every multi-step plan (`task-single-plan`). Especially when introducing a new feature that spans layers.

**Anti-pattern.** "Let's design the schema first, then the API, then the UI." By the time the UI reveals the schema was wrong, the schema is already in prod.

**Micro-example.** For a "user comments on posts" feature, a horizontal plan writes six migrations, four endpoints, three UI components, twelve tests. A vertical plan writes one migration, one endpoint, one UI element, one test, all just enough to display a single hard-coded comment; then the next slice adds authoring; then editing; then threading. Each slice is shippable.

### Expand → Migrate → Contract

**What it is.** For changes with wide blast radius (rename a shared column, retype a shared symbol, split a shared function), sequence the work as three sequential phases:

- **Expand**: add the new form beside the old. Both coexist.
- **Migrate**: move call sites from old to new, in batches sized by blast radius.
- **Contract**: delete the old form once no caller remains.

**Why it works.** A single-shot rename touches everything at once; a failure halfway through leaves the codebase in an inconsistent state. Expand-migrate-contract keeps every intermediate state runnable and reversible.

**When to invoke.** Any refactor whose call-site count exceeds what one session can touch confidently (`task-single-plan` sequences this into the plan).

**Anti-pattern.** "Just rename it globally with sed and commit." Works until it doesn't; then untangling the failure state costs 10x more than the batched migration would have.

**Micro-example.** Renaming a database column `created` to `created_at`:

- **Expand**: add `created_at`; write triggers to keep both in sync.
- **Migrate**: update readers in batches (query builders first, then reports, then dashboards).
- **Contract**: drop the triggers, drop the old column, remove the sync code.

### Adversarial Review

**What it is.** Review the artifact as an adversary, not an advocate. Do not build a case for why it is fine; build the case for how it fails. Every finding names a concrete failure mode (an input that breaks it, a sequence that races it, a requirement it misses), not a vague concern. Attack from at least three orthogonal angles per review (e.g. correctness, performance, security, maintainability, spec drift).

**Why it works.** Advocates find nothing because their prior is "this works". Adversaries find real defects because their prior is "this fails". The finding-to-word ratio is the metric; "looks fine" is not a verdict.

**When to invoke.**
- Post-implementation audit of code (`task-judge`)
- Pre-execution review of a written plan (`task-challenge`)
- Anywhere an "official-sounding but under-attacked" artifact needs to be pushed against

**Anti-pattern.** Polite hedging that hides real defects: "you might consider…", "one could argue…". If the reviewer cannot name a concrete failure, the review found nothing.

**Micro-example.** Reviewing a login endpoint. Advocate says "looks clean, well-tested". Adversary says: "what happens if `email` is 10 MB long?" (DoS via memory) → concrete finding. "What happens if two requests arrive in the same microsecond with different passwords?" (race) → concrete finding. "What is the response for a nonexistent user versus a wrong password?" (user enumeration via timing) → concrete finding.

### Fowler Smell Baseline

**What it is.** Martin Fowler's *Refactoring* chapter 3 lists a set of "code smells" that reliably indicate design problems. `task-judge`'s Standards axis applies this list when the repo documents no local convention on the point in question. All smells are judgment calls, not hard violations; a documented repo standard always wins.

**Common smells applied**:

- **Mysterious Name**: rename it; if no honest name comes, the design is murky.
- **Duplicated Code**: extract the shared shape.
- **Feature Envy**: move the method onto the data it envies.
- **Data Clumps**: group repeated field sets into one type.
- **Primitive Obsession**: give the domain concept its own small type.
- **Repeated Switches**: replace with polymorphism or a shared map.
- **Shotgun Surgery**: gather what changes together into one module.
- **Divergent Change**: split so each module changes for one reason.
- **Speculative Generality**: delete unused parameters and abstractions.
- **Message Chains**: hide the walk behind one method.
- **Middle Man**: cut the pass-through and call the real target.
- **Refused Bequest**: drop the inheritance, use composition.

**Why it works.** A named smell is a shared vocabulary between reviewer and reviewee. "This is Feature Envy" is easier to defend, debate, and refactor away than "this looks off".

**When to invoke.** Standards-axis review inside `task-judge`, when the local repo has no rule.

**Anti-pattern.** Treating smells as hard rules. Every smell has legitimate exceptions; the reviewer's job is to flag them, not to demand they disappear.

### TDD Discipline

**What it is.** Test-driven development, applied strictly:

1. Write a failing test that captures the desired behavior.
2. Run the test and confirm it fails for the *right* reason (not a syntax/import/setup error).
3. Write the minimum production code to make the test pass.
4. Refactor with the test as safety net. This refactor is scoped to what you just wrote in step 3, not to neighboring code.

Applies to new features, bug fixes (write a regression test that reproduces the bug first), and API changes.

**Two hard sub-rules:**

- **Tests live at seams**, never against internals. A seam is the public interface where you observe behavior without reaching inside. Name the seam before writing the test.
- **Vertical slicing**: one test, one implementation, one cycle. Never write all tests first then all implementation ("horizontal slicing"); that verifies imagined behavior and locks in shape before you understand the implementation.

**Anti-patterns to reject:**

- **Implementation-coupled test**: mocks internal collaborators, tests private methods, verifies through a side channel. The test breaks when you refactor even though behavior did not change.
- **Tautological test**: `expect(add(a, b)).toBe(a + b)`. Passes by construction; can never disagree with the code. Expected values must come from an independent source of truth.
- **Horizontal slicing**: as above.

**When to invoke.** Cross-cutting across all execution roles (`task-multi-build`, `task-yugong`). Explicit exceptions include throwaway spike/experiment scripts, config-only edits, docs, dependency version bumps.

**Micro-example.** Adding a `discount()` function. The wrong approach writes ten tests covering every discount tier, then implements. The right approach writes one test for a 10% off case, watches it fail, implements, refactors; next cycle adds the 20% tier; next adds the stackable case; each cycle produces working code.

### Loop Engineering

**What it is.** The default execution mode of `task-yugong` (the Old Man Who Moved the Mountain, from an ancient Chinese fable). Take one clearly-scoped task and grind through it under full discipline until it is done and verified. Do not delegate the primary work. Retry up to 3 times per step. If the task turns out to be larger than expected, **stop and report** to the user; never silently expand scope.

**Why it works.** Most real work is not multi-domain and does not benefit from delegation. Delegation adds coordination overhead, ambiguity in ownership, and risk of specialist output disagreement. A single grinder finishes what a coordinated team would spend the same time debating.

**When to invoke.** Any concrete task with a clear single scope. `task-yugong` is the **default role** when the user gives an implementation task without naming a role.

**Anti-pattern.**

- **Silent scope expansion**: task turns out bigger; `task-yugong` keeps going and finishes something the user did not ask for.
- **Reflexive delegation**: dispatching sub-agents that are not needed. Coordination cost > direct execution.

**Micro-example.** User says "the login page has a 2-pixel misalignment on mobile Safari; fix it". `task-yugong` reproduces, finds the wrong flexbox value, fixes it, adds a regression screenshot test, verifies on iOS Safari, reports. If in the middle it turns out the misalignment is a symptom of a broken CSS design token that affects 40 other pages, `task-yugong` stops and reports the finding; it does not silently fix all 40.

### Six-Phase Evidence-First Loop

**What it is.** `task-debug` diagnoses hard bugs in six ordered phases. It stays read-only, builds the evidence, and specifies instrumentation, tests, and fixes for a writable executor. Skipping phases is only allowed when explicitly justified.

- **Phase 1: Build a feedback loop.** Construct one command that goes red on this bug and green when fixed. The loop must be red-capable (drives the actual bug code path), deterministic (same verdict every run), fast (seconds), agent-runnable (unattended). **Do not proceed to hypotheses without a loop.**
- **Phase 2: Reproduce + minimise.** Run the loop, watch it go red. Shrink the repro one element at a time; every remaining element must be load-bearing.
- **Phase 3: Hypothesise.** Generate 3-5 ranked, *falsifiable* hypotheses before testing any. Show the ranked list to the user; domain knowledge often re-ranks instantly.
- **Phase 4: Instrument.** Debugger/REPL first. If writes are needed, specify targeted instrumentation for the executor. Change one variable at a time.
- **Phase 5: Fix + regression test.** Specify a regression test and minimal fix at a correct seam. The executor writes the test **before the fix**.
- **Phase 6: Cleanup + post-mortem.** Re-read executor evidence. Confirm the original repro no longer reproduces, the regression test passes, and all debug instrumentation is removed.

**Why it works.** Phase 1 (the feedback loop) is the entire skill; every subsequent phase is mechanical once the loop exists. Debugging without a loop is guessing.

**When to invoke.** Hard bug or perf regression that resisted a first fix, flaky "sometimes fails" behavior, chain of symptoms with no obvious cause.

**Anti-pattern.**

- **Shotgun debugging**: change three things at once, hope one worked.
- **Log-then-grep**: dump everything, grep later, drown in signal.
- **Fix without test**: no regression test locks in the bug for reintroduction.

**Micro-example.** A test occasionally fails on CI:

- **Phase 1**: reproduce locally by running the test in a loop with `--repeat 100`; observe 3 failures.
- **Phase 2**: strip the test to the minimum body that still fails 3/100.
- **Phase 3**: hypothesise (a) shared mutable state, (b) timezone-dependent assertion, (c) database ordering non-determinism.
- **Phase 4**: instrument the state before assertion; observe.
- **Phase 5**: fix the specific race with a lock; add a regression test that forces the race condition.
- **Phase 6**: verify, clean, document.

### SHA1 Debug Session Prefix and Record File

**What it is.** Every `task-debug` session that needs file-based instrumentation specifies a SHA1. The writable executor uses its first 8 characters as `[DEBUG-a3f9c2e1]` and records redacted session data in `spec/debug/<sha1_short>.md`.

**Why it works.** Debug logs are supposed to be temporary. Without a session prefix, cleaning them up requires visual inspection. With a per-session prefix, cleanup is one grep: `grep -rn "[DEBUG-a3f9c2e1]" | xargs sed -i '/DEBUG-a3f9c2e1/d'`. No debug log survives past its session by accident.

**When to invoke.** Any `task-debug` session that needs debug logging. Every proposed line must carry the tag.

**Anti-pattern.**

- **Unattributed `console.log("here")`** left in the codebase. This is how debug noise accumulates.
- **Reused prefix across sessions**: a `[DEBUG]` tag with no session identifier is uncleanable across concurrent debug work.

**Micro-example.** During a debug session with SHA1 prefix `a3f9c2e1`, the developer adds `console.log("[DEBUG-a3f9c2e1] user id at entry:", userId)` and `console.log("[DEBUG-a3f9c2e1] cache hit:", cached)`. After the fix is done and the regression test passes, one grep removes both lines. `spec/debug/a3f9c2e1.md` optionally survives as a post-mortem note.

### Fog-of-War Mapping

**What it is.** `task-strategy` charts a large multi-session effort as an issue-tracker map. The rule is **do not chart what you cannot state precisely**. Beyond the sharp tickets lies fog; write it loosely under `Not yet specified` and let it graduate to tickets as the frontier advances. Ticket types are `research` (resolved by `task-librarian`), `prototype` (resolved by `task-quick-verify`), `grilling` (resolved by `task-clarify`), and `task` (manual work that unblocks a decision).

**Why it works.** Premature specification of vague areas invents scope. Explicit fog is honest; it prevents the team from acting on assumptions that will change. As research or prototypes resolve, fog turns into precise tickets.

**When to invoke.** Work too large to fit in one agent session, with a foggy path to the destination, multiple decisions still to be made before execution can start.

**Anti-pattern.**

- **Over-planning**: writing 50 tickets covering unknowns. Most will be wrong; most will be re-written; the effort is wasted.
- **Charging at the destination**: ignoring fog, starting to build the guessed solution.
- **Resolving more than one non-research ticket per session**: rushes the map's evolution and defeats the point.

**Micro-example.** The task is "Migrate the app from Framework A to Framework B." `task-strategy` names the destination ("the app runs on B with feature parity"), then charts precise tickets such as `[task] set up B alongside A`, `[research] does B support our SSO adapter?`, `[prototype] port one screen and measure`, and `[grilling] do we deprecate A features that B has no equivalent for?`. Everything else stays as fog. Each session picks one ticket.

### Dual-Branch Prototyping

**What it is.** `task-quick-verify` builds throwaway code that answers one design question, choosing one of two branches:

- **logic branch**: an interactive terminal app that pushes a state machine through hard-to-reason cases.
- **UI branch**: multiple radically different variants on a single route, URL-parameter switched with a floating toggle bar.

Throwaway from day one. One command to run. No persistence. No tests. No polish. Once the decision is validated, fold it into real code. Keep the prototype off main; create a throwaway branch or commit only when the current user message asks.

**Why it works.** A cheap concrete artifact answers many design questions faster than any amount of discussion. Two branches cover the two dominant shapes of design uncertainty (behavioral vs. visual).

**When to invoke.** "Does this feel right?" (UI branch). "What should this state machine actually do in the corner cases?" (logic branch). Any design question that generates more meetings than progress.

**Anti-pattern.**

- **Prototype creep**: adding tests, adding persistence, adding polish. The prototype becomes production by accident.
- **Merging the prototype to main**: locks in throwaway shape as permanent.

**Micro-example.** UI branch. Three candidate onboarding flows all live at `/onboard?v=1|2|3`; a floating toggle bar switches. Users click through all three in a hallway test. Winner is folded into `/onboard`; the toggle bar is deleted. Logic branch. A terminal app simulates the state machine of a payment retry loop over 200 synthetic transaction traces; three edge cases surface that the specification did not anticipate.

### Primary-Source-Only Research

**What it is.** `task-librarian` follows every claim back to its owning source, including official docs, source code, specs, first-party APIs. Never a secondary write-up. Every claim in the output is cited with a URL or a concrete repo path (`owner/repo:file:line`). Claim types are distinguished:

- `[verified via docs]`: from official documentation
- `[verified via source]`: from reading the actual source code
- `[common pattern]`: from many observed examples in the wild, with representative link
- `[unverified, training snapshot]`: from model training data only, no live verification

**Why it works.** Secondary write-ups drift, misquote, and omit context. Primary sources are the ground truth the library maintainers themselves authored. Citation with URL or file:line makes claims independently checkable.

**When to invoke.** "How does library X work?", "What's the best practice for framework Y?", "How does OSS repo Z implement this?"

**Anti-pattern.**

- **Blog citation**: a random dev.to post is treated as authoritative.
- **Uncited claim**: "usually you do it this way" with no source.
- **Invented API signature**: describing an API that does not exist in the actual source. This is what shallow LLM assistants do; `task-librarian` refuses.

**Micro-example.** Question: "How do I use React Server Components with a database in Next.js 15?" `task-librarian` reads the official Next.js 15 App Router docs, cites the exact URL and section, cross-checks with the Next.js source repo for the actual `unstable_cache` behavior, cites the source file and line, and marks any claim that could not be verified as `[unverified, training snapshot]` so the caller knows what to double-check.

### Mid-Execution Checkpoint

**What it is.** `task-checkpoint` runs read-only during execution, not before or after. It verifies the in-progress work still matches the approved plan and can be safely continued. Verdict is one of `continue` / `adjust plan` / `halt`.

**When it fires:**

- Every ~3 steps of a multi-step plan.
- Before any major state transition (schema migration, deployment, `git push`).
- When the executor reports drift or unexpected friction.

**Why it works.** Execution drift is invisible from inside execution. A checkpoint role external to the execution loop notices "we're on step 4 but the plan assumed we'd have finished step 3's tests" before the drift compounds. Cheap intervention beats expensive rework.

**When NOT to invoke.** Before a plan exists (that's `task-clarify`'s job). After all work is done (that's `task-judge`'s job). At every single step (that's over-checkpointing, coordination cost > benefit).

**Anti-pattern.**

- **Rubber-stamp checkpoint**: `task-checkpoint` just says "continue" every time without actually reading the diff. Useless.
- **Late checkpoint**: waiting until the plan has drifted 10 steps before checking. The point is to catch drift *early*.

**Micro-example.** `task-multi-build` is on step 6 of a 12-step plan implementing an auth refactor. `task-checkpoint` reads the diff since step 3 (last checkpoint), notices the executor introduced a new dependency the plan didn't sanction, and returns `adjust plan`. The plan is updated to explicitly account for the new dependency (or the dependency is removed) before continuing.

---

## Part 2: Roles

Roles are grouped by phase of work. Each role card lists purpose, when to enter, methodologies inherited, handoff destinations, and when *not* to use it.

### 2.1 Decision and Planning

Roles that decide *what to build* and *how to sequence it*, before code is written.

#### `task-clarify`

- **Purpose**: Critique the user's request itself, not the code. Enumerate assumptions, ambiguities, and likely AI failure modes; recommend the single most valuable clarifying question.
- **When to enter**: The request is ambiguous, larger than one turn, or contains contradictions the user may not have noticed.
- **Methodologies**: First-Principles Decomposition
- **Hard rule**: Never proceeds past the draft without user's approval. No plan. No implementation.
- **Handoff**: `task-single-plan` (once the user clarifies)
- **Not for**: Requests that are already precise. Skipping straight to `task-single-plan` wastes a turn.

#### `task-single-plan`

- **Purpose**: Produce a written plan (or a spec/PRD for substantial work) that a single execution session can carry out. Read-only; never edits files.
- **When to enter**: Multi-step work (≥3 steps), architectural choice on the table, multiple modules touched, or scope not obvious.
- **Methodologies**: First-Principles Derivation, Tracer-Bullet Vertical Slicing, Expand → Migrate → Contract
- **Hard rule**: Stops after writing the plan. Waits for approval.
- **Handoff**: `task-challenge` (for review) → `task-multi-build` or `task-yugong` (for execution). For very large multi-session work, hand off to `task-strategy` first.
- **Not for**: Work that spans multiple sessions with foggy destination (use `task-strategy`).

#### `task-challenge`

- **Purpose**: Remonstrate against a written plan for clarity, completeness, and verifiability. For each step verify three things.
  - Is the file named?
  - Is the observable result stated?
  - Is the verification step defined?
- **When to enter**: A written plan exists (in chat, in a file, or produced by `task-single-plan`) and needs a rigorous critique before implementation.
- **Methodologies**: Adversarial Review
- **Hard rule**: No editing the plan; returns findings only. No polite hedging that hides a real defect.
- **Handoff**: `task-single-plan` (to revise) or `task-multi-build` / `task-yugong` (to execute if approved).
- **Not for**: Reviewing implemented code (that's `task-judge`).

#### `task-quick-verify`

- **Purpose**: Build throwaway code that answers one design question, when a cheap concrete artifact would answer faster than more discussion.
- **When to enter**: "Does this feel right?" / "What should it look like?" / "What does this state machine do in the corner cases?"
- **Methodologies**: Dual-Branch Prototyping
- **Hard rule**: Throwaway from day one. No tests, no polish, no persistence. Commit to a throwaway branch out of main.
- **Handoff**: `task-single-plan` (fold validated decision into real plan) or `task-multi-build` (integrate).
- **Not for**: Building production features. If it looks tempting to merge, remember the branch is throwaway.

#### `task-strategy`

- **Purpose**: Chart a large multi-session effort as a shared map of decision tickets. Resolve one ticket per session until the way to the destination is clear.
- **When to enter**: Work bigger than one agent session, foggy path to the destination, multiple decisions still to be made before execution can start.
- **Methodologies**: Fog-of-War Mapping
- **Hard rule**: Never charges at the destination. Never resolves more than one non-research ticket per session.
- **Handoff**: `task-librarian` (research ticket), `task-quick-verify` (prototype ticket), `task-clarify` (grilling ticket), `task-single-plan` (task ticket ready for execution planning).
- **Not for**: Small tasks that fit in one session. `task-strategy`'s overhead is only worth it for genuinely multi-session work.

### 2.2 Execution

Roles that write code and produce artifacts.

#### `task-multi-build`

- **Purpose**: Multi-domain implementer with active delegation to specialists. Executes changes across multiple modules and runs independent specialists in parallel where the host supports native subagents.
- **When to enter**: Task spans multiple modules or systems, benefits from delegating sub-tasks to `task-explore` / `task-librarian` / `task-judge` / `task-multimodal-looker`.
- **Methodologies**: TDD Discipline, Mid-Execution Checkpoint (dispatched every ~3 steps)
- **Hard rule**: No type suppression, no empty catch blocks, no destructive git actions without user confirmation, no unsolicited refactors while doing a bug fix.
- **Handoff**: `task-judge` (post-implementation audit).
- **Not for**: Single-scope tasks. Prefer `task-yugong`. Multi-domain coordination cost is only worth it when the work genuinely spans domains.

#### `task-yugong` (default role)

- **Namesake**: The Yugong fable tells of Old Man Yugong who moved a mountain little by little; the paradigm of scoped, patient, un-delegated labor. This role is the default executor. Take one clearly-scoped task, grind, verify, stop if scope grows.
- **Purpose**: Take one clearly-scoped task and grind through it under full engineering discipline until done and verified. This is the default role when the user names none.
- **When to enter**: Any concrete implementation task with a clear single scope.
- **Methodologies**: Loop Engineering, TDD Discipline
- **Hard rule**: No delegation of the primary task. Retry up to 3 times per step. If the task turns out larger than expected, **stop and report**; never silently expand scope.
- **Handoff**: None (terminates when done). May consult `task-checkpoint` mid-way or `task-judge` at end.
- **Not for**: Multi-domain tasks that genuinely need specialist delegation (use `task-multi-build`).

#### `task-general`

- **Purpose**: Read-only coordination of mixed research and execution across unrelated systems when no specialist role fits. Decompose and dispatch specialists; parallelize only where the host supports native subagents.
- **When to enter**: Task mixes research and execution across several unrelated systems and no single specialized role covers it.
- **Hard rule**: Never swallow specialist work that belongs to `task-explore`, `task-librarian`, `task-judge`, `task-multimodal-looker`, or `task-debug`; hand off.
- **Handoff**: Specialist roles per sub-task; return control to user with aggregated conclusion.
- **Not for**: Tasks that fit a single role. `task-general` is a fallback, not a first choice.

### 2.3 Search and Research

Roles that gather information without editing.

#### `task-explore`

- **Purpose**: Contextual grep inside this repository. Answers "where is X defined?", "which file handles Y?", cross-cutting pattern searches.
- **When to enter**: User asks where something is defined or handled; a cross-cutting pattern search cannot be answered from memory.
- **Hard rule**: No file edits. No speculation beyond what search results actually show. No summarizing files not opened. Stop after the first pass unless the user asks for more.
- **Handoff**: `task-multi-build` / `task-yugong` (modify what was found) or `task-single-plan` (plan changes based on findings).
- **Not for**: External research (use `task-librarian`).

#### `task-librarian`

- **Purpose**: External references, including docs, OSS repos, official APIs, best-practice research.
- **When to enter**: Unfamiliar library/framework, "what's the best practice for X?", "how does OSS repo Y do this?", research that requires web or external repositories.
- **Methodologies**: Primary-Source-Only Research
- **Hard rule**: No unlabeled speculation. No inventing API signatures not observed in real source.
- **Handoff**: `task-single-plan` (design integration) or `task-multi-build` (apply directly). Can run as a background agent while the parent works.
- **Not for**: In-repo search (use `task-explore`).

#### `task-multimodal-looker`

- **Purpose**: Describe or extract information from images, PDFs, screenshots, and diagrams the user shared.
- **When to enter**: User shared visual media; the parent agent needs a specific piece of information that lives inside it.
- **Hard rule**: Answer the specific question first. Mark low-confidence readings explicitly. Never fabricate text not visible in the media. If the current tool cannot open the shared media, say so plainly.
- **Handoff**: Whichever role uses the extracted info.
- **Not for**: Text-only inputs.

### 2.4 Review and Diagnosis

Roles that inspect work for defects, at three different points in time.

#### `task-checkpoint` (during execution)

- **Purpose**: Mid-execution checkpoint. Verify in-progress work still matches the approved plan and can be safely continued.
- **When to enter**: Every ~3 steps of a multi-step plan, before any major state transition (schema migration, deployment, `git push`), or when the executor reports drift.
- **Methodologies**: Mid-Execution Checkpoint
- **Hard rule**: Read-only. Runs during execution, not before or after. Verdict is `continue` / `adjust plan` / `halt`.
- **Handoff**: Executor (if `continue`), `task-single-plan` (if `adjust plan`), user (if `halt`).
- **Not for**: Pre-plan critique (use `task-challenge`) or post-implementation audit (use `task-judge`).

#### `task-judge` (after execution)

- **Purpose**: Read-only high-authority audit on two independent axes.
- **When to enter**: Architectural choice with multi-system trade-offs, after ≥2 failed fix attempts on the same bug, after completing a significant change before claiming done, security/performance judgment call.
- **Methodologies**: Adversarial Review, Fowler Smell Baseline
- **Two axes stay independent** (never merged or re-ranked; native subagent tools may run them in parallel):
  - **Standards**: does the code follow this repo's coding standards + the Fowler smell baseline?
  - **Spec**: does the code match what the originating issue / PRD asked for?
- **Hard rule**: No file edits. No vague "you could consider…" without a concrete recommendation. Never merge findings across axes; one axis can pass while the other fails.
- **Handoff**: `task-multi-build` / `task-yugong` (apply fixes) or user (architectural approval).
- **Not for**: In-progress work (use `task-checkpoint`).

#### `task-debug` (hard bug)

- **Purpose**: Diagnose hard bugs and performance regressions through a six-phase evidence-first loop.
- **When to enter**: Hard bug or perf regression that resisted a first fix, "sometimes fails" flakiness, chain of symptoms with no obvious cause, before a second fix attempt on a bug the executor cannot pin down.
- **Methodologies**: Six-Phase Evidence-First Loop, SHA1 Debug Session Prefix and Record File
- **Hard rule**: No jumping to hypotheses without a red-capable loop. No shotgun debugging. No debug logs without a SHA1-prefixed tag. No declaring done without re-running the original repro.
- **Handoff**: `task-multi-build` / `task-yugong` (apply fix) or `task-judge` (if root cause is architectural).
- **Not for**: Bugs that a straightforward first fix will resolve; `task-debug` is for the hard ones.

---

### 2.5 Workflows

Multi-step chains that compose `task-*` skills into end-to-end business workflows. Workflows own sequencing, approval gates, and state handoff; invoked tasks own production-code behavior.

#### `job-plan`

- **Purpose**: Route an ambiguous or multi-step request → `task-clarify` → `task-single-plan` → `task-challenge` → user approval → persist the approved plan artifacts (`plan.md` always; `design.md` / `guide.md` / `README.md` when the plan warrants) to `spec/<slug>/`.
- **When to enter**: Request is ambiguous, ≥ 2 steps, involves architectural choice, or user says "plan first" / "先做个计划".
- **Chain reference**: [`AGENTS.md`](AGENTS.md) section 5.2
- **Dispatch rule**: Never skip `task-clarify` for ambiguous requests. Never proceed past step 6 (user approval) without explicit OK. Never write to `spec/<slug>/` before approval. Never fabricate optional artifacts (design/guide/README) at write time if their section was not produced in step 3.
- **Handoff**: `job-build` (once persisted; executor reads `spec/<slug>/plan.md` from disk).
- **Not for**: Single-step tasks (route directly to `task-yugong` or the specific skill).

#### `job-build`

- **Purpose**: Execute an approved plan under TDD discipline with mid-execution checkpoints. Chains `task-yugong` (single-scope) or `task-multi-build` (multi-module) with `task-checkpoint` every ~3 steps.
- **When to enter**: A plan already exists (approved via `job-plan` or provided by user); user says "implement" / "execute" / "落实".
- **Chain reference**: [`AGENTS.md`](AGENTS.md) section 5.2
- **Dispatch rule**: Never continue past a `halt` checkpoint verdict without user reset. Never silently expand scope; stop and report if the task turns out larger. Never skip the checkpoint after a major state transition.
- **Handoff**: `job-review` (once all planned steps complete).
- **Not for**: Un-planned improvisation (go through `job-plan` first).

#### `job-verify`

- **Purpose**: Verify in-progress work against the approved plan through `task-checkpoint` (continue / adjust plan / halt).
- **When to enter**: Mid-execution "check progress", executor drift, or automatic dispatch by `job-build` every ~3 steps.
- **Chain reference**: [`AGENTS.md`](AGENTS.md) section 5.2
- **Dispatch rule**: Never run post-completion review here. Never edit files inside this workflow.
- **Handoff**: Executor (`task-yugong` / `task-multi-build`) if `continue`; `job-plan` if `adjust plan`; user if `halt`.
- **Not for**: Completed-work review (use `job-review`).

#### `job-debug`

- **Purpose**: First-pass bug diagnosis via `task-debug` (Phase 1-3 of the six-phase loop). Escalates to `job-debug-deep` for hard/flaky/chained bugs.
- **When to enter**: User reports a bug, test failure, or unexpected behavior; first attempt.
- **Chain reference**: [`AGENTS.md`](AGENTS.md) section 5.2
- **Dispatch rule**: Never skip Phase 1 (feedback loop); no hypothesis before red-capable repro. Never apply a fix without a regression test written first. Never continue past Phase 3 if the bug is hard; escalate. Never `sleep()`-cover a race.
- **Handoff**: `task-yugong` (apply straightforward fix); `job-debug-deep` (escalate on hard bug).
- **Not for**: Bugs already resisting a first fix (go direct to `job-debug-deep`).

#### `job-align`

- **Purpose**: Read-only code-doc alignment. `task-explore` enumerates doc touch-points → classify stale/missing/drift → user approves direction → persist the approved report → `task-yugong` / `task-multi-build` applies edits → `task-judge` re-scans.
- **When to enter**: "docs are out of date" / "align docs" / "文档和代码不一致" / large feature landed and doc drift accumulated.
- **Chain reference**: [`AGENTS.md`](AGENTS.md) section 5.2
- **Dispatch rule**: Never edit spec/PRD intent documents without explicit user OK. Never use bulk text diff to apply changes; item-by-item preserves semantics.
- **Handoff**: None (workflow terminates on clean re-scan).
- **Not for**: Writing new documentation from scratch (that's a normal implementation task).

#### `job-review`

- **Purpose**: Pre-completion review. Chains `task-challenge` (plan-vs-diff walkthrough) → `task-judge` (Standards axis + Spec axis) → `task-explore` (known-bug signatures and leftover sweep) → aggregate.
- **When to enter**: Before declaring any significant task done; before opening or merging a PR; before releasing a feature branch; after an executor session reports completion.
- **Chain reference**: [`AGENTS.md`](AGENTS.md) section 5.2
- **Dispatch rule**: Read-only. Standards and Spec axes kept separately attributed and never merged. No `SHIP` verdict if any `[blocker]` remains. Do not "quickly fix" findings inside this role.
- **Handoff**: `task-multi-build` or `task-yugong` to apply the `[blocker]` and `[should-fix]` items.
- **Not for**: In-progress checks (`task-checkpoint` runs during execution; this runs after).

#### `job-security-review`

- **Purpose**: End-to-end security audit. Chains `task-explore` (locate security-sensitive surfaces) → independent `task-judge` + `task-librarian` passes (parallel where supported) → optional `task-debug` escalation for unclear vulnerabilities → aggregate.
- **When to enter**: Before shipping code with security surface (auth, session, crypto, secret/token handling, input validation, deserialization); before opening a PR that touches security-sensitive code; on a periodic per-release cadence; when a security-relevant bug's exploit surface needs charting before the fix.
- **Chain reference**: [`AGENTS.md`](AGENTS.md) section 5.2
- **Dispatch rule**: Read-only. Sub-agent findings preserved by source and never merged or re-ranked. `[blocker]` requires a concrete named failure mode. Verdict is one line, `SHIP` / `FIX-THEN-SHIP` / `DO-NOT-SHIP`.
- **Handoff**: `task-multi-build` or `task-yugong` to apply the `[blocker]` and `[should-fix]` items.
- **Not for**: Non-security correctness review (use `job-review`).

#### `job-debug-deep`

- **Purpose**: Hard-bug diagnosis end-to-end. Drives `task-debug` through the six-phase evidence-first loop; dispatches `task-librarian` in Phase 3 when a hypothesis depends on external knowledge; escalates to `task-judge` in Phase 4 if the root cause is architectural; hands the Phase 5 fix off to `task-yugong` (single-scope) or `task-multi-build` (multi-module); verifies Phase 6 cleanup.
- **When to enter**: Hard bug or perf regression that resisted a first fix; "sometimes fails" flakiness; chain of symptoms with no obvious cause; before a second fix attempt on a bug the executor cannot pin down.
- **Chain reference**: [`AGENTS.md`](AGENTS.md) section 5.2
- **Dispatch rule**: No jumping to hypotheses without a red-capable feedback loop. No debug log without a SHA1-prefixed tag and matching `spec/debug/<sha1_short>.md` record. Regression test written at a correct seam **before** the fix. Never `sleep()`-cover a race; never skip Phase 6 cleanup.
- **Handoff**: `task-yugong` (single-scope fix) or `task-multi-build` (multi-module fix); optional final `task-judge` audit on the fix diff.
- **Not for**: A first-attempt fix on a straightforward bug (that goes to `job-debug` or `task-yugong` directly).

---

## Part 3: Scenarios

Three realistic development situations, walked end-to-end. Each shows which roles fire in what order and how the methodologies from Part 1 shape each step.

### Scenario A: Ambiguous Request, Medium-Sized Task

**Request** (from user, imprecise): "Add authentication to the app."

**Chain**: `task-clarify → task-single-plan → task-challenge → task-multi-build → task-checkpoint (checkpoint) → task-judge`

**Walkthrough:**

1. **`task-clarify`** critiques the request itself. First-Principles Decomposition asks what problem "authentication" solves for this app. Likely candidates are (a) prevent unauthorized access, (b) personalize the experience, (c) enable per-user billing. Enumerate assumptions ("SSO expected? password reset needed? SSO providers?"), ambiguities ("session or JWT? mobile clients?"), and AI failure modes ("will over-engineer with OAuth if a simple session cookie suffices"). Recommends the single most valuable clarifying question, "Do users pay per-account, or is this just about not letting strangers see private data?"
2. User answers: "Just prevent strangers from seeing private data. Email + password. No SSO."
3. **`task-single-plan`** produces a written plan. First-Principles Derivation asks the irreducible constraints, which are (a) email + password, (b) session-based (no mobile clients mentioned), (c) password reset via email, (d) the existing framework's session middleware. Tracer-Bullet Vertical Slicing sequences six atomic steps, each demoable end-to-end, including schema migration for `users`, sign-up endpoint, login endpoint, session middleware, sign-out endpoint, password reset flow. Each step names the file it touches and the expected observable result. Stops. Waits for approval.
4. **`task-challenge`** critiques the plan under Adversarial Review posture. Finds that step 3 doesn't specify hashing algorithm; step 4 doesn't say what happens on session expiry; there's no rate-limiting on step 3 (brute-force risk); the plan has no rollback story. Returns findings; the plan is revised.
5. User approves the revised plan.
6. **`task-multi-build`** executes. TDD Discipline means for each step, write the failing behavior test at a seam first, watch it fail for the right reason, implement, refactor. Dispatches `task-librarian` in the background to verify the exact bcrypt cost factor recommendation from the OWASP docs (Primary-Source-Only Research). Dispatches `task-explore` to find any existing middleware to reuse.
7. **`task-checkpoint`** fires after step 3 (about 1/3 through). Read-only checkpoint. Reads the diff since the last commit; confirms the executor added rate-limiting as `task-challenge` demanded. Verdict: `continue`.
8. After step 6, `task-multi-build` reports the feature is done and all tests pass.
9. **`task-judge`** runs the two-axis adversarial audit. Standards axis flags a Primitive Obsession (raw strings for passwords instead of a domain type); judgment call, not a hard violation. Spec axis confirms every ambiguity `task-challenge` raised has been resolved in the code. Verdict is approve with one `[should-fix]` on the Primitive Obsession. Handed to `task-multi-build` for a small follow-up.

**Methodologies exercised**: decomposition, derivation, vertical slicing, adversarial review (twice), TDD, primary-source, checkpoint, Fowler smells.

### Scenario B: Foggy Long-Horizon Project

**Request** (from a tech lead, big scope): "Migrate our web app from Framework A to Framework B."

**Chain**: `task-clarify → task-strategy (map) → tickets (research / prototype / grilling / task) → task-strategy (work map, one ticket per session) → task-single-plan (per task ticket) → task-multi-build → task-checkpoint → task-judge`

**Walkthrough:**

1. **`task-clarify`** decomposes the request.
   - **Root problem**: probably "Framework A is EOL / performance ceiling / hiring difficulty".
   - **Ambiguity**: "migrate" could mean full rewrite, incremental strangler, or new modules only.
   - **Recommends**: "Name the finish line. What does 'migrated' mean concretely? Feature parity on B, or new features go on B while old features stay on A?"
2. User answers: "Full parity. All new features must be on B. Old features migrate as we touch them, but we need a plan for the deliberately dormant ones."
3. **`task-strategy`** charts the wayfinder map. Fog-of-War Mapping names the destination ("all features run on B, feature parity, no A in production"). Then charts what can be stated precisely:
   - `[task] Set up B alongside A (dual-stack build).`
   - `[research] Does B support our SSO adapter? Verify against SSO vendor docs.`
   - `[research] Does B support our data-viz library? Verify against the lib's B-compatibility matrix.`
   - `[prototype] Port one representative screen. Measure LCP, bundle size, developer velocity.`
   - `[grilling] What do we do with the 12 dormant features that no one uses but no one has permission to delete?`
   - `[task] Cutover strategy: strangler at the routing layer vs. per-feature flag.`
   Everything else stays in `Not yet specified`.
4. Session 2: `task-strategy` picks the first ticket, `[research] SSO adapter`. Dispatches `task-librarian`. Librarian reads the SSO vendor's B-compatibility docs (Primary-Source-Only Research), cross-checks with the vendor's public SDK repo, finds one gotcha (session refresh differs between adapters). Ticket resolved with findings; one line appended to `Decisions so far`. Session ends.
5. Session 3 runs `[prototype] Port one representative screen`. Dispatches `task-quick-verify`. UI branch builds three ports of the same screen with different B routing patterns, measures LCP for each, drops the toggle bar in the demo for the team to click through. Winner is captured in a decision log. Ticket resolved.
6. Session 4: `[grilling] Dormant features`. Dispatches `task-clarify` to grill the user. User agrees to a formal deprecation vote for 8 of the 12 features.
7. As tickets resolve, fog turns into new precise tickets: `[task] Migrate the SSO layer per the librarian's finding`, `[task] Adopt the winning routing pattern from the prototype`, `[task] Deprecate the 8 approved features`.
8. Each task ticket, when picked up in a fresh session, goes through **`task-single-plan`** (single-session plan) → **`task-challenge`** (review) → **`task-multi-build`** (execute) → **`task-checkpoint`** (checkpoint) → **`task-judge`** (audit).
9. After each session, `task-strategy` updates the map with the ticket's resolution and graduates any newly-precise fog to fresh tickets.

**Methodologies exercised**: decomposition, fog-of-war mapping, primary-source, dual-branch prototyping, and the full Scenario A chain per task ticket.

**Key discipline**: Never resolve more than one non-research ticket per session. The temptation to "just also do this small one" defeats the whole map's evolution.

### Scenario C: Hard Bug with Failed First Fix

**Request** (from a developer, frustrated): "The checkout test occasionally fails on CI. I fixed it once by adding a `sleep(1)`, but it still fails intermittently."

**Chain**: `task-yugong (attempted first fix, failed) → task-debug (six-phase diagnosis) → task-multi-build (real fix, TDD) → task-judge (audit if architectural)`

**Walkthrough:**

1. **`task-yugong`** was the default when the user first asked "fix this test". It attempted `sleep(1)`. Fix superficially worked, then flakiness returned. `task-yugong` correctly stops and reports rather than adding more `sleep(2)`; it does not silently expand scope by patching over symptoms.
2. User says "still flaky". This is the trigger for `task-debug`.
3. **`task-debug` Phase 1**: Build a feedback loop. Runs the test in a loop with `--repeat 200` locally. Observes 4 failures out of 200. Loop is red-capable, deterministic-enough (4/200 reproducibly), fast (30 seconds), agent-runnable. Records the feedback loop command.
4. **`task-debug` Phase 2**: Reproduce + minimise. Confirms the failure is the user's exact symptom (specific assertion at line 87), not a nearby different one. Strips the test to the minimum body that still fails 3/200. Every remaining element is load-bearing.
5. **`task-debug` Phase 3** (hypothesise). Generates 4 ranked, falsifiable hypotheses.
   - (a) Database transaction isolation causes read-your-writes to fail under concurrent test runs. If serializing the test suite makes flakiness disappear, hypothesis confirmed.
   - (b) The `Date.now()` in the assertion crosses a second boundary. If freezing time makes flakiness disappear, hypothesis confirmed.
   - (c) The checkout service caches something in a module-level variable. Falsifiable by clearing the module cache between test runs.
   - (d) A shared test fixture is mutated by an unrelated test. Falsifiable by running this test in isolation.
   Shows the ranked list to the user. User re-ranks based on domain knowledge: "we recently added a Redis cache to the checkout service" → (c) jumps to #1.
6. **`task-debug` Phase 4** (instrument). Specifies SHA1 session `a3f9c2e1`, redacted `spec/debug/a3f9c2e1.md` content, and one targeted log line `console.log("[DEBUG-a3f9c2e1] checkout cache state:", cache)`. A writable executor applies the plan and returns the cache evidence. The evidence confirms hypothesis (c), the module-level cache from a previous test survives into the next test in the same process.
7. **`task-multi-build` Phase 5** (fix + regression test). Writes a regression test at the correct seam (test-suite-level `afterEach` that asserts the cache is empty). Watches it fail for the right reason, then fixes the checkout service to expose a `resetCache()` method (or, better, uses dependency injection so the cache is per-instance). Test suite goes green.
8. **`task-debug` Phase 6** (verify cleanup + post-mortem). Re-reads executor evidence. `grep -rn "[DEBUG-a3f9c2e1]"` returns no matches, the debug record is curated or deleted, and the original `--repeat 500` loop reports 0 failures. It supplies the correct hypothesis for a future commit or PR message, "Fix flaky checkout test caused by module-level Redis cache surviving across test runs."
9. If in Phase 4 the root cause had turned out to be an architectural mistake (e.g. shared mutable state is used pervasively across the codebase), `task-debug` would have handed off to **`task-judge`** for an architectural verdict before the fix; the fix would then be scoped by the audit.

**Methodologies exercised**: loop engineering (correctly stopping instead of piling `sleep`s), six-phase loop, SHA1 tag, TDD (applied to the regression test), adversarial audit (if escalated).

**Key discipline**: `sleep()` in a flaky test is a red flag that the underlying race was never diagnosed. The role that fires next is `task-debug`, not another `sleep(2)`.

---

## Closing

**How to start using the roles:**

- Read `AGENTS.md` section 3.0 for semantic routing and section 4 for role cards. Type `@task-<role>` or `@job-<workflow>` when you want to name a role explicitly, or describe the task and let the router choose.
- When in doubt about which role, look for the closest scenario in Part 3 and follow its chain.
- When a methodology feels unfamiliar in practice, re-read its section in Part 1 and try it on a small real task.

**Where to go next:**

- `README.md`: installation and per-tool setup.
- `AGENTS.md`: the live operating rules that AI reads on session start. Section 3.0 is the default state and semantic routing table; sections 3.1-3.10 are the always-on discipline; section 5 is orchestration patterns.
- `skills/task-<role>.md` and `skills/job-<workflow>.md`: the full behavior contract, output template, and hard constraints for each role or workflow.
