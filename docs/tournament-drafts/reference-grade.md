# readmedaddy

**A Claude Code Agent Skill that writes the README your repo deserves — and earns the score instead of asserting it.**

[![ci](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml/badge.svg)](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![version](https://img.shields.io/badge/version-0.1.0-blue.svg)](CHANGELOG.md)
[![Agent Skill](https://img.shields.io/badge/Claude%20Code-Agent%20Skill-8A2BE2.svg)](https://agentskills.io)
[![readme style: standard](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg)](https://github.com/RichardLitt/standard-readme)

readmedaddy detects your project's **archetype**, pulls the README patterns that win for that type, drafts competing candidates, and ranks them through ten quality gates whose **weights shift with the archetype**. A CLI gets judged on its demo and quickstart; a library on its API and badges; an agent skill on its trigger and examples. The winner is assembled, the best of the runners-up grafted in, and every factual claim verified against the repo before output.

```text
  repo
   │
   ▼  ① detect the archetype       — CLI? library? agent skill? app?
   │
   ▼  ② pull the winning patterns  — must-have sections + apt visual
   │
   ▼  ③ generate candidates        — key sections, or N whole drafts
   │
   ▼  ④ rank through 10 gates      — weights shift with the archetype
   │
   ▼  ⑤ assemble · graft · verify  — claims checked against the repo
   │
   ▼
  a README that earns its score, instead of asserting it
```

## Table of Contents

- [Background](#background)
  - [The ten gates](#the-ten-gates)
  - [The ten archetypes](#the-ten-archetypes)
  - [Tournament mode](#tournament-mode)
- [Install](#install)
- [Usage](#usage)
  - [When it triggers](#when-it-triggers)
  - [What you get](#what-you-get)
  - [Standard pass vs. tournament](#standard-pass-vs-tournament)
- [Examples](#examples)
- [Verification](#verification)
- [Configuration](#configuration)
- [Non-goals and precedence](#non-goals-and-precedence)
- [What's inside](#whats-inside)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

## Background

A README is only "good" relative to what the project *is*. A perfect CLI README makes a poor library README. Generic templates ignore this, so they produce front pages that are complete and forgettable. readmedaddy starts from the opposite move: classify the repo first, then judge it by the standard that kind of project is actually held to.

The differentiator is a **contextual multi-gate ranking system**. Every candidate — a whole draft, a competing tournament draft, or a single section — is scored 0–5 on ten gates against concrete anchors. Each gate carries a weight that depends on the archetype, so the same gate matters more for one kind of project than another. The score is not a grade filed away. It is the **selection function**: the highest weighted total becomes the skeleton, the per-gate winners get grafted in, and each gate's *deficit* (`weight × (5 − score)`) ranks the fix list so the highest-leverage fixes surface first.

### The ten gates

Each gate has a 0-anchor (the anti-pattern it names) and a 5-anchor. The weight column shows readmedaddy's own archetype — **agent skill / plugin** — which bumps the hook, the examples, and the contextual fit.

| Gate | What it measures | Weight (agent skill) |
|------|------------------|:--:|
| G1 Hook | first screen conveys what it is and why you'd care, in one line | **6** |
| G2 Identity / trust | name, one-liner, real badges, honest social proof | 2 |
| G3 Visual | a wordmark, diagram, screenshot, or demo that is apt and earns its space | 2 |
| G4 Quickstart | install + smallest real usage in under 30s, copy-pasteable, correct | **5** |
| G5 Scannability | heading hierarchy, short paragraphs, tables, a TOC once long | 2 |
| G6 Completeness | usage, config, examples, links, contributing, license — no bloat | 2 |
| G7 Credibility | real examples, tests/CI signals, honest limitations and non-goals | 2 |
| G8 Contextual fit | follows the conventions of its archetype | **4** |
| G9 Community / maint | contributing, code of conduct, changelog, support/roadmap | 2 |
| G10 Voice | distinct, confident, free of AI-slop | 2 |

Every archetype's weights sum to 29, so the maximum weighted score is always `29 × 5 = 145` and the normalized total is `Σ(weightᵢ × scoreᵢ) / 145 × 100`. The same divisor every time means scores compare across runs. Two rules hold on every gate: never invent a number (each score traces to something on the page), and verify before you credit (a badge that 404s or a benchmark with no source scores 0, not 5).

### The ten archetypes

Detection runs top to bottom; the most specific structural signal wins. Each archetype loads its own must-have sections, the right visual, and the gate weighting.

| Archetype | Heaviest gates | The right visual |
|-----------|----------------|------------------|
| CLI tool | G3 demo + G4 quickstart + G1 hook | ASCII wordmark and/or a demo gif |
| Library | G4 API usage + G2 badges + G6 completeness | a tight code block (often no visual) |
| Framework | G4 + G2 + G6, leaning on G1 + G3 | logo + architecture diagram |
| App / SaaS | G1 hook + G3 screenshot + G9 community | a product screenshot or hero demo |
| Infra / devops | G4 quickstart + G7 credibility + G6 | an architecture / data-flow diagram |
| Data / ML | G1 hook + G7 results + G6 citations | a benchmark plot or table |
| **Agent skill / plugin** | **G1 + G4 examples + G8 fit** | a wordmark, concept diagram, or before/after |
| Research | G1 finding + G7 reproducibility + G6 | the key results figure |
| Monorepo | G5 scannability + G6 + navigation | a packages table + dependency diagram |
| Internal tool | G5 + G6 + navigation, plus G4 + G7 | an architecture + setup-flow diagram |

readmedaddy itself is the **agent skill / plugin** row — the one this README is scored on.

### Tournament mode

For high-stakes work — a repo about to be open-sourced, a flagship front page, or an explicit ask for "the best possible README" — readmedaddy escalates from per-section candidates to a full tournament: **five to six whole-README drafts** in deliberately distinct styles (banner/CLI, diagram-led, story-hook, reference-grade, show-don't-tell, minimal-elegant), scored by a **three-judge panel**.

| Judge | Reads as | Authoritative on |
|-------|----------|------------------|
| Craft judge | the editor/engineer | does it run, is it complete, is it honest, does it read clean (G4, G6, G7, G8, G9, G10) |
| First-impression judge | the cold visitor, first screen only | would a stranger keep reading and trust it (G1, G2) |
| ASCII / design judge | the visual critic | does the banner/diagram/screenshot earn its space and render at width (G3, with G5) |

The top weighted total becomes the skeleton; a non-base draft's surface is grafted only where it beats the skeleton by ≥ 2 points on a gate, then rewritten in one voice. The merged draft must out-score every draft it was built from, or the graft is reverted. Everything lighter is well served by the standard single pass, because escalating by default is the same over-engineering the voice gate penalizes in prose.

## Install

readmedaddy is a self-contained skill directory with no runtime dependencies. Install it into your Claude Code skills folder and verify in one step.

```sh
# 1. Get the skill
git clone https://github.com/Systemartis/readmedaddy.git
cd readmedaddy

# 2. Install into ~/.claude/skills/readmedaddy (idempotent, makes no network calls)
./install.sh

# 3. Confirm it landed
ls ~/.claude/skills/readmedaddy/SKILL.md
```

`install.sh` copies `skills/readmedaddy/` into your skills directory, then verifies that `SKILL.md` arrived with the right frontmatter name before reporting success. Re-running is safe.

## Usage

Once installed, the skill is available to Claude Code. Point it at any repository and ask for a README, or let it trigger on its own when it sees the symptoms below.

```text
"readmedaddy: write a README for this repo"
"improve the README — it buries what this thing does"
"readme review"
```

### When it triggers

The skill fires on its frontmatter `description`, which states the symptoms — not the workflow:

> Use when writing a README from scratch for a new repo, or when an existing README is thin, outdated, unscannable, buries the value proposition, has no quickstart, or doesn't match its project type; when a project needs a strong front page before open-sourcing; or when asked to "improve the README", "write a README", "make a good README", or "readme review". Not a docs-site generator; yields to existing project style guides.

### What you get

A complete `README.md`, fit to the repo's detected archetype, with every factual claim — install commands, file paths, version, license, code blocks — checked against the repo. After the README, readmedaddy offers the strong runner-up elements as labelled alternatives ("shorter hook from the minimal draft", "alternate banner from the diagram-led draft") so you can swap a section without re-running anything.

### Standard pass vs. tournament

| | Standard generate → rank | High-stakes tournament |
|---|---|---|
| Generates | 2–3 variants per key section | 5–6 whole-README drafts |
| Ranks with | the contextual gates, self-scored | a three-judge panel |
| Best for | almost every request | front pages that materially affect adoption |
| Cost | fast | more compute, reserved on purpose |

## Examples

Two worked before/after transformations ship in [`examples/`](examples/), each showing a thin baseline, the archetype detection, the per-gate scorecard, and the upgraded README:

- [`examples/before-after-cli.md`](examples/before-after-cli.md) — a thin CLI README rebuilt around a demo, a copy-paste quickstart, and a concrete hook (the gates a CLI bumps).
- [`examples/before-after-library.md`](examples/before-after-library.md) — a bare package README rebuilt around an import-and-use block, badges, and an API section (the gates a library bumps).

## Verification

Quality claims are tested, not asserted. The skill ships an eval harness and a CI pipeline that run on every push.

**Eval harness** ([`skills/readmedaddy/eval/`](skills/readmedaddy/eval/)) proves two things with a RED→GREEN methodology and a pre-registered hypothesis fixed before any result was collected:

- **Detection** — readmedaddy classifies a repo into the right archetype and names the signals it used.
- **Lift** — the README it produces beats a deliberately thin baseline through the contextual gates, scored by a **blind judge** ([`judge-prompt.md`](skills/readmedaddy/eval/judge-prompt.md)) that is never told which README is which.

Four minimal-but-realistic fixtures keep the test honest, because language alone never gives the archetype away:

| Fixture | Archetype | What it is |
|---------|-----------|------------|
| `cli-fixture/` | CLI | a Node CLI with a `bin` entry and `--help` |
| `lib-fixture/` | library | a Python package exporting a public function |
| `skill-fixture/` | agent skill | a `SKILL.md` with trigger frontmatter |
| `research-fixture/` | research | a notebook + `CITATION.cff` + a dataset note |

A stdlib-only [`score.py`](skills/readmedaddy/eval/score.py) recomputes the weighted `/100` from per-gate scores using the same per-archetype weights as the rubric, so a judge's arithmetic can be checked independently. It runs its own self-tests.

**CI** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs three jobs:

- `validate` — [`scripts/validate-skill.py`](scripts/validate-skill.py) checks frontmatter and the description budget, that every relative link in `SKILL.md` and `references/` resolves, version consistency (`SKILL.md` `metadata.version` matches the top `CHANGELOG.md` entry), the clean-for-publish forbidden-reference guard, that all four reference files exist, that the rubric defines every gate G1–G10, and that every archetype named in the rubric appears in the catalog.
- `shell` — `shellcheck` and a POSIX syntax check on `install.sh`.
- `markdown` — `markdownlint-cli2` across the docs.

## Configuration

readmedaddy needs no config to run. Two knobs exist for control:

- **Install destination.** `install.sh` honors a `DEST` override for non-default skills directories:

  ```sh
  DEST=/path/to/skills ./install.sh
  ```

- **Badge recipes.** [`skills/readmedaddy/assets/badges.md`](skills/readmedaddy/assets/badges.md) holds copy-paste badge markdown plus the rule that governs them: a badge is a claim, so ship one only when something true backs it — a CI run, the `LICENSE` file, a real release tag, or the skill's own metadata. Quality lives in the rubric score, never in a badge.

## Non-goals and precedence

readmedaddy is honest about what it does not do:

- **Not a docs-site generator.** It produces one front-page `README.md`, not a multi-page documentation site, an API-doc build, or a wiki.
- **No invented trust.** No fabricated stars, downloads, benchmarks, or testimonials, and no badge for a thing that does not exist. CI, license, version, and "Agent Skill" badges are fine because they become valid on push.
- **It yields rather than overrides.** Precedence, highest first: host safety policy → an explicit live user instruction → standing project docs (`CLAUDE.md` / `AGENTS.md`) and any existing style guide → engineering-discipline skills. When a project already pins a README convention, readmedaddy follows it and ranks within it.

It composes with project-finalization skills — run it as the README stage of a delivery pipeline — without depending on any specific one.

## What's inside

| Path | What it holds |
|------|---------------|
| [`skills/readmedaddy/SKILL.md`](skills/readmedaddy/SKILL.md) | the lean skill: triggers + the five-step method |
| [`references/multi-gate-rubric.md`](skills/readmedaddy/references/multi-gate-rubric.md) | the ten gates, 0–5 anchors, per-archetype weight tables, the merge procedure |
| [`references/archetypes.md`](skills/readmedaddy/references/archetypes.md) | detection signals, must-have sections, the right visual, exemplars |
| [`references/famous-readme-patterns.md`](skills/readmedaddy/references/famous-readme-patterns.md) | the README canon and exemplars by archetype |
| [`references/generation-and-ranking.md`](skills/readmedaddy/references/generation-and-ranking.md) | the generate→rank flow, the tournament, grafting without Frankensteining the voice |
| [`assets/badges.md`](skills/readmedaddy/assets/badges.md) | honest badge recipes |
| [`eval/`](skills/readmedaddy/eval/) | fixtures, the blind judge, `score.py`, the pre-registration |
| [`examples/`](examples/) | before/after READMEs (CLI, library) |
| [`scripts/validate-skill.py`](scripts/validate-skill.py) | the structural validator CI enforces |

This README was itself produced by readmedaddy's tournament workflow — six styled drafts, the three-judge panel, a grafted winner — which is the standard every claim in a generated README is held to.

## Maintainers

Maintained by [Systemartis](https://github.com/Systemartis). Questions, ideas, and "this archetype is wrong" reports are welcome via [issues](https://github.com/Systemartis/readmedaddy/issues).

## Contributing

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) for the dev loop and the rule that no skill behavior ships without a failing test or eval first. By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). Security reports go through [SECURITY.md](SECURITY.md), and notable changes are tracked in [CHANGELOG.md](CHANGELOG.md). There are issue templates for a [bug report](.github/ISSUE_TEMPLATE/bug_report.md) and a [README request](.github/ISSUE_TEMPLATE/readme_request.md).

## License

[MIT](LICENSE) © 2026 Systemartis.
