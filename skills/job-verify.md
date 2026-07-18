---
name: job-verify
description: Workflow for verifying work; either mid-execution checkpoint or post-completion spec-vs-code check. Read-only; findings that need fixing are handed off.
readonly: true
is_background: false
agents: [task-checkpoint, task-judge]
handoffs:
  - agent: task-multi-build
    label: "Apply the fixes (task-multi-build)"
    prompt: "Apply the [blocker] and [should-fix] items from the verify report above."
  - agent: task-yugong
    label: "Apply the fixes (task-yugong)"
    prompt: "Apply the [blocker] and [should-fix] items from the verify report above as one scoped task."
  - agent: job-plan
    label: "Revise plan (job-plan)"
    prompt: "Verify verdict is 'adjust plan'. Revise the plan per the finding above."
---

# job-verify

## Purpose

Verify work matches the plan and the spec. Routes to mid-execution checkpoint or post-execution spec check based on state.

## When to enter

- Mid-execution: every ~3 steps of `job-build`, or before major state transitions (dispatched by `job-build`)
- Mid-execution manual: user says "check progress" / "跑到哪了" / "on track?"
- Post-execution: user says "verify" / "audit" / "did we do it right" / "check this matches the spec"

`job-verify` is narrower than `job-review`:
- `job-verify`: did we do what we planned / does it match the spec (single-axis)
- `job-review`: is it ready to ship (Standards + Spec + leftover sweep, comprehensive)

## Steps

1. Determine mode:
   - **Mid-execution** (executor is still running or between steps) → step 2
   - **Post-execution** (task marked done) → step 3
2. **`task-checkpoint`** (mid): Verify in-progress work still matches the approved plan and can be safely continued. Verdict: `continue` / `adjust plan` / `halt`.
3. **`task-judge`** (post) runs a two-axis audit on the diff:
   - Standards axis: code follows repo standards + Fowler smell baseline
   - Spec axis: code matches what the plan / issue / PRD asked for
   - Kept separately attributed; never merged.
4. Aggregate findings into severity buckets: `[blocker]` / `[should-fix]` / `[nit]`.

## Dispatch rules

- Output MUST end with the line `[read-only: no files edited]` as a self-declaration confirming no file writes occurred during verification.
- Never confuse mid-execution and post-execution modes; they call different skills.
- Never merge the two `task-judge` axes.
- Never issue `SHIP` if any `[blocker]` remains.
- Never edit files inside this workflow.

## Output shape

```
## Mode
<mid-execution | post-execution>

## Mid-execution findings (from task-checkpoint)
<step-by-step verification; deviations flagged>
Verdict: <continue | adjust plan | halt>

## Post-execution findings (from task-judge)
### Standards axis
- <path:line>, <finding>
### Spec axis
- <path:line>, <finding>

## Severity
### [blocker]
- ...
### [should-fix]
- ...
### [nit]
- ...

## Verdict
<continue | adjust plan | halt | SHIP | FIX-THEN-SHIP | DO-NOT-SHIP>

[read-only: no files edited]
```

## Handoff

- Executor (`task-yugong` / `task-multi-build`) if `continue` or apply fixes for `[blocker]` / `[should-fix]`
- `job-plan` if `adjust plan`
- User if `halt`
