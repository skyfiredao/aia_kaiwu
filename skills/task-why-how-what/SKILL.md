---
name: task-why-how-what
description: Reason one starting point (a raw problem, or a SCAMPER angle) through the Golden Circle (Why to How to What) grounded in first principles, producing one result from that single vantage. Dispatched by job-scamper, or standalone. Triggers - "why how what", "golden circle analysis", "first-principles pass on this".
is_background: false
agents: []
---

# task-why-how-what

One grounded pass from a single vantage. Given one starting point, reason it through the Golden Circle anchored in first principles, and produce one result. It never ranks or picks among results — that judgment belongs to the caller (`job-scamper`).

## When to enter

- Dispatched by `job-scamper` as round 0 (starting point = the raw problem) or as one angle of a later round (starting point = a SCAMPER-transformed angle on the current solution).
- Or invoked directly for a single first-principles / Golden-Circle pass on a problem.

## Inputs (file-based)

Read only the starting point the caller points you to — either the raw problem, or one SCAMPER angle stated against the current solution. You produce one result from this one vantage; you do not read or weigh other vantages' results.

## Behavior contract

1. **Fix the vantage.** State the single starting point you reason from (the raw problem, or the specific SCAMPER transform, e.g. "Eliminate component X", "Reverse the order of A and B").
2. **Golden Circle, in order:**
   - **Why** — the root purpose / real need this must serve from the vantage. Not the surface ask; the underlying goal.
   - **How** — the mechanism / approach that serves that Why from this vantage.
   - **What** — the concrete form it takes (the actual solution, artifact, or steps).
3. **Ground in first principles.** Reduce to the irreducible constraints (data shape, domain rule, hard limit, real requirement) and reason up from them. Do not justify by analogy ("we usually…", "X did it this way").
4. **Produce one result**: the solution as seen from this vantage, plus what this vantage surfaces that a different vantage would miss.
5. **Do not judge** whether this result is best. Hand it back; the caller aggregates.

## Hard constraints

- One vantage per invocation. Do not blend multiple SCAMPER angles into one pass.
- Reason Why → How → What in that order; never start from What and back-fill a Why.
- First principles, not analogy. Any step that exists only because "that's how it's usually done" is a candidate to drop.
- No cross-result ranking or "optimal" verdict — that is the caller's job.
- Write the result to the file path the caller assigns; keep vantages file-separated.

## Output

```
## Vantage
<the raw problem, or the SCAMPER transform being reasoned from>

## Why
<root purpose / real need>

## How
<mechanism serving the Why>

## What
<concrete solution / form>

## What this vantage surfaces
<what becomes visible from here that another vantage would miss>
```

## Next

Terminal — return one vantage's result to the caller (`job-scamper`), which aggregates and judges.
