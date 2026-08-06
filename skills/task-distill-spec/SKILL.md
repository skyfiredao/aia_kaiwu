---
name: task-distill-spec
description: Distill an overview-level project spec (glossary, core domain model, design principles, main business logic) from existing project docs into a preloadable AGENTS.md-style file, so a team's AI tools share one baseline and avoid information gaps, inconsistent terminology, and design drift. Compress and define only; never infer new design. A static snapshot — re-run when source docs change. Triggers — "蒸馏项目 spec", "生成项目 overview/术语基线", "distill a project overview for the team to preload".
is_background: false
agents: [task-explore, task-multimodal-looker]
---

# task-distill-spec

## Purpose

Produce an overview-level, preloadable project spec from existing project documentation, so every team member's AI tool starts from the same baseline: shared vocabulary, core concepts, design principles, and main business logic. It exists to prevent three failures: information asymmetry, inconsistent terminology, and design-direction drift.

This is a summary layer that sits on top of the detailed docs. It does not replace them, hold authority over them, or change any design decision.

## When to enter

- User asks to distill a project overview / concept baseline for AI preloading ("蒸馏项目 spec", "生成项目 overview/术语基线", "distill a project overview for the team to preload").
- AI-tool onboarding material is needed and the project already has design / requirement docs.
- Source docs changed and the existing distilled spec must be regenerated.

## Inputs

- Project documentation: design docs, requirement docs, PRDs, ADRs, architecture notes (the primary source).
- Optionally, conversation history — used ONLY to pick up already-adopted decisions not yet written into docs (latest adopted decision wins; never rejected or superseded proposals).
- Output path for the preload file. Default to the project's agent preload file; never clobber an existing authority / rules doc — if one exists, write a distinctly-named overview file instead.

If no source docs are available, stop and say so. Never distill from memory.

## Admission gate

An item earns a place in the spec only if ALL three hold:

1. **Project-specific** — general knowledge does not cover it (skip generic programming / domain concepts).
2. **Non-obvious** — a newcomer or their AI would misunderstand it or not know it.
3. **Traceable** — it cites a concrete source (`doc:section`). Untraceable items are excluded.

## Steps (single pass)

1. **Locate sources.** Use `task-explore` to find the project's docs; read them. For PDF / diagram / image docs, use `task-multimodal-looker`. From conversation history, take only already-adopted decisions as deltas (latest wins).
2. **Extract through the admission gate.** Collect candidate terms, concepts, principles, and business rules that pass all three conditions.
3. **Compress and define — never infer.** Each entry states only what the source says, compressed, with its source cite. Do not add, resolve, or invent design decisions.
4. **Flag conflicts.** Where two sources define the same term / concept differently, record both with a conflict flag; do not pick or fabricate a resolution.
5. **Write the spec** to the output path, within the size discipline below.
6. **Append a non-blocking human-review note** listing what to verify. Terminate; do not wait for approval.

## Size discipline

No fixed line / token cap. Size is controlled by:

- the admission gate (the main filter — most content is excluded);
- per-entry compression (term = definition + one-line significance + source; business logic = invariant / flow in a few lines, not prose);
- a readable-in-one-sitting ceiling (a human must be able to review the whole thing for fidelity). If it exceeds that, the gate was too loose or the project surface is too large — split by domain into multiple preload files.

## Output shape

```
# <Project> — Overview Spec
> Distilled overview for AI preload. Summary layer over the detailed docs; not authoritative. Distilled: <timestamp>. Sources: <doc list>.

## Glossary
- **<term>**: <definition> — <why it matters>. [source: <doc:section>]

## Core domain model
- <entity> — <role>; <relationship to others>. [source: <doc:section>]

## Design principles
- <principle, as stated by the source>. [source: <doc:section>]

## Core business logic
- Invariant: <what must always hold>. [source: <doc:section>]
- Main flow: <step → step → step>. [source: <doc:section>]

## Flagged conflicts (for humans to resolve)
- <term/concept>: <definition A> [source A] vs <definition B> [source B]

## Human review requested (non-blocking)
- Verify traced entries match their sources.
- Resolve the flagged conflicts in the source docs, then re-distill.
```

## Hard constraints

- Compress and define only; never infer, resolve, or invent design decisions.
- Every entry traces to a concrete source; untraceable content is excluded.
- Docs are the primary source; conversation history contributes only already-adopted decisions (latest wins), never rejected / superseded proposals.
- Conflicts are flagged, never silently resolved.
- Overview depth ceiling: core domain model + key invariants + main flows; deeper detail stays in the source docs.
- Static snapshot: no incremental / dynamic updates. When sources change, re-distill from scratch.
- Never clobber an existing authority / rules doc; write a distinctly-named overview file if one exists.
- Foreground, single pass. The human-review note is output, not a blocking gate.
- Never distill from memory; if no source docs exist, stop and say so.

## Next

Terminal — produce the overview spec and return to the caller. The human-review note is advisory.
