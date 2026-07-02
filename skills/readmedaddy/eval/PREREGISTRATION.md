# Pre-registration — detection accuracy and gate-score lift

Committed before any result was collected, so the headline numbers cannot be
p-hacked out of a fixtures x gates x runs grid after the fact. The hypothesis,
the analysis, the floor, and the falsifiers below are fixed. Results live beside
this file once produced and are cited from the skill only after they exist.

## The claims under test

readmedaddy's differentiator is a **contextual multi-gate ranking system**:
detect the archetype, weight the gates for that archetype, generate and rank
candidates, verify every claim. The complexity only earns its place if it does
two measurable things.

- **Claim 1 — Detection.** readmedaddy assigns the correct archetype to all
  **4/4** fixtures and cites the signals it used. The fixtures span four
  archetypes (`cli`, `library`, `agent-skill`, `research`) across three
  languages, so the classifier must read entrypoints and manifests, not file
  extensions.
- **Claim 2 — Lift.** For every fixture, the README readmedaddy produces scores
  **higher on the contextual weighted total than the thin baseline README**,
  blind-judged through the same rubric, by at least the margin below.

## Design

- **Unit of analysis:** one fixture. Four fixtures, scored independently. No
  averaging across fixtures for the pass/fail decision — every fixture must
  clear its bar on its own.
- **Control:** `baseline-README.md` in each fixture — a deliberately thin README
  (weak hook, no real quickstart, no visual, no badges, no completeness).
- **Treatment:** the README readmedaddy generates from the same skeleton with the
  baseline hidden.
- **Scoring:** the blind judge (`judge-prompt.md`) scores each README on G1..G10,
  applies the archetype weights, and returns a weighted `/100`. `score.py`
  independently recomputes that total from the per-gate scores using the rubric's
  weights, so a judge arithmetic slip cannot move the result.
- **Blindness:** for each fixture the two READMEs are presented in randomized
  order under neutral labels (`README-A`, `README-B`). The judge is given the
  archetype but never told which README is the baseline, which is readmedaddy, or
  that a comparison is even happening. The judge scores each in isolation.
- **Repetition:** judge each README at least `N=3` times (independent passes) and
  take the median per-gate score to damp judge sampling noise before computing
  the weighted total.

## Pre-registered thresholds

These are the numbers the eval is graded against. They are absolute points on the
`/100` weighted scale.

| Quantity | Threshold |
|---|---|
| Archetype detection accuracy | **4/4** fixtures correct, every `must_detect_signals` entry covered |
| Per-fixture lift (`readmedaddy - baseline`) | **>= +20.0** on every fixture |
| Mean lift across the four fixtures | **>= +25.0** |
| readmedaddy absolute score | **>= 70.0 / 100** on every fixture |
| Baseline expected band (sanity, not a gate) | typically **<= 45 / 100** |

## The FLOOR (minimum acceptable)

The eval **passes** iff all of the following hold simultaneously:

1. Detection is exactly **4/4** (a 3/4 is a fail, not a 75%).
2. Every fixture shows lift **>= +20.0**.
3. readmedaddy scores **>= 70.0** on every fixture (it wins by being good, not
   merely by the baseline being bad).

Anything below this floor is a failing eval. The floor is per-fixture and
conjunctive on purpose: a strong average that hides one weak fixture does not
pass, because a README skill that only works on three repo types out of four is
not the skill described in the contract.

## What would falsify the skill

The differentiator is the *contextual* ranking — that weighting the gates by
archetype produces better READMEs than a thin default. It is falsified if:

- **Any** fixture's archetype is mis-detected. Detection is the first gate of
  the whole method; if it picks the wrong archetype it pulls the wrong patterns
  and weights the wrong gates, and the rest of the pipeline is built on sand.
- **Any** fixture shows lift `< +20.0`, or the thin baseline ever ties or beats
  the readmedaddy README on the weighted total. If a deliberately bad README is
  competitive, the multi-gate generate-and-rank machinery is not earning its
  cost and a one-shot template would be simpler and just as good.
- readmedaddy's output lands `< 70.0` on any fixture even while beating the
  baseline — the skill is then only "better than terrible", not "good", and the
  contract's quality claim is not met.

A null or reversed result is reported as-is and the skill's framing is corrected
or the skill is rewritten. That is the point of pre-registering: the eval can
say no.

## Threats to validity (acknowledged up front)

- **Judge identifiability.** A README that screams "generated" could leak its
  condition and bias the judge. Mitigation: neutral labels, randomized order,
  per-README isolation. If a judge can name the readmedaddy README above chance,
  the blindness is compromised and that run is discarded.
- **Baseline strawmanning.** The baselines are thin on purpose, but they are the
  *realistic* thin-READMEs the skill exists to replace (a title, a vague line, a
  "run it" usage). They are not empty files; an empty file would inflate lift.
- **Self-judging.** The same model family generates and judges. The blind A/B and
  the independent `score.py` re-computation reduce, but do not eliminate, shared
  bias. A second judge from a different family strengthens any positive result
  and is recommended before the result is cited as load-bearing.
- **Weight drift.** `score.py` mirrors `../references/multi-gate-rubric.md`. If
  the rubric's weights change, the scorer must be updated in the same commit, or
  detection-and-lift numbers computed under mismatched weights are invalid.
