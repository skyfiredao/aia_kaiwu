---
name: job-debug-deep
description: Workflow for hard-bug diagnosis end-to-end. Drives task-debug through the six-phase evidence-first loop, dispatches task-librarian for external knowledge, escalates to task-judge for architectural verdicts, hands off the fix, and verifies cleanup.
readonly: false
is_background: false
agents: [task-debug, task-librarian, task-judge, task-yugong, task-multi-build]
handoffs:
  - agent: task-yugong
    label: "Apply the fix (task-yugong)"
    prompt: "Read the `spec/debug/<sha1_short>.md` path supplied by the parent. Apply its Phase 5 fix as one scoped task and write the regression test at the identified seam before the fix. Grind until verified."
  - agent: task-multi-build
    label: "Apply the fix (task-multi-build)"
    prompt: "Read the `spec/debug/<sha1_short>.md` path supplied by the parent. Apply its Phase 5 fix. If the fix spans multiple modules, dispatch specialists per the task-multi-build contract. Write the regression test at the identified seam before the fix."
  - agent: task-judge
    label: "Post-fix audit (task-judge)"
    prompt: "Two-axis audit on the fix diff. Confirm the fix addresses the correct hypothesis and does not introduce Standards-axis regressions."
---

# job-debug-deep

## Purpose

Drive `task-debug` end-to-end through the six-phase evidence-first loop, escalate as needed, hand off the fix, and verify cleanup.

## When to enter

- Hard bug or performance regression that resisted a first fix
- "Sometimes fails" flakiness
- Chain of symptoms with no obvious cause
- Before a second fix attempt on a bug the executor cannot pin down

Straightforward first fixes go to `task-debug` (dispatched by `job-debug`) directly; this workflow is for the hard ones.

Optional argument `<bug-description>` is a short description of the symptom (e.g., "checkout test fails 3/100 on CI").

## Steps

1. **`task-debug`**: Phase 1, build a red-capable feedback loop (deterministic, fast, agent-runnable). Do not proceed without a loop.
2. **`task-debug`**: Phase 2, reproduce + minimise. Confirm the loop reproduces the user's exact symptom; shrink to smallest scenario that still fails.
3. **`task-debug`**: Phase 3, 3–5 ranked falsifiable hypotheses. Show the ranked list to the user.
   - **Optional parallel skill: `task-librarian`** if any hypothesis depends on external knowledge (library internals, protocol spec, framework quirk); primary sources only, cited.
4. **`task-debug`**: Phase 4, produce the instrumentation plan. Debugger/REPL first, targeted logs second. Name the SHA1 session, redacted `spec/debug/<sha1_short>.md` content, tagged log lines, and the one variable to change.
   - **Optional escalation skill: `task-judge`** if instrumentation reveals the root cause is architectural (shared mutable state used pervasively, wrong layering, spec ambiguity); the fix scope is then set by the audit before any code change.
5. **Handoff for Phase 5** (instrumentation + fix + regression test). The executor first persists the full diagnostic and instrumentation plan to `spec/debug/<sha1_short>.md`, writes only redacted values, and writes the regression test at a correct seam **before** the fix. The handoff prompt includes the artifact path. Hand off:
   - Single-scope fix → `task-yugong`
   - Multi-module fix → `task-multi-build`
6. Invoke **`task-debug`** for Phase 6, cleanup + post-mortem. Verify all of:
   - Original repro no longer reproduces (Phase 1 loop rerun result)
   - Regression test passes
   - All `[DEBUG-<sha1_short>]` instrumentation removed via grep
   - `spec/debug/<sha1_short>.md` updated or deleted
   - Correct hypothesis supplied for a future commit/PR message
   - Optional final `task-judge` audit on the fix diff if the change is significant.

## Dispatch rules

- Never jump to hypotheses without a red-capable feedback loop.
- Never proceed past Phase 3 without showing the ranked hypotheses to the user.
- Never let Phase 5 handoff apply a fix without a regression test written first.
- Never `sleep()`-cover a race; that re-opens the bug later.
- Never skip Phase 6 cleanup.

## Output shape

```
## Bug
<user's stated symptom>

## Phase 1, feedback loop
<command + first-run output showing red>

## Phase 2, minimised repro
<smallest scenario that stays red>

## Phase 3, ranked hypotheses
1. <hypothesis>, falsifiable prediction: <if X then Y disappears>
2. ...

## Phase 4, findings
<what the probes revealed; SHA1 session ref: spec/debug/<sha1_short>.md>

## Phase 5, fix + regression test
<seam name / regression test path / fix path:line>

## Phase 6, cleanup
[ok] Original repro no longer reproduces
[ok] Regression test passes
[ok] All [DEBUG-<sha1_short>] removed
[ok] spec/debug/<sha1_short>.md updated or deleted
[ok] Correct hypothesis for commit/PR message: <one line>
```

## Handoff

Phase 5, `task-yugong` (single-scope) or `task-multi-build` (multi-module). Optional Phase 6, `task-judge` for post-fix audit.
