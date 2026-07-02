# Eval run — 2026-07-02

First execution of the pre-registered eval in [`../../PREREGISTRATION.md`](../../PREREGISTRATION.md).
The hypothesis, thresholds, floor, and falsifiers were committed before this run;
nothing below was chosen after seeing a result.

**Verdict: PASS — every pre-registered threshold cleared on every fixture.**

## Protocol

- **Generation.** One fresh agent context per fixture executed the skill
  (SKILL.md + references) against the fixture directory with
  `baseline-README.md` and `expected.json` explicitly off-limits. Each agent
  reported its detected archetype, the repo signals it used, and its generated
  README (committed beside this report as `generated-*.md`).
- **Judging.** 24 independent passes: 8 READMEs (4 baselines + 4 generated)
  × 3 passes each. Every judge was a fresh context given only
  [`judge-prompt.md`](../../judge-prompt.md), the rubric anchors, the archetype,
  and one README under an anonymized filename (`r1.md`–`r8.md`, assignment
  shuffled with seed `20260702`). No judge saw a pair, a label, or any hint of
  origin. Raw per-pass scores: [`judge-scores.json`](judge-scores.json).
- **Aggregation.** Median per-gate score across the 3 passes, per README;
  weighted totals recomputed independently by [`score.py`](../../score.py)
  (rubric sum-29 vectors, /145 normalization) — judge arithmetic was not
  trusted.
- **Model.** Claude Fable 5 (`claude-fable-5`) for both generation and judging,
  in separate contexts.

## Claim 1 — Detection: 4/4

| Fixture | Expected | Detected | Must-detect signals covered |
|---|---|---|---|
| `cli-fixture` | `cli` | `cli` | 5/5 — `bin` field, shebang, `--help`/`--version`, subcommand surface, terminal framing; CLI-vs-library disambiguated (module export identified as secondary) |
| `lib-fixture` | `library` | `library` | 5/5 — no `[project.scripts]`, `__all__` public API, `py.typed`, pytest suite, importable-package classifiers |
| `skill-fixture` | `agent-skill` | `agent-skill` | 5/5 — `skills/<name>/SKILL.md` layout, frontmatter name+description, trigger-style description, `references/` progressive disclosure, no binary/package |
| `research-fixture` | `research` | `research` | 5/5 — `CITATION.cff` with abstract/DOI, figure-reproducing notebook, dataset note, `results/`, no installable; research-vs-data-ML disambiguated |

## Claim 2 — Lift (blind-judged, median of 3 passes, score.py-recomputed)

| Fixture | Baseline /100 | readmedaddy /100 | Lift | Floor ≥ 70 | Lift ≥ +20 |
|---|---:|---:|---:|:--:|:--:|
| `cli-fixture` | 15.9 | 75.2 | +59.3 | pass | pass |
| `lib-fixture` | 13.1 | 71.7 | +58.6 | pass | pass |
| `skill-fixture` | 12.4 | 77.9 | +65.5 | pass | pass |
| `research-fixture` | 9.7 | 89.0 | +79.3 | pass | pass |

Mean lift **+65.7** (threshold ≥ +25). Every baseline landed inside the
pre-registered ≤ 45 sanity band (9.7–15.9), so no baseline was accidentally
strong or artificially empty.

Median per-gate scores for the generated READMEs (G1…G10):

| Fixture | Medians |
|---|---|
| `cli-fixture` | 5, 4, 4, 3, 4, 4, 3, 4, 1, 5 |
| `lib-fixture` | 5, 4, 2, 3, 5, 4, 4, 4, 1, 4 |
| `skill-fixture` | 5, 4, 3, 3, 4, 4, 4, 5, 1, 4 |
| `research-fixture` | 5, 3, 2, 5, 5, 5, 5, 5, 2, 5 |

The consistent G9 ≈ 1 across generated READMEs is honest: the fixtures ship no
CONTRIBUTING/CHANGELOG/community surface, and the skill invents nothing, so the
community gate has nothing to score. The weighting absorbs this — G9 is a base-2
gate for all four archetypes tested.

## Threats to validity (as pre-registered)

- **Self-judging.** The same model family generated and judged, mitigated by
  blind isolation and independent `score.py` recomputation but not eliminated.
  Per the pre-registration, a second judge from a different model family is
  recommended before this result is cited as load-bearing.
- **Judge noise.** Per-pass totals varied by up to ~9 points on the same README
  (e.g. cli generated: 80.0 / 75.2 / 71.0); the median-of-3 aggregation is the
  pre-registered damping for exactly this.
- **Fixture scale.** Four fixtures across four archetypes; six archetypes are
  untested by this run.
