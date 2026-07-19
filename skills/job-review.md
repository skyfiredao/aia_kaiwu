---
name: job-review
description: Workflow for pre-completion / pre-ship review. Walks the plan against the actual diff, runs Standards + Spec audit, scans for known-bug signatures and leftover debug/TODO. Read-only; fixes are handed off.
readonly: true
is_background: false
agents: [task-challenge, task-judge, task-explore]
handoffs:
  - agent: task-multi-build
    label: "Apply the fixes (task-multi-build)"
    prompt: "Read the persisted pre-completion review report path provided by the parent. Apply its [blocker] and [should-fix] items. Skip [nit] items unless the user asks."
  - agent: task-yugong
    label: "Apply the fixes (task-yugong)"
    prompt: "Read the persisted pre-completion review report path provided by the parent. Apply its [blocker] and [should-fix] items as one scoped task. Skip [nit] items unless the user asks."
---

# job-review

## Purpose

Comprehensive pre-completion review that walks plan-vs-diff, runs a two-axis audit, and sweeps for known-bug signatures and leftover debug/TODO.

## When to enter

- Before declaring any significant task done
- Before opening or merging a PR
- Before releasing a feature branch
- After an executor session reports completion

Distinct from `task-checkpoint`: this runs **after** execution; checkpoint runs **during**.

Optional argument `[scope]` accepts `diff-since:<git-ref>` (default is current branch vs main) or `<path>`.

## Steps

1. **`task-challenge`**: Plan-vs-reality check. If a written plan or spec exists (chat history, `spec/`, PR description, issue), walk through it step by step against the actual diff. Flag drifted, merged, and missing steps. If no plan exists, note it and skip.
2. **`task-judge`** on the diff:
   - Standards axis: code follows repo's coding standards + Fowler smell baseline.
   - Spec axis: code matches what the originating issue/PRD/plan asked for.
3. **`task-explore`** scans the diff for unresolved flakiness signatures, unreverted debug scaffolding, silent catch blocks, `sleep()` covering races, disabled tests, `TODO`, `FIXME`, `XXX`, `HACK`, unattributed `console.log`, `[DEBUG-` remnants, commented-out code, and dead imports.
4. **Aggregate** into severity buckets: `[blocker]` / `[should-fix]` / `[nit]`. Preserve source attribution.
5. If fixes are required, ask the parent or a writable workflow to persist the report under `spec/review/<sha_short>.md`, then include that path in the executor handoff.

## Dispatch rules

- Output MUST end with the line `[read-only: no files edited]` as a self-declaration confirming no file writes occurred during the review.
- No file edits.
- Never skip step 1 if a plan exists.
- Never merge Standards and Spec axis findings (kept separately attributed).
- Never issue `SHIP` if any `[blocker]` remains.
- Do not "quickly fix" findings inside this role; fixing is a separate step under the executor.

## Output shape

```
## Scope
<diff range or path>

## Plan-drift (from task-challenge)
<per-step: matched / drifted / merged / missing; or "no plan available">

## Standards axis (from task-judge)
<findings with path:line>

## Spec axis (from task-judge)
<findings with path:line>

## Known-bug and leftover sweep (from task-explore)
<flakiness signatures / TODO / FIXME / debug remnants with path:line>

## Aggregated verdict

### [blocker]
- <path:line>, <finding>

### [should-fix]
- <path:line>, <finding>

### [nit]
- <path:line>, <finding>

## Ship verdict
<SHIP | FIX-THEN-SHIP | DO-NOT-SHIP + reasoning>

[read-only: no files edited]
```

## Handoff

`task-multi-build` or `task-yugong` to apply the `[blocker]` and `[should-fix]` items.
