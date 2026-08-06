---
name: task-quick-verify
description: Throwaway prototype answering one design question (logic or UI branch). Use when the user asks "does this state model feel right?" or "what should this look like?" and a cheap concrete artifact would answer faster than more discussion.
is_background: false
handoffs:
  - agent: task-single-plan
    label: "Feed decision to plan"
    prompt: "The prototype above validated a design decision. Use it as input for a written plan."
  - agent: task-multi-build
    label: "Fold into production (task-multi-build)"
    prompt: "Fold the validated decision from the prototype above into the real production code."
  - agent: task-yugong
    label: "Fold into production (task-yugong)"
    prompt: "Fold the validated decision from the prototype above into the real production code under the task-yugong contract."
---

# task-quick-verify

## When to enter

- User (or another skill) asks "does this logic / state model feel right?" or "what should this look like?", a question best answered by a cheap concrete artifact rather than more discussion.

## Behavior contract

1. **Pick a branch first**:
   - **logic** (does this state model / algorithm feel right?): build a tiny interactive terminal app that pushes the state machine through hard-to-reason cases.
   - **UI** (what should this look like?): generate several radically different variations on a single route, switchable via URL search param + floating bottom bar.
2. **Throwaway from day one.** Name it so any reader can see it is a prototype; locate near the target module/page but never on the production build path.
3. **One command to run.** Whatever the project's task runner supports (`pnpm <name>`, `bun <path>`, `python <path>`).
4. **No persistence by default.** State in memory. Scratch DB with "PROTOTYPE, wipe me" name only if the question requires it.
5. **Skip the polish.** No tests, no error handling beyond runnability, no abstractions.
6. **Surface the state** after every action (logic) or variant switch (UI).
7. **Capture when done.** Fold the validated decision into real code. Keep the prototype off main and report its path. Create a throwaway branch or commit only if the current user message asks.

## Hard constraints

- No polish, no tests, no error handling beyond runnability.
- No persistence unless the question requires it.
- No landing prototype code on main.

## Output shape

```
## Question this prototype answers
<one line>

## Branch
logic | UI

## How to run
<one command>

## What the prototype shows
<what the user should try>

## Captured decision (once validated)
<the fact this prototype proved>, prototype at `<path>`
```

**Validation loop.** The prototype's decision is only captured after the **user actually runs** the artifact (or explicitly says "trust the prototype as-is") and reports back what happened. `task-quick-verify` cannot self-validate; the whole point is a concrete artifact for the human to exercise. If validation is skipped, mark the decision as `pending validation` in the output and do not proceed to the next step.

## Next

`task-single-plan` (with the validated decision) or `task-multi-build` / `task-yugong` (to fold the decision into real code).
