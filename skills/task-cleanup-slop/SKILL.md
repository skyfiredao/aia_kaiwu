---
name: task-cleanup-slop
description: Remove AI slop prose from a document without changing its facts or decisions. Use to clean self-justification, preachy imperatives, defensive negation, explanatory padding, duplication, restated ownership, and em-dash abuse from docs ("清理AI垃圾话", "文档瘦身", "remove AI slop from this doc").
is_background: false
handoffs:
  - agent: task-yugong
    label: "Clean the next files (task-yugong)"
    prompt: "Run the same task-cleanup-slop pass on the next batch of files listed above as one scoped task. Confirm scope first, cut only the slop categories, and preserve every fact and decision."
---

# task-cleanup-slop

## Purpose

Remove AI slop prose from a document while preserving every resolved decision, current contract, verified behavior, and unique fact. This pass cuts wording, never facts.

## Behavior contract

1. Confirm scope with the user: which files are included, which are excluded. Do not infer scope from nearby references, directory structure, or related documents.
2. Read each included file in full before cutting.
3. Cut each slop category below. Cutting only; the sole allowed addition is a pointer to an owning document.
4. Preserve meaning. Every resolved decision, contract, verified behavior, and unique fact stays. If a cut would drop a fact, keep the fact and cut only the wording around it.
5. When another document owns a fact, remove the duplicate here and point to the owning document.

## Slop categories

- **Self-justification**: text that only explains why something is or is not present.
- **Preachy imperatives**: keep only a line that states a real, easily-violated technical constraint.
- **Defensive negation**: keep only when it disambiguates two real, easily-confused values or resources. State rules positively; do not enumerate counter-examples to make a point.
- **Explanatory padding**: filler about responsibility, impact, or settled background.
- **Duplication and restated ownership**: facts an overview section already owns, and another document's protocol, API, or business design restated here.
- **Historical reasoning**: resolved alternatives and decision chronology sitting inside a current document.
- **Meta-commentary**: navigation notes such as "this document has three parts", "as mentioned above", "(moved out of X)".
- **Diluting words**: hedges and qualifiers that weaken a rule without adding a fact.
- **Em-dash abuse**: replace an em-dash with a comma, colon, period, or parentheses.

## Hard constraints

- Output only conclusions supported by verifiable evidence.
- Achieve the highest information density and communication efficiency.
- Modify only the files the user included. Leave every excluded file untouched, including ones with related or contradictory content. Do not expand scope without asking.
- This pass preserves meaning. Never drop a resolved decision, contract, or unique fact to shorten prose.
- Add no new sections, compatibility fields, or content. The only addition allowed is a pointer to an owning document.

## Verification

- Grep each changed document for the slop signatures you cut; confirm none remain unintended.
- Confirm `git diff --check` passes.
- Confirm the changed-file list stays within the authorized scope.
- Re-read each changed document: every remaining sentence carries a unique fact, contract, or decision.

## Output shape

```
## Cleaned
<file>: <N cuts>, <categories>

## Preserved
<facts and decisions kept, unchanged>

## Out of scope
<dependencies noticed in excluded files, or none>
```

## Next

Next step: clean the next batch of files (via task-yugong), or route the cleaned document to the user for review.
