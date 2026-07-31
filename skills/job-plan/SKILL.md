---
name: job-plan
description: Workflow for turning an ambiguous or multi-step request into approved, persisted plan artifacts. Chains clarify → single-plan → challenge → user approval → persist plan (and optionally design / guide / README) to spec/<slug>/.
is_background: false
agents: [task-clarify, task-single-plan, task-challenge]
handoffs:
  - agent: job-build
    label: "Execute the persisted plan (job-build)"
    prompt: "The plan artifacts above were approved by the user and persisted to `spec/<slug>/`. Execute per `spec/<slug>/plan.md` under job-build (TDD, checkpoint every ~3 steps, stop and report if scope grows)."
---

# job-plan

## When to enter

- Request is ambiguous or contains contradictions
- Request is ≥ 2 steps and no plan is provided
- User says "plan first" / "help me break this down" / "先做个计划" / "怎么做" / "拆解一下"
- Architectural choice on the table
- Scope not obvious

## Steps

1. **`task-clarify`**: Critique the request itself. Enumerate hidden assumptions, ambiguities, likely AI failure modes. Recommend the single most valuable clarifying question.
2. **gate: user answers the clarifying question.** Do not proceed without an answer.
3. Invoke **`task-single-plan`** to produce:
   - Plan title (used to derive `<slug>`)
   - Numbered plan (tracer-bullet vertical slices; each step names file + expected result + verification)
   - Assumptions and Open Questions
   - `Artifacts to persist` block: marks `design.md`, `guide.md`, `README.md` as `yes`/`no` based on plan characteristics (architectural / ops-affecting / user-facing)
   - Emit the corresponding artifact section for every `yes` mark, using the templates in `skills/task-single-plan.md`
4. **`task-challenge`**: Adversarial review of the plan and any emitted artifact sections. Flag drifted, merged, missing steps.
5. Read `task-challenge`'s **verdict** field (values: `approve` / `needs-revision` / `reject`). If `needs-revision` or `reject` → revise (return to step 3). If `approve` → proceed. (The per-step `[blocker]` / `[should-fix]` / `[nice-to-have]` labels are severity annotations; the verdict is the gate.)
6. **gate: user approves the plan artifacts.** Show the user the `Artifacts to persist` list; user can add or remove any of design.md / guide.md / README.md from the write set. Do not proceed to persistence without explicit user OK.
7. Persist the approved artifacts directly (job-plan writes these files itself; no executor dispatch):
   - Derive `<slug>` from the plan title (kebab-case, ≤ 40 chars; append `-N` on collision with existing `spec/<slug>/` directories)
   - Create `spec/<slug>/` if missing
   - Write `spec/<slug>/plan.md` (always; the numbered plan)
   - For each artifact marked `yes` in the approved list, write the corresponding section to `spec/<slug>/<artifact>.md`
   - Never write an artifact whose section was not emitted in step 3 or was removed by the user in step 6
8. Terminate. Emit the slug and the list of persisted file paths so `job-build` can read from disk.

## Dispatch rules

- Never skip `task-clarify` when the request is ambiguous.
- Never proceed past step 6 (user approval) without explicit OK from the user.
- Never write anything to `spec/<slug>/` before step 6 approval (steps 1-6 are strictly chat-only).
- Never write implementation code inside this workflow. Step 7 writes only plan artifact files under `spec/<slug>/`.
- Never write `design.md` / `guide.md` / `README.md` if the corresponding section was not produced in step 3 (no fabrication at write time).
- Output MUST end with the line `[persisted: <comma-separated file paths>]` on success, or `[not persisted: <reason>]` if the workflow terminated before step 7.

## Output shape

```
## Restatement
<one paragraph>

## Clarifying question (from task-clarify)
> <the one question>

## Plan title
<one line>

## Plan (from task-single-plan)
1. <file: what / expected result / verification>
2. ...

## Assumptions / Open Questions
- ...

## Artifacts to persist (recommended)
- plan.md: always
- design.md: [yes|no] <reason>
- guide.md: [yes|no] <reason>
- README.md: [yes|no] <reason>

## Design (if yes)
<per template>

## Guide (if yes)
<per template>

## README (if yes)
<per template>

## Adversarial review (from task-challenge)
### [blocker] / [should-fix] / [nice-to-have]
- <per-step findings>

## Approval status
<pending user approval | approved | needs revision>

## Persistence
- spec/<slug>/plan.md: <written | not written>
- spec/<slug>/design.md: <written | skipped, reason X>
- spec/<slug>/guide.md: <written | skipped, reason X>
- spec/<slug>/README.md: <written | skipped, reason X>

[persisted: spec/<slug>/plan.md, spec/<slug>/design.md, ...]
```

## Handoff

`job-build` (once persisted). The handoff prompt references `spec/<slug>/plan.md` so the executor reads the plan from disk, not from chat context. If `spec/<slug>/design.md` or `guide.md` exists, the executor may consult them as needed.
