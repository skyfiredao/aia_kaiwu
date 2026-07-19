---
name: job-verify
description: Workflow for verifying in-progress work against the approved plan. Read-only; verdict is continue / adjust plan / halt.
readonly: true
is_background: false
agents: [task-checkpoint]
handoffs:
  - agent: task-multi-build
    label: "Continue (task-multi-build)"
    prompt: "Verify verdict is 'continue'. Resume the approved plan from the current step."
  - agent: task-yugong
    label: "Continue (task-yugong)"
    prompt: "Verify verdict is 'continue'. Resume the current scoped task."
  - agent: job-plan
    label: "Revise plan (job-plan)"
    prompt: "Verify verdict is 'adjust plan'. Revise the plan per the finding above."
---

# job-verify

## Purpose

Verify in-progress work still matches the approved plan and can safely continue.

## When to enter

- Every ~3 steps of `job-build`, or before major state transitions
- User says "check progress" / "跑到哪了" / "on track?"
- Executor reports drift or unexpected findings

Completed work goes to `job-review` for Standards + Spec review and the leftover sweep.

## Steps

1. Read the approved plan and current execution state.
2. Invoke **`task-checkpoint`** to verify completed steps and deviations.
3. Return one verdict, `continue` / `adjust plan` / `halt`.

## Dispatch rules

- Output MUST end with the line `[read-only: no files edited]` as a self-declaration confirming no file writes occurred during verification.
- Never run a post-completion ship review here; use `job-review`.
- Never edit files inside this workflow.

## Output shape

```
## Mid-execution findings (from task-checkpoint)
<step-by-step verification; deviations flagged>

## Verdict
<continue | adjust plan | halt>

[read-only: no files edited]
```

## Handoff

- Executor (`task-yugong` / `task-multi-build`) if `continue`
- `job-plan` if `adjust plan`
- User if `halt`
