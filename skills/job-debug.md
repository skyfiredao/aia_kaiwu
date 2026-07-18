---
name: job-debug
description: Workflow for bug diagnosis. Runs first-pass diagnosis via task-debug; escalates to job-debug-deep if the bug resists a straightforward fix.
readonly: false
is_background: false
agents: [task-debug, task-yugong]
handoffs:
  - agent: task-yugong
    label: "Apply the fix (task-yugong)"
    prompt: "Apply the fix identified in Phase 5 of the diagnosis above. Write the regression test at the identified seam before the fix."
  - agent: job-debug-deep
    label: "Escalate to hard-bug workflow (job-debug-deep)"
    prompt: "The first-pass fix did not resolve the bug or the bug shows chained symptoms / flaky behavior. Escalate to job-debug-deep for full six-phase diagnosis."
---

# job-debug

## Purpose

Diagnose and fix a bug. First-pass diagnosis with `task-debug`; escalate to `job-debug-deep` when the bug is hard.

## When to enter

- User reports a bug
- Test failure
- Unexpected runtime behavior
- User says "有 bug" / "X 不 work" / "为什么没生效"

Do **not** enter for:
- Already-diagnosed bugs where the fix is known (go direct to `task-yugong`)
- Flaky "sometimes fails" bugs (go direct to `job-debug-deep`)
- Bugs already resisted a first fix (go direct to `job-debug-deep`)

## Steps

1. **`task-debug`**: Phase 1, build a red-capable feedback loop (deterministic, fast, agent-runnable).
2. **`task-debug`**: Phase 2, reproduce and minimise. Confirm it is the user's exact symptom.
3. **`task-debug`**: Phase 3, rank 3–5 falsifiable hypotheses. Show the ranked list to the user.
4. **Assess complexity, escalation checklist.** After Phase 3 hypotheses are ranked, escalate to `job-debug-deep` if **any** of the following holds:
   - `[flaky]`: bug reproduces intermittently (any "sometimes fails" or "3/100 runs" signal)
   - `[chained]`: the failing symptom is triggered by another failure chained through 2+ modules
   - `[multi-module]`: the fix path spans 3+ source files or crosses subsystem boundaries
   - `[hypotheses > 2]`: after Phase 3, 3+ falsifiable hypotheses remain plausible with roughly equal likelihood
   - `[architectural]`: top-ranked hypothesis identifies a design flaw (shared mutable state, wrong layering, race condition needing a lock strategy)
   - `[repeated failure]`: the user reports this bug already resisted a prior fix attempt
   
   Otherwise (single dominant hypothesis, single-file fix, first attempt) → proceed to step 5.
5. **`task-debug`**: Phase 4-5 lite, minimal instrumentation, write regression test at correct seam **before** the fix.
6. **`task-yugong`**: Apply the fix. Verify the Phase 1 loop is now green.
7. Cleanup: remove any debug scaffolding; commit with the correct hypothesis in the message.

## Dispatch rules

- Never skip Phase 1 (feedback loop); no hypothesis before red-capable repro.
- Never apply a fix without a regression test written first.
- Never continue past Phase 3 if the bug is hard; escalate.
- Never `sleep()`-cover a race.

## Output shape

```
## Bug
<symptom>

## Feedback loop
<command + first-run showing red>

## Ranked hypotheses
1. ...
2. ...

## Assessment
<straightforward → proceed to fix | hard → escalate to job-debug-deep>

## Fix
<seam / regression test path / fix path:line>

## Verify
<Phase 1 loop rerun result>
```

## Handoff

- `task-yugong` (apply the fix if straightforward)
- `job-debug-deep` (escalate if hard)
