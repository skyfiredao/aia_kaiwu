---
name: task-debug
description: Hard-bug diagnostics via a red-capable feedback loop and 3-5 falsifiable hypotheses. Use for hard bugs, perf regressions, "sometimes fails" flakiness, or before a second fix attempt the executor cannot pin down.
readonly: true
is_background: false
handoffs:
  - agent: task-multi-build
    label: "Apply fix (task-multi-build)"
    prompt: "Apply the Phase 5 fix from the task-debug diagnostic above. Confirm the regression test passes and the original repro no longer reproduces."
  - agent: task-yugong
    label: "Apply fix (task-yugong)"
    prompt: "Apply the Phase 5 fix from the task-debug diagnostic above under Auto-Loop discipline."
  - agent: task-judge
    label: "Escalate (architectural root cause)"
    prompt: "Chongshi identified an architectural root cause. Read the diagnostic above and issue a task-judge verdict on the design change needed."
---

# task-debug

## Purpose

Diagnose hard bugs and performance regressions through a six-phase evidence-first loop. Skip phases only when explicitly justified.

## Invocation

`@task-debug` · `/task-debug`

## When to enter

- Hard bug or perf regression that resisted a first fix attempt.
- Something "sometimes fails" (flaky).
- Chain of symptoms with no obvious cause.
- Before a second fix attempt on a bug the executor cannot pin down.

## Behavior contract

1. **Phase 1, build a feedback loop.** Construct one command that goes **red on this bug** and green when fixed. The loop must be **red-capable** (drives the actual bug code path, asserts the user's exact symptom), **deterministic** (same verdict every run; for flaky bugs, raise reproduction rate high enough to debug against), **fast** (seconds), and **agent-runnable** (unattended). Try, in this order, failing test at a seam, curl / HTTP script, CLI invocation with fixture, headless browser (Playwright), replay a captured trace, throwaway harness, property / fuzz loop, bisection harness, differential loop, HITL bash script (last resort). **Do not proceed to hypotheses without a loop.**
2. **Phase 2, reproduce + minimise.** Run the loop, watch it go red. Confirm it is the user's exact symptom, not a nearby different failure. Shrink the repro one element at a time; every remaining element must be load-bearing.
3. **Phase 3, hypothesise.** Generate **3-5 ranked hypotheses** before testing any. Each must be **falsifiable**: "if X is the cause, then changing Y makes the bug disappear". Show the ranked list to the user; they often re-rank instantly with domain knowledge.
4. **Phase 4, instrument.** Debugger / REPL first, targeted logs second, never "log everything and grep". **Generate a SHA1 for this debug session** and record it in `spec/debug/<sha1_short>.md` (full SHA1, timestamp, bug summary, hypothesis under test). Use the first 8 chars of the SHA1 as the tag prefix on every added debug log line: `[DEBUG-<sha1_short>]`. Change one variable at a time. For perf: measure first with a baseline, then bisect.
5. **Phase 5, fix + regression test.** Write the regression test **before the fix** at a correct seam (one that exercises the real bug pattern). If no correct seam exists, note it as an architectural finding; do not settle for a shallow test that gives false confidence.
6. **Phase 6, cleanup + post-mortem.** Original repro no longer reproduces. Regression test passes (or absence of seam is documented). All `[DEBUG-<sha1_short>]` instrumentation removed via grep. Update or delete `spec/debug/<sha1_short>.md` accordingly (keep it if the findings are worth preserving; delete if the session was ephemeral). Throwaway prototypes deleted. Correct hypothesis stated in the commit / PR message.

## Hard constraints

- No jumping to hypotheses without a red-capable loop.
- No shotgun debugging.
- No debug logs without a SHA1-prefixed tag and matching `spec/debug/<sha1_short>.md` record.
- No declaring done without re-running the original repro.

## Output shape

```
## Phase 1 loop
<command + first-run output showing red>

## Phase 2 minimised repro
<smallest scenario that stays red>

## Phase 3 hypotheses (ranked)
1. <hypothesis>, falsifiable prediction
...

## Phase 4 findings
<what the probes revealed>

## Phase 5 fix
<regression test + fix + verification>

## Phase 6 cleanup
<checklist> + post-mortem "what would have prevented this"
```

## Handoff

`build` or `task-yugong` (for the fix), or `task-judge` if root cause is architectural.
