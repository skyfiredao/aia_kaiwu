---
name: job-scamper
description: Build a comprehensive solution through systematic multi-angle (SCAMPER) analysis, round by round until no new angle remains. Domain-general, aimed at a comprehensive solution, not fault-finding. Triggers - "scamper", "multi-angle analysis", "build a comprehensive solution from all angles", "全角度分析".
is_background: false
agents: [task-why-how-what]
---

# job-scamper

## Files

```
spec/scamper/<prefix>/
  problem.md                     # the original problem, constant
  round-<n>.solution.md          # the current best solution after round n
  round-<n>.<angle>.result.md    # one vantage's result within round n
```

Vantages are kept in separate files. The orchestrator reads solutions and results; each dispatched task reads only its assigned vantage.

## Steps

1. **Set up.** Derive `<prefix>` from the problem. Create `spec/scamper/<prefix>/`. Write `problem.md`.
2. **Round 0 — initial solution.** Dispatch one `task-why-how-what` on the raw problem. Save its result as `round-0.solution.md`. This is the current solution.
3. **Loop** (round n = 1, 2, …):
   1. **SCAMPER-decompose the current solution** across the seven angles:
      - **S** Substitute — swap an element for another
      - **C** Combine — merge elements, or with something external
      - **A** Adapt — borrow an approach from another context
      - **M** Modify / Magnify — change an attribute, scale up or down
      - **P** Put to another use — serve a different purpose or audience
      - **E** Eliminate — remove an element
      - **R** Reverse / Rearrange — invert or reorder

      For each angle, **analyze** whether it yields a meaningful starting point against the current solution, then apply two filters:
      - **reasonableness** — if the angle does not hold, is incoherent, or is meaningless for this solution, discard it;
      - **novelty** — if it is materially the same as an angle already analyzed in a prior round, treat it as a repeat and skip.

      Keep only angles that are **new AND reasonable**.
   2. If **no angle survives both filters → converge.** Output the current solution as the final comprehensive solution. Stop.
   3. Otherwise, for each kept angle, dispatch one `task-why-how-what` as an isolated vantage (starting point = that SCAMPER transform against the current solution). Save each as `round-<n>.<angle>.result.md`.
   4. **Re-evaluate the optimum.** Read the current solution plus all this round's vantage results, and synthesize the new best solution by:
      - **Pareto focus** — keep the vital few vantages that carry most of the value; do not dilute with marginal ones;
      - **logical self-consistency** — the synthesized solution must hold together without internal contradiction.

      Write it as `round-<n>.solution.md`; it becomes the current solution.
   5. Next round.

## Dispatch rules

- Never dispatch a task for an angle that does not hold just to fill the seven.
- Termination is "a round produces no new reasonable angle." No fixed round cap.
- A vantage that merely confirms part of the current solution is still useful coverage.

## Output shape

```
## SCAMPER build
- Prefix: <prefix>
- Rounds: N

## Evolution
- Round 0 initial: <gist>
- Round 1: kept [S, E, R]; discarded [C incoherent, A no-new] → revised: <gist>
- ...
- Round N: no new reasonable angle → converged

## Final comprehensive solution
<the converged solution>
```

## Next

Terminal — return the comprehensive solution and its round-by-round evolution to the caller.
