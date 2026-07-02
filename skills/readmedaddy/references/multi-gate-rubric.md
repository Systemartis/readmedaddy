# The contextual multi-gate rubric

This is the core ranking IP. Every candidate README — a whole draft, a competing
draft in tournament mode, or a single section from a generator pass — is scored
against ten gates. Each gate gets a raw score from 0 to 5 against a concrete
anchor. Each gate also carries a **weight that depends on the project's
archetype**: the same gate matters more for a CLI than for a research repo. The
output is a per-gate table plus one weighted total out of 100.

The total is not a grade you file away. It is the **selection function**. The
highest-scoring draft becomes the skeleton, the per-gate winners get grafted
into it, and the per-gate *deficits* tell you exactly what to fix and in what
order. Score to pick and merge, not just to judge.

Detect the archetype first (see `archetypes.md`); the weighting below keys off
it. Gate IDs `G1`–`G10` are the same everywhere in this skill.

## How to score a gate

Each gate has a concrete 0-anchor and 5-anchor. Score the space between by
interpolation:

| Score | Meaning |
|-------|---------|
| 0 | the 0-anchor, or the anti-pattern the gate names |
| 1–2 | a real but weak signal — present, doesn't land |
| 3 | solid but plain — does the job, nothing more |
| 4 | strong — one thing short of the anchor |
| 5 | the 5-anchor with nothing missing |

Two rules hold for every gate. **Never invent a number:** each score must trace
to something actually on the page. **Verify before you credit:** badges,
benchmarks, and links score for what resolves, not for what is claimed (see
*Scoring discipline*).

## The ten gates

Each gate states what it measures, its 0- and 5-anchors, a one-line litmus for
novel cases, and what does **not** move the score.

### G1 — Hook

Does the first screen convey **what it is + why you'd care**, in one line,
before any history?

- **0:** "A project for X." / "This repository contains…" / a paragraph of backstory before the reader learns what the thing does.
- **5:** one sharp, concrete sentence you can repeat from memory — names the thing, the outcome, and who it's for (e.g. "recursively searches directories for a regex while respecting your gitignore").
- **Litmus:** cover everything below line three. Can a stranger say what this is and why they'd use it? If not, it is not a 5.
- **Doesn't move it:** how long the rest of the README is, how clever the name is, how good the code is. The hook is judged on the first screen alone.

*Why: the reader decides whether to keep reading in the first five seconds; the hook is the only gate they reach before bouncing.*

### G2 — Identity / trust

Name, one-liner, and badges (CI, version, license, downloads) plus tasteful
social proof.

- **0:** bare name, no tagline, no badges — or badges for things that don't exist (invented star counts, fake download numbers, a CI badge with no CI).
- **5:** name + one-liner + a tight row of **real** badges (CI status, version, license) and at most a line of honest social proof.
- **Litmus:** do the trust signals here actually resolve? A badge that 404s or a star count nobody can verify scores 0, not 5.
- **Doesn't move it:** badge count beyond the useful set. Badge spam does not raise this gate and can lower G5.

*Why: trust signals are only worth points if they are true; a fabricated badge is worse than none.*

### G3 — Visual

ASCII wordmark, logo, diagram, screenshot, or demo gif that is **apt** and
earns its space.

- **0:** no visual where the archetype expects one (a CLI with no demo, an app with no screenshot), **or** decorative noise that conveys nothing.
- **5:** one visual that conveys the core idea in about five seconds — a gif of the CLI running, an apt pipeline or dial diagram, a clean figlet wordmark, or a product screenshot.
- **Litmus:** cover the prose. Does the visual alone tell you what this does or what it looks like? If it is only texture, it is a 1, not a 5.
- **Doesn't move it:** polish for its own sake. A beautiful banner that conveys nothing is still not a 5; aptness beats prettiness.

*Why: the right image carries meaning the reader would otherwise spend three paragraphs to absorb.*

### G4 — Quickstart

Install + smallest real usage in under 30 seconds, copy-pasteable, correct.

- **0:** no install/usage, **or** steps written as prose ("clone the repo and build it") rather than runnable commands, **or** commands that are wrong.
- **5:** a single fenced block you can paste into a fresh shell and run, which installs and shows one real result.
- **Litmus:** could you paste this block unedited and get the advertised result? If you have to guess or fill in a command, it is not a 5.
- **Doesn't move it:** how many install methods are listed. One correct copy-paste path beats five partial ones.

*Why: a quickstart that doesn't run is a broken promise on the page most readers try first.*

### G5 — Scannability

Heading hierarchy, short paragraphs, tables, and a TOC once the doc is long;
skimmable in 20 seconds.

- **0:** walls of text with no headings, or a flat list of twenty H2s with no hierarchy; you cannot find anything in 20 seconds.
- **5:** clean H1 > H2 > H3 nesting, paragraphs under ~4 lines, tables for comparisons, and a TOC once the doc passes ~2 screens.
- **Litmus:** in a 20-second skim, can you locate install, usage, and config? If you have to *read* in order to navigate, it is not a 5.
- **Doesn't move it:** total length, as long as structure scales with it. A long README can still score 5.

*Why: most readers skim before they read; structure is what lets them find the one thing they came for.*

### G6 — Completeness

Usage, config, examples, links, contributing, and license — **without bloat**.

- **0:** core sections missing (no usage, no license) **or** padded with filler that adds no information.
- **5:** every section a reader needs is present, and nothing is padded; each section earns its place.
- **Litmus:** is there a question a real user would have that the README never answers, or a section a reader would skip entirely? Either one keeps it off 5.
- **Doesn't move it:** optional sections the archetype doesn't need. A library is not docked for omitting a screenshot.

*Why: completeness is measured against what this kind of reader needs, so padding costs points the same way a gap does.*

### G7 — Credibility

Real examples, tests/CI signals, and honest limitations and non-goals.

- **0:** no examples, no test/CI signal, no statement of limits — or claims you can't trust (invented benchmarks, "blazing fast" with no number).
- **5:** runnable examples with real output, a visible CI or test signal, and an explicit limitations / non-goals section.
- **Litmus:** does the README give you a reason to believe it works, and does it admit what it does *not* do? Confidence without either is not a 5.
- **Doesn't move it:** marketing superlatives. "Fastest ever" with no benchmark lowers credibility rather than raising it.

*Why: a README that names its limits is more trustworthy than one that only sells, and unverifiable claims actively subtract.*

### G8 — Contextual fit

Follows the conventions of its archetype.

- **0:** wrong shape for the type — a CLI with no command examples, a library with no import/API snippet, a research repo with no results or citations.
- **5:** hits the must-have sections and the expected visual for its archetype (see `archetypes.md`).
- **Litmus:** would a regular user of *this kind* of project find what that kind of project's README always has? A missing convention keeps it off 5.
- **Doesn't move it:** conventions from a different archetype. A CLI does not need an API reference to score 5.

*Why: readers arrive with genre expectations; matching them is most of why a README feels "right" without the reader knowing why.*

### G9 — Community / maintenance

Contributing, code of conduct, changelog, and support/roadmap signals.

- **0:** no contributing guidance, no changelog, no support channel, no sign the project is maintained.
- **5:** links to CONTRIBUTING and a code of conduct, a changelog, and a clear support or roadmap line.
- **Litmus:** if you hit a bug or wanted to contribute, does the README tell you where to go? If not, it is not a 5.
- **Doesn't move it:** for a one-off or archived project, an honest "not accepting contributions" is fine and is not penalized. Absence of process is only a gap when the project pretends to have it.

*Why: maintenance signals tell a reader whether the project is alive, which decides whether they'll depend on it.*

### G10 — Voice

Distinct, confident, and free of AI-slop.

- **0:** AI-slop — "in today's fast-paced world," stacked "it's not X, it's Y," rule-of-three padding, em-dash spam, hedging in every sentence.
- **5:** plain, confident sentences that lead with the outcome and read like a person who built the thing.
- **Litmus:** read it aloud. Does it sound like a confident maintainer or like generated filler? Any slop tell keeps it off 5.
- **Doesn't move it:** formality level. A terse voice and a warm voice both score 5 as long as neither is slop.

*Why: voice is the difference between a README people quote and one they forget; slop reads as low-effort no matter the content.*

## Contextual weighting

Every gate starts at a **base weight of 2**. Each archetype then bumps its three
heaviest gates by **+4, +3, and +2** (most important first). The bumps always
sum to +9 and the ten base weights sum to 20, so **every archetype's weights
total 29** — the maximum possible weighted score is always `29 × 5 = 145`, and
normalization uses the same divisor every time.

Default weight vector (before bumps):

| Gate | G1 | G2 | G3 | G4 | G5 | G6 | G7 | G8 | G9 | G10 |
|------|----|----|----|----|----|----|----|----|----|-----|
| Base | 2  | 2  | 2  | 2  | 2  | 2  | 2  | 2  | 2  | 2   |

Per-archetype bumps (added on top of the base):

| Archetype | +4 (heaviest) | +3 | +2 | Non-gate aspects fold into |
|-----------|---------------|----|----|----------------------------|
| CLI tool | G3 visual/demo | G4 quickstart | G1 hook | — |
| Library / framework | G4 API usage | G2 badges | G6 completeness | — |
| App / SaaS | G1 hook | G3 screenshot | G9 community | — |
| Infra / devops | G4 quickstart | G7 credibility | G6 completeness | — |
| Data / ML | G1 hook | G7 results/benchmarks | G6 completeness | citations score under G6 + G7 |
| Agent skill / plugin | G1 hook | G4 examples | G8 fit | trigger description scores under G1 + G8 |
| Research | G1 finding/abstract | G7 reproducibility | G6 completeness | abstract → G1; citations → G6 |
| Monorepo / internal-tool | G5 scannability | G6 completeness | G1 hook | navigation scores under G5 |

The ten archetypes map onto eight weighting groups: *framework* inherits
*library*'s weighting and *internal-tool* inherits *monorepo*'s. Data/ML and
research share one numeric vector (G1/G7/G6) but read those gates differently —
for research, G7 is reproducibility and the citation block lives under G6.
readmedaddy itself is **agent skill / plugin**, so its own README is scored on
the row that bumps G1, G4, and G8.

### Resolved weight vectors (read these off directly)

The bumps applied. Use the row for the detected archetype as your multipliers;
every row sums to 29.

| Archetype (group) | G1 | G2 | G3 | G4 | G5 | G6 | G7 | G8 | G9 | G10 |
|-------------------|----|----|----|----|----|----|----|----|----|-----|
| CLI tool | 4 | 2 | **6** | **5** | 2 | 2 | 2 | 2 | 2 | 2 |
| Library / framework | 2 | **5** | 2 | **6** | 2 | **4** | 2 | 2 | 2 | 2 |
| App / SaaS | **6** | 2 | **5** | 2 | 2 | 2 | 2 | 2 | **4** | 2 |
| Infra / devops | 2 | 2 | 2 | **6** | 2 | **4** | **5** | 2 | 2 | 2 |
| Data / ML | **6** | 2 | 2 | 2 | 2 | **4** | **5** | 2 | 2 | 2 |
| Agent skill / plugin | **6** | 2 | 2 | **5** | 2 | 2 | 2 | **4** | 2 | 2 |
| Research | **6** | 2 | 2 | 2 | 2 | **4** | **5** | 2 | 2 | 2 |
| Monorepo / internal-tool | **4** | 2 | 2 | 2 | **6** | **5** | 2 | 2 | 2 | 2 |

### Scoring procedure

1. Detect the archetype.
2. Take that archetype's row from the resolved-vectors table (or start every gate at base 2 and apply the +4 / +3 / +2 bumps yourself).
3. Score each gate 0–5 against its anchors.
4. Multiply per gate: `weighted_i = weight_i × score_i`.
5. Sum and normalize: `total = round( Σ weighted_i / 145 × 100, 1 )` — one decimal, matching `eval/score.py` exactly. Equivalently `Σ weighted_i ÷ 1.45`, since the weights always sum to 29.

For the fix list, also compute each gate's **deficit**:
`deficit_i = weight_i × (5 − score_i)`. The deficit is how many normalized
points that gate leaves on the table. Rank fixes by deficit, highest first — the
bumped gates surface first whenever they are weak, so the rubric tells you
*what* to fix, not only how bad it is.

## Worked scorecard

A plausible thin CLI README — not a strawman, the kind that ships on a real
weekend project:

```
# fastcat

A tool for printing files.

## Installation

Clone the repo and build it.

## Usage

Run the binary with a filename.
```

Archetype: **CLI tool** → weights G3 = 6, G4 = 5, G1 = 4, all others = 2.

| Gate | Weight | Score (0–5) | Weighted (w×s) | Deficit (w×(5−s)) | Reading |
|------|--------|-------------|----------------|-------------------|---------|
| G1 Hook | 4 | 1 | 4 | 16 | "A tool for printing files" is the "A project for X" anti-pattern. |
| G2 Identity/trust | 2 | 1 | 2 | 8 | Name only; no badges, no one-liner. |
| G3 Visual | 6 | 0 | 0 | **30** | A CLI with no demo or wordmark where one is expected. |
| G4 Quickstart | 5 | 1 | 5 | **20** | "Clone and build it" is prose, not a runnable block. |
| G5 Scannability | 2 | 2 | 4 | 6 | Headings exist, but there is nothing under them to find. |
| G6 Completeness | 2 | 1 | 2 | 8 | No config, examples, links, contributing, or license. |
| G7 Credibility | 2 | 1 | 2 | 8 | No example output, no CI, no limitations. |
| G8 Contextual fit | 2 | 1 | 2 | 8 | Misses every CLI convention (flags, real commands, demo). |
| G9 Community/maint | 2 | 0 | 0 | 10 | No contributing, changelog, or support signal. |
| G10 Voice | 2 | 2 | 4 | 6 | Flat and generic, but not slop-filled. |
| **Total** | **29** | — | **25** | **120** | |

Weighted total = 25. Normalized = `25 / 145 × 100` ≈ **17 / 100**.

**What the score points at.** Rank by deficit: G3 (30) → G4 (20) → G1 (16) →
G9 (10) → the cluster at 8 → G5 and G10 at 6. The top three fixes are G3, G4,
and G1 — exactly the three gates the CLI archetype bumped. Add a demo gif or a
figlet wordmark (G3), replace the prose steps with one copy-paste
install-and-run block (G4), and rewrite the first line into a concrete value
proposition (G1). Those three moves recover 66 of the 120 deficit points; the
contextual weighting is what makes the highest-leverage CLI fixes also the top
of the fix list.

*Why: because deficit is weight times gap, a weak gate the archetype cares about always outranks a weak gate it doesn't — the rubric prioritizes the fix list for you instead of leaving every gap looking equal.*

## How the score drives the merge

The same numbers select and assemble the final README. Each gate governs a
specific surface, so a gate winner can be grafted in cleanly:

| Gate | Surface it governs |
|------|--------------------|
| G1 | the first line / tagline |
| G2 | the name block + badge row |
| G3 | the visual block (ascii / diagram / screenshot / gif) |
| G4 | the Quickstart fenced block |
| G5 | the heading tree + TOC |
| G6 | the full set of sections |
| G7 | examples + CI/test signals + Limitations / Non-goals |
| G8 | the archetype's must-have sections |
| G9 | Contributing / CoC / Changelog / Support links |
| G10 | the prose, sentence by sentence |

Merge procedure when running competing candidates (tournament mode, or multiple
generator passes):

1. **Score every candidate** on all ten gates at the archetype's weighting.
2. **Pick the skeleton:** the candidate with the highest weighted total becomes the base draft. Its order, voice, and shape are the spine.
3. **Graft per-gate winners:** for each gate, find the candidate scoring highest on it. If that beats the skeleton by **≥ 2 points on that gate**, swap that candidate's version of the gate's surface (its tagline, its visual, its quickstart block) into the skeleton. Graft the structure, then rewrite the prose in the skeleton's voice — see `generation-and-ranking.md` for keeping one voice across the seams.
4. **Reconcile and verify:** after grafting, re-read for consistency (names, version, and claims still agree) and re-check every factual claim against the repo — a quickstart grafted from another draft may reference a command or flag the skeleton never introduced.
5. **Re-score the merged draft.** It must beat every input candidate on weighted total. If a graft raised one gate but lowered another (a richer visual that hurt G5 scannability, say), revert that single graft and keep the rest.

*Why: the score is the selection function, not a report card — the base draft is chosen by total, each surface is chosen by its gate winner, and the merge is only accepted once a re-score proves it beats every draft it was built from.*

## Scoring discipline

- Never invent a number. Every gate score must trace to something actually on the page.
- Before scoring G2 or G7, confirm that badges, benchmarks, and links **resolve and are real**. CI/version/license badges that become valid on push are allowed; an unverifiable trust claim scores low, never high.
- Any quality claim about the finished README must cite a gate score, not assert one. "Strong quickstart" means G4 = 5 with the block that proves it, or it doesn't get said.
- Score the README as it will render on push, not as it reads in your head — open it as a stranger would, first screen first.
