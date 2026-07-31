---
name: job-build
description: Workflow for executing an approved plan under TDD discipline with mid-execution checkpoints and a pre-completion review. Routes to task-yugong (single-scope) or task-multi-build (multi-module).
is_background: false
agents: [task-yugong, task-multi-build, task-checkpoint]
handoffs:
  - agent: job-review
    label: "Pre-completion review (job-review)"
    prompt: "Task execution finished. Run job-review to walk the plan against the diff, do a two-axis audit, and sweep for known-bug / TODO leftovers before declaring done."
---

# job-build

## When to enter

- Plan already persisted at `spec/<slug>/plan.md` (produced by `job-plan`) or provided inline by the user
- User says "implement" / "build" / "execute" / "落实" / "按计划做" / "开始实现"

## Steps

1. Read the approved plan. If invoked from `job-plan`, read `spec/<slug>/plan.md` from disk (and consult `spec/<slug>/design.md` / `guide.md` when present). If the plan was provided inline, use that. Confirm scope with the user if unclear.
2. **gate: user approves execution start.** Restate the plan scope and executor choice in one paragraph, then wait for explicit user OK ("start" / "go" / "execute" / "开始" / "开工"). Do not dispatch any executor or write any file before this OK.
3. Choose executor:
   - Single-scope task (one module, one clear goal) → **`task-yugong`**
   - Multi-module task (spans several modules, benefits from specialist delegation) → **`task-multi-build`**
4. TDD rhythm inside the executor: red → green → refactor, one behavior at a time, tests at seams.
5. Every ~3 steps of execution, or before any major state transition (schema migration, deploy, `git push`): **`task-checkpoint`**.
6. On checkpoint verdict:
   - `continue` → executor resumes
   - `adjust plan` → return to `job-plan` step 3 (revise plan)
   - `halt` → stop and report to user; do not proceed
7. On executor completion → handoff to `job-review` for the pre-completion audit.

## Dispatch rules

- Never continue past a `halt` verdict without explicit user reset.
- Never silently expand scope; if the task turns out larger than planned, stop and report.
- Never skip the checkpoint after a major state transition.
- Never apply "quick fixes" outside the plan; deviations require plan revision.
- Never dispatch an executor or write any file before the step 2 start gate is passed.

## Output shape

```
## Execution progress
- Step 1: <status: done / in-progress / skipped>, <observed result>
- Step 2: ...

## Checkpoints
- After step 3: continue
- After step 6: <verdict>

## Ready for review
<yes if all steps done, no if any halt/adjust>
```

## Handoff

`job-review` (once all planned steps complete).
