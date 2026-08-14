---
name: job-debug
description: Bug diagnosis, first pass. Use for a reported bug with a clear reproduction; escalates to job-debug-deep if it resists a straightforward fix.
is_background: false
agents: [task-debug, task-yugong]
handoffs:
  - agent: task-yugong
    label: "Apply the fix (task-yugong)"
    prompt: "Read the diagnostic artifact path supplied by the parent. Apply its Phase 5 fix and write the regression test at the identified seam before the fix."
  - agent: job-debug-deep
    label: "Escalate to hard-bug workflow (job-debug-deep)"
    prompt: "The first-pass fix did not resolve the bug or the bug shows chained symptoms / flaky behavior. Escalate to job-debug-deep for full six-phase diagnosis."
---

# job-debug

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
5. **`task-debug`**: Phase 4-5 lite, specify minimal instrumentation, the regression test seam, and the minimal fix.
6. **`task-yugong`**: Apply the instrumentation plan if needed, create the redacted debug record, write the regression test before the fix, apply the fix, remove debug scaffolding, and verify the Phase 1 loop is green.
7. **`task-debug`**: Run Phase 6 as a read-only verification pass. Confirm the repro stays green, the regression test passes, debug scaffolding is gone, and the correct hypothesis is ready for a future commit or PR message. Commit only if the current user message asks.

## Dispatch rules

- Never skip Phase 1 (feedback loop); no hypothesis before red-capable repro.
- Never apply a fix without a regression test written first.
- Never continue past Phase 3 if the bug is hard; escalate.
- Never `sleep()`-cover a race.
- Three-strike rule: 3rd fix of same root cause (grep git log) → structural change or escalate to `job-debug-deep`.

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

## Next

- `task-yugong` (apply the fix if straightforward)
- `job-debug-deep` (escalate if hard)
