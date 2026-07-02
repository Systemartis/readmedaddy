# Blind judge prompt

You are scoring **one** README. You do NOT know who wrote it or whether it is a
thin baseline or a generated candidate, and you are not comparing it to anything
— judge only the text in front of you, on its own merits, for the stated
archetype. Do not try to guess the README's origin; if you find yourself
reasoning about who produced it, stop and score the text.

## Inputs you are given

- `ARCHETYPE` — one of: `cli`, `library`, `framework`, `app-saas`,
  `infra-devops`, `data-ml`, `agent-skill`, `research`, `monorepo`,
  `internal-tool`.
- `README` — the full Markdown of the README under review.

## How to score

Score each of the ten gates from **0 to 5** using the anchors in
[`../references/multi-gate-rubric.md`](../references/multi-gate-rubric.md). The
gates:

- **G1 Hook** — does the first screen instantly convey *what it is* and *why you'd
  care*? A sharp concrete one-liner, not a history lesson.
- **G2 Identity / trust** — name, one-liner, badges (CI / version / license),
  tasteful social proof.
- **G3 Visual** — ASCII art, logo, diagram, screenshot, or demo that is *apt* and
  earns its space; 0 if missing where the archetype expects one, or if it is
  noise.
- **G4 Quickstart** — install plus the smallest real usage, copy-pasteable and
  correct, in under 30 seconds.
- **G5 Scannability** — heading hierarchy, short paragraphs, tables, a TOC when
  long; skimmable in 20 seconds.
- **G6 Completeness** — usage, config, examples, links, contributing, license,
  without bloat.
- **G7 Credibility** — real examples, test/CI signals, honest limitations and
  non-goals.
- **G8 Contextual fit** — does it follow the conventions of its `ARCHETYPE`?
- **G9 Community / maintenance** — contributing, code of conduct, changelog,
  support / roadmap signals.
- **G10 Voice** — distinct and confident, with NO AI-slop (no "in today's
  fast-paced world", no "it's not X, it's Y" stacking, no rule-of-three padding,
  no em-dash spam).

Then apply the **archetype weights** for `ARCHETYPE` from the rubric's resolved
weight vectors to get the weighted total on a `/100` scale. (The weights differ
by archetype: a `cli` rewards G3/G4/G1; a `library` rewards G4/G2/G6; an
`agent-skill` rewards G1/G4/G8; `research` rewards G1/G7/G6.) Each archetype's
weights sum to 29, so the maximum raw weighted score is 145 and the total is
`round(sum(weight_i * score_i) / 145 * 100, 1)` — a straight-5s README scores
exactly 100.

Be strict and literal. A quickstart that would not actually run is G4 <= 2, even
if it looks tidy. A visual that is decorative noise is G3 <= 1, not a 3 for
effort. Reward only what is on the page.

## Output

Return a per-gate table followed by a fenced JSON block. Nothing else.

```
| Gate | Score (0-5) | Note |
|------|-------------|------|
| G1   |             |      |
| G2   |             |      |
| G3   |             |      |
| G4   |             |      |
| G5   |             |      |
| G6   |             |      |
| G7   |             |      |
| G8   |             |      |
| G9   |             |      |
| G10  |             |      |
```

```json
{"archetype": "<ARCHETYPE>", "scores": {"G1": 0, "G2": 0, "G3": 0, "G4": 0, "G5": 0, "G6": 0, "G7": 0, "G8": 0, "G9": 0, "G10": 0}, "weighted_100": 0.0}
```

The JSON `scores` object is the source of record. The harness re-computes
`weighted_100` from it with `score.py`, so if your hand-applied weighting and the
scorer disagree, the scorer's number wins — fill `scores` exactly and honestly
and the total takes care of itself.
