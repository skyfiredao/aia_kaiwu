---
name: task-yugong
description: DEFAULT SKILL for concrete implementation tasks. Handles one clearly-scoped task with full engineering discipline, no delegation, no scope expansion. Prefer over `task-multi-build` when the task is single-scope.
is_background: false
agents: []
---

# task-yugong (default)

## Basket definition

A **basket** = one atomic step verified by exactly one machine-checkable predicate.

- Multiple file writes MAY occur within a single basket only if they collectively serve that one predicate (e.g., add a function + its import so one test passes).
- TDD red-and-green counts as **two** baskets. Writing the failing test is one basket (predicate = test file exists and fails when run); making it pass is another (predicate = same test now passes).
- Unrelated edits are separate baskets.

## Behavior contract

1. Do only the task in the current message. Do not expand scope.
2. Apply always-on discipline (`AGENTS.md` section 3) in full, especially TDD (section 3.9).
3. Do each basket, verify with its predicate, then move to the next. State which basket just moved and which is next.
4. When a basket fails, before retrying, articulate what will be **materially different** in the next attempt (new hypothesis, new code path, new assumption, new data). Identical inputs and identical logic produce identical outputs; if no material difference can be named, further retry is futile.
5. Continue retrying with materially differentiated attempts as long as you can produce them. When no differentiated next attempt exists for a failing basket → emit `Quit: <reason>`.
6. If the task turns out larger than expected (requires decomposition beyond a single basket loop) → emit `Quit: scope-too-big`.
7. If you notice an issue outside the current task scope (security bug, tech debt, wrong assumption in nearby code), record it under `## Incidental findings` in the output. Do not silently fix it; do not silently drop it.

## Hard constraints

- **Machine-verifiable done gate.** `Done` requires a task-level verification predicate that exercises the user's stated goal (not a proxy like compilation, syntax check, or unrelated smoke test) and its raw output. `[ok]` on individual baskets requires basket-level machine-checkable predicates. "Looks right" / "should work" / "compiled" is not `[ok]` or `Done`.
- **Foreground-only execution.** Refuse background dispatch (`run_in_background=true` / `--async` / detached). Surface violation on first output line.
- No hand-off of the primary task; you own the task from start to finish.
- No spawning parallel subagents for the main work.
- No "while I was there I also …".

## Output shape

```
## Task
<one line: the mountain being moved>

## Baskets
1. [ok] <step>, <predicate + raw verification output>
2. [ok] <step>, <predicate + raw output>
3. [fail] <step>, <differentiated attempts tried + why no further material difference is possible>

## Incidental findings (optional; omit section if none)
- <one-line finding + file:line + why not addressed in this task>

## Verification
<final task-level command run + raw output>

Done | Quit: <reason>
```

State legend (2 basket states):
- `[ok]`: completed and verified by a machine-checkable predicate
- `[fail]`: attempted with materially differentiated retries but did not pass; contributes to `Quit`

Terminal (2 modes):
- `Done`: all baskets `[ok]` and the task-level verification predicate passed
- `Quit: <reason>`: unable to articulate a materially different next attempt for at least one basket; reason names the specific cause (e.g., `retry-exhausted: no material difference available`, `no-progress: same file set without new hypothesis`, `scope-too-big: requires decomposition`, `external-dependency: <what's missing>`, `authorization: <what needs approval>`)

## Next

Terminal — return the `Done` / `Quit` signal to the caller.
