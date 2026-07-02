# readmedaddy eval harness

The Iron-Law test for readmedaddy: no skill behavior ships without a failing
test or eval first. This package proves two things rather than asserting them:

1. **Detection** — readmedaddy classifies a repo into the *right archetype* and
   names the signals it used.
2. **Lift** — the README readmedaddy produces *beats a thin baseline* through the
   contextual gates, scored by a judge who does not know which README is which.

The committed hypothesis, margins, floor, and falsifiers are in
[`PREREGISTRATION.md`](PREREGISTRATION.md). They were fixed before any result
was collected; do not edit them to fit an outcome.

## What's here

- `fixtures/<name>/` — four minimal-but-realistic repo skeletons, one per target
  archetype. Each ships:
  - the repo skeleton itself (manifests, an entrypoint or API, tests where they
    belong) — the input readmedaddy analyzes;
  - `baseline-README.md` — a deliberately thin README, the control to beat;
  - `expected.json` — `{archetype, must_detect_signals}`, the detection answer key.
- `judge-prompt.md` — the blind judge. Scores one README at a time against the
  contextual rubric, given only the archetype, returning a per-gate table and a
  weighted `/100`. Never told which README is baseline vs. readmedaddy.
- `score.py` — stdlib-only. Recomputes the weighted `/100` from per-gate scores
  using the same per-archetype weights as
  [`../references/multi-gate-rubric.md`](../references/multi-gate-rubric.md), so
  a judge's arithmetic can be checked independently. Runs its own self-tests.

## The four fixtures

| Fixture | Archetype | What it is | Why it's a good test |
|---|---|---|---|
| `cli-fixture/` | `cli` | a Node CLI with a `bin` entry and `--help` | the classic ASCII/demo/quickstart-led README |
| `lib-fixture/` | `library` | a Python package exporting a public function | API-usage and badges, *no* CLI entrypoint |
| `skill-fixture/` | `agent-skill` | a `skills/demo/SKILL.md` with trigger frontmatter | readmedaddy's own archetype; trigger + examples |
| `research-fixture/` | `research` | a notebook + `CITATION.cff` + a dataset note | abstract/results/citations, not an installable |

The mix is deliberate: language alone does not give the archetype away (the CLI
is Node, the library is Python, both could be mistaken for "a project"), so
detection has to read entrypoints and manifests, not just file extensions.

## How to run

The fixtures and judge prompt are model-driven; there is no single binary that
produces a README. The procedure, per fixture:

1. **Detect.** Point readmedaddy at the fixture directory with `baseline-README.md`
   hidden. Record the archetype it chooses and the signals it cites. Compare to
   `expected.json`: the archetype must match exactly and every
   `must_detect_signals` entry must be covered. Detection accuracy = fixtures
   passed / 4.
2. **Generate.** Let readmedaddy produce its README for the fixture (single-pass
   is fine; the skeletons are not high-stakes tournament work).
3. **Judge blind.** For each fixture, hand the judge the two READMEs —
   `baseline-README.md` and the readmedaddy output — in randomized order under
   neutral labels (`README-A`, `README-B`), plus the fixture's archetype. The
   judge scores each independently per `judge-prompt.md`. Collect per-gate scores.
4. **Re-score.** Feed the judge's per-gate scores to `score.py` (TSV or JSON) to
   recompute each weighted `/100` and confirm the judge's arithmetic.
5. **Compute lift.** `lift = readmedaddy_total - baseline_total`, per fixture.

```sh
# verify the scorer itself
python3 score.py                       # runs inline self-tests, exits 0 on pass

# score a sheet of judge results (one README per row)
python3 score.py results.tsv           # header: readme  archetype  G1..G10
python3 score.py results.json          # [{"readme","archetype","scores":{...}}]
```

## What passing means

Read the binding thresholds in [`PREREGISTRATION.md`](PREREGISTRATION.md). In
short, the eval passes iff:

- **Detection:** 4/4 fixtures get the correct archetype with all must-detect
  signals covered (no partial credit — 3/4 fails the claim).
- **Lift:** on *every* fixture the readmedaddy README's weighted total exceeds
  the baseline's by at least the pre-registered margin, blind-judged.
- **Absolute floor:** the readmedaddy README clears the pre-registered minimum
  score on every fixture, so it wins by being good, not merely by the baseline
  being bad.

A miss on any fixture does not get averaged away. One mis-detected archetype, or
one fixture where the thin baseline ties or beats readmedaddy, falsifies the
differentiator and the result is reported as-is.

## Results

| Run | Verdict | Detection | Lift range | Mean lift | Floor |
|---|---|---|---|---|---|
| [2026-07-02](results/2026-07-02/report.md) | **PASS** | 4/4 | +58.6 … +79.3 | +65.7 | 71.7–89.0 (≥ 70) |

Each run's directory holds the full report, the raw per-pass judge scores, and
the generated READMEs, so the numbers can be re-derived with `score.py`.
