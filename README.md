```text
██████╗ ███████╗ █████╗ ██████╗ ███╗   ███╗███████╗
██╔══██╗██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔════╝
██████╔╝█████╗  ███████║██║  ██║██╔████╔██║█████╗
██╔══██╗██╔══╝  ██╔══██║██║  ██║██║╚██╔╝██║██╔══╝
██║  ██║███████╗██║  ██║██████╔╝██║ ╚═╝ ██║███████╗
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚══════╝
██████╗  █████╗ ██████╗ ██████╗ ██╗   ██╗
██╔══██╗██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝
██║  ██║███████║██║  ██║██║  ██║ ╚████╔╝
██║  ██║██╔══██║██║  ██║██║  ██║  ╚██╔╝
██████╔╝██║  ██║██████╔╝██████╔╝   ██║
╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═════╝    ╚═╝
```

[![ci](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml/badge.svg)](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![version](https://img.shields.io/badge/version-0.1.0-blue.svg)](CHANGELOG.md)
[![Agent Skill](https://img.shields.io/badge/Claude%20Code-Agent%20Skill-8A2BE2.svg)](https://agentskills.io)

**A [Claude Code](https://claude.ai/code) [Agent Skill](https://agentskills.io) that writes the README your repo deserves — and earns its score instead of asserting it.**

Point readmedaddy at a repo and it detects the project's archetype, pulls the README patterns that win for that type, drafts competing candidates, and ranks them through ten quality gates whose weights shift with the archetype. A CLI gets judged on its demo and quickstart; a library on its API and badges; an agent skill on its trigger and examples. The winner is assembled, the best of the runners-up grafted in, and every factual claim checked against your code before a line ships.

Most README tools fill one template. readmedaddy runs a contest and ships the result with the receipts.

## Table of contents

- [See it work](#see-it-work)
- [How it works](#how-it-works)
- [The rubric: ten gates, weighted by archetype](#the-rubric-ten-gates-weighted-by-archetype)
- [The ten archetypes](#the-ten-archetypes)
- [Install](#install)
- [Keep it current: the auto-update hook](#keep-it-current-the-auto-update-hook)
- [Usage and triggers](#usage-and-triggers)
- [Tournament mode](#tournament-mode)
- [Verification](#verification)
- [What's in the box](#whats-in-the-box)
- [Composition and non-goals](#composition-and-non-goals)
- [Contributing](#contributing)
- [License](#license)

## See it work

An agent skill is best judged by its output, so here is one. readmedaddy looked at a small Rust CLI with a real test suite, CI, and a one-binary install — none of which reached its README. It detected the **CLI** archetype and rewrote the page around the three gates CLI readers care about most: a demo, a 30-second quickstart, and a one-line hook.

<table>
<tr>
<td width="50%" valign="top">

**Before** — inert, ~26 / 100

```text
# stint

A simple command line time
tracker written in Rust.

## Installation

cargo install stint

## Usage

stint start "task name"
stint stop

## License

MIT.
```

</td>
<td width="50%" valign="top">

**After** — readmedaddy, ~95 / 100

```text
███████╗████████╗██╗███╗   ██╗████████╗
██╔════╝╚══██╔══╝██║████╗  ██║╚══██╔══╝
███████╗   ██║   ██║██╔██╗ ██║   ██║
╚════██║   ██║   ██║██║╚██╗██║   ██║
███████║   ██║   ██║██║ ╚████║   ██║
╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝   ╚═╝

[ci] [crates.io] [MIT]

Track where your hours actually go
— without leaving the terminal.

$ brew install acme/tap/stint
$ stint start "first task"
● tracking · first task · 09:14
```

</td>
</tr>
</table>

The lift, scored on CLI weighting (heaviest gates first):

| Gate (CLI weighting) | Before | After |
|----------------------|:------:|:-----:|
| G3 Visual (demo / ASCII) | 0 | 5 |
| G4 Quickstart | 2 | 5 |
| G1 Hook | 1 | 5 |
| **Weighted total (/100)** | **26.2** | **94.5** |

Same repo, same facts — the README just started doing its job. Point readmedaddy at a *library* instead and the banner disappears, because a library sells itself with a typed code block, not ASCII, and the weight moves to API usage, badges, and completeness:

| | CLI repo (`stint`) | Library repo (`fetchet`) |
|---|---|---|
| Heaviest gates | G3 demo · G4 quickstart · G1 hook | G4 API usage · G2 badges · G6 completeness |
| What leads the first screen | ASCII wordmark + terminal demo | typed code hero + badge row, **no banner** |
| Scored lift | 26.2 → 94.5 | 28.3 → 94.5 |

Same ten gates, different weights — that is the whole idea. Both walkthroughs are worked end to end, with full scorecards, in [`examples/`](examples/). They are deliberately illustrative: `stint` and `fetchet` are invented repos, so the numbers show the *shape* of the upgrade, not a benchmark.

## How it works

Five steps, in order. The fourth is the differentiator.

```text
 repo
  │
  ▼
 ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
 │ detect  │  │  pull   │  │generate │  │  rank   │  │assemble │
 │   the   │─▶│ winning │─▶│candidate│─▶│ through │─▶│ winner  │
 │archetype│  │patterns │  │sections │  │10 gates │  │+ verify │
 └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘
```

1. **Detect the archetype first.** Read the languages, entrypoints, and manifests (`package.json` bin vs main, `pyproject.toml`, `Cargo.toml`, `go.mod`, `SKILL.md`) and resolve the repo to exactly one of ten archetypes. The archetype sets the gate weights and the visual the README should lead with. When the signals genuinely tie, it states the assumption in one line and proceeds.
2. **Pull the winning pattern set.** Load that archetype's must-have sections, its right visual, its gate weighting, and the exemplars to adapt from.
3. **Generate competing candidates.** Draft two to three genuinely different candidates per key section — or, for high-stakes work, several whole-README drafts in distinct styles.
4. **Rank through the ten gates.** Score every candidate 0–5 on each gate, apply the archetype's weights, and normalize to `/100`. The score is the selection function, not a report card.
5. **Assemble, verify, output.** Stitch the winner, graft the per-gate winners from the runners-up, then check every claim against the repo. No invented benchmarks, no fake stars, no badge for a thing that does not exist.

The full method lives in [`SKILL.md`](skills/readmedaddy/SKILL.md) and [`references/generation-and-ranking.md`](skills/readmedaddy/references/generation-and-ranking.md).

## The rubric: ten gates, weighted by archetype

This is the core IP. Every candidate — a whole draft, a competing tournament draft, or a single section — is scored 0–5 against a concrete anchor on each gate.

| Gate | What it measures |
|------|------------------|
| **G1 Hook** | first screen conveys what it is and why you'd care, in one line |
| **G2 Identity / trust** | name, one-liner, and real badges — never a fabricated count |
| **G3 Visual** | a wordmark, diagram, screenshot, or demo that is apt and earns its space |
| **G4 Quickstart** | install + smallest real usage in under 30s, copy-paste correct |
| **G5 Scannability** | heading hierarchy, short paragraphs, tables, a TOC once long |
| **G6 Completeness** | usage, config, examples, links, contributing, license — without bloat |
| **G7 Credibility** | real examples, tests/CI signals, honest limitations and non-goals |
| **G8 Contextual fit** | follows the conventions of its archetype |
| **G9 Community / maint** | contributing, code of conduct, changelog, support/roadmap |
| **G10 Voice** | distinct, confident, free of AI-slop |

The weighting is what makes the score contextual. Every gate starts at a base weight of 2. Each archetype bumps its three heaviest gates by +4, +3, and +2 — the bumps always sum to +9, so every archetype's weights total 29 and the maximum weighted score is always `29 × 5 = 145`. The normalized total is `round(Σ(weightᵢ × scoreᵢ) / 145 × 100)`.

The same numbers drive the merge. Each gate's **deficit** (`weightᵢ × (5 − scoreᵢ)`) is how many normalized points that gate leaves on the table, so the fix list ranks itself, highest-leverage first. A weak gate the archetype cares about always outranks a weak gate it doesn't.

readmedaddy itself is the **agent skill / plugin** archetype, so this very README was scored on the row that bumps the hook, the examples, and contextual fit:

| Gate | G1 | G2 | G3 | G4 | G5 | G6 | G7 | G8 | G9 | G10 |
|------|----|----|----|----|----|----|----|----|----|-----|
| Weight | **6** | 2 | 2 | **5** | 2 | 2 | 2 | **4** | 2 | 2 |

The anchors, the per-archetype weight table, the merge procedure, and a worked scorecard are in [`references/multi-gate-rubric.md`](skills/readmedaddy/references/multi-gate-rubric.md).

## The ten archetypes

> A good README for a CLI is a bad README for a library. readmedaddy scores each one against *its own* archetype, not a generic checklist.

A README is only good relative to what the project is, so readmedaddy classifies the repo first, then loads that archetype's heaviest gates and its right visual.

| Archetype | Heaviest gates | The right visual |
|-----------|----------------|------------------|
| CLI tool | G3 demo · G4 quickstart · G1 hook | ASCII wordmark and/or a demo gif |
| Library | G4 API usage · G2 badges · G6 completeness | a tight code block; usually no banner |
| Framework | G4 · G2 · G6 (+ G1, G3) | logo + architecture diagram |
| App / SaaS | G1 hook · G3 screenshot · G9 community | a product screenshot or hero demo |
| Infra / devops | G4 quickstart · G7 credibility · G6 | an architecture / data-flow diagram |
| Data / ML | G1 hook · G7 results · G6 citations | a benchmark plot or table |
| **Agent skill / plugin** | **G1 hook · G4 examples · G8 fit** | a small wordmark, concept diagram, or before/after |
| Research | G1 finding · G7 reproducibility · G6 | the key results figure |
| Monorepo | G5 scannability · G6 · navigation | a packages table + dependency diagram |
| Internal tool | G5 · G6 · navigation (+ G4, G7) | an architecture + setup-flow diagram |

Detection signals, must-have sections, tie-breakers, and exemplars for each live in [`references/archetypes.md`](skills/readmedaddy/references/archetypes.md). The README canon they draw on — Art-of-README, Standard-Readme, makeareadme, Best-README-Template, awesome-readme — is in [`references/famous-readme-patterns.md`](skills/readmedaddy/references/famous-readme-patterns.md).

## Install

readmedaddy is a self-contained skill directory with no runtime dependencies. One step installs the skill and wires the [auto-update hook](#keep-it-current-the-auto-update-hook).

```sh
git clone https://github.com/Systemartis/readmedaddy.git
cd readmedaddy && ./install.sh   # copies the skill into ~/.claude/skills, verifies it, registers the hook
```

`./install.sh` copies the skill, self-verifies it landed, then registers the Stop hook user-global so your READMEs stay watched across every project. Skip the hook with `./install.sh --no-hook`; remove it later with `python3 scripts/install-hook.py --uninstall`. [`install.sh`](install.sh) makes no network calls, touches nothing outside the destination, and is safe to re-run. Install elsewhere with `DEST=/path ./install.sh`, or copy `skills/readmedaddy/` into any agent's skills directory by hand.

## Keep it current: the auto-update hook

A README rots the moment the code moves and nobody notices. The optional Stop hook notices. It watches the signal files a README is built from — manifests, entrypoints, CLI, CI workflows, install scripts — and when they change while the README does not, it prompts you to refresh the page **through the readmedaddy skill, in the same session**: re-detect the archetype, re-rank, then finish. It detects drift and asks; it does not silently rewrite your README or run anything behind your back.

It is deliberately quiet. No git repo, no README, or a config that turns it off, and it does nothing — and every path exits clean, so it can never break a session. Three modes pick how insistent the nudge is:

| Mode | Behavior |
|------|----------|
| **auto** *(default)* | Blocks the Stop once per distinct drift and asks the agent to refresh — one clear nudge, then silence until something new drifts. |
| **notify** | Prints the same message to stderr and gets out of the way — awareness without a handoff. |
| **enforce** | Re-prompts on every Stop until the README actually changes — for projects with a hard "README tracks code" rule. |

Configure it per project with a `.readmedaddy.json` (mode, the watched README, the watch list), or force a mode for one session with `README_DADDY_HOOK=notify|enforce|off`. Disable it entirely with `README_DADDY_HOOK=off`. Full behavior, the drift logic, and the loop-safety guards are in [`references/auto-update-hook.md`](skills/readmedaddy/references/auto-update-hook.md).

## Usage and triggers

Once installed, point Claude Code at any repository and ask for a README, or let the skill fire on its own when it sees the symptoms below.

```text
"readmedaddy: write a README for this repo"
"improve the README — it buries what this thing does"
"readme review"
```

The skill triggers on its frontmatter `description`, which states the symptoms, not the workflow:

> Use when writing or improving a README — the README is thin, stub, outdated, a wall of text, unscannable, or missing; a new or empty repo needs a front page or landing doc; the existing README has no quickstart, no install, no badges, no examples, broken or stale instructions, or reads like AI slop; someone says "write me a README", "make this README better", "the readme sucks", "polish the readme", "good first impression", "readme.md", "project front page", "documentation landing". Works for any repo: CLI, library/package, framework, app/SaaS, infra, data/ML, Claude Code skill or agent tool, research, or monorepo. Yields to user and project instructions; never invents facts about the code.

You get a complete `README.md`, fit to the repo's detected archetype, with every factual claim — install commands, file paths, version, license, code blocks — checked against the repo. After the README, readmedaddy offers the strong runner-up elements as labelled alternatives ("shorter hook from the minimal draft", "alternate banner from the diagram-led draft") so you can swap a section without re-running anything.

## Tournament mode

Most requests are well served by a single contextual pass with competing per-section candidates. When the README is a front page that materially moves adoption — a repo about to be open-sourced, a flagship project, or an explicit ask for "the best possible README" — readmedaddy escalates to a full tournament: **five to seven whole-README drafts** in deliberately distinct styles (banner/CLI, diagram-led, story-hook, reference-grade, show-don't-tell, minimal-elegant), scored by a **three-judge panel**.

| Judge | Reads for | Decides |
|-------|-----------|---------|
| **First-impression** | the first screen, five seconds, cold | G1 hook, G2 trust |
| **Craft** | the editor / engineer | G4 quickstart, G6/G7 substance, G10 voice |
| **ASCII / design** | the visual critic | G3 visual, G5 scannability |

The top-scoring draft becomes the skeleton; each gate's winner is grafted in where it beats the skeleton by two points or more, then rewritten in one voice; the merge is kept only once a re-score proves it beats every draft it was built from. Escalating by default would be the same over-engineering the voice gate penalizes in prose, so everything lighter takes the fast path.

This README was produced by exactly that tournament — seven drafts (six deliberately styled plus a single-pass control), the three-judge panel, a grafted winner — then held to the same agent-skill rubric every generated README is scored against. The drafts and scorecard are preserved in [`docs/`](docs/).

## Verification

readmedaddy ships an eval harness and a CI pipeline instead of adjectives.

**The eval** ([`skills/readmedaddy/eval/`](skills/readmedaddy/eval/)) proves two things RED→GREEN, against thresholds **pre-registered before any run** in [`PREREGISTRATION.md`](skills/readmedaddy/eval/PREREGISTRATION.md): that readmedaddy detects the right archetype, and that its README beats a deliberately thin baseline through the gates, scored by a [blind judge](skills/readmedaddy/eval/judge-prompt.md) who is never told which README is which. Four fixtures keep the test honest, because language alone never gives the archetype away:

| Fixture | Archetype | What it is |
|---------|-----------|------------|
| `cli-fixture/` | CLI | a Node CLI with a `bin` entry and `--help` |
| `lib-fixture/` | library | a Python package exporting a public function |
| `skill-fixture/` | agent skill | a `SKILL.md` with trigger frontmatter |
| `research-fixture/` | research | a notebook + `CITATION.cff` + a dataset note |

The bar is conjunctive and per-fixture: **4/4** correct archetype detection, at least **+20** weighted points of lift on *every* fixture, and an absolute floor of **70/100** — no strong average can hide a weak fixture. A stdlib-only [`score.py`](skills/readmedaddy/eval/score.py) recomputes the weighted total from the per-gate scores, so a judge's arithmetic can be checked independently. A null or reversed result is reported as-is; the eval can say no.

**It said yes.** The first run (2026-07-02) cleared every pre-registered threshold: **4/4 detection** with all must-detect signals covered, per-fixture lift **+58.6 to +79.3** against the +20 bar, absolute scores **71.7–89.0** against the 70 floor, mean lift **+65.7**. Blind judging: 24 independent passes (3 per README) over anonymized files, medians recomputed by `score.py`. The full protocol, raw judge scores, and the generated READMEs are in [`eval/results/2026-07-02/`](skills/readmedaddy/eval/results/2026-07-02/report.md) — including the acknowledged limits (same-family self-judging; four of ten archetypes exercised).

**CI** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs four jobs on every push and pull request:

- `validate` — [`scripts/validate-skill.py`](scripts/validate-skill.py) (standard library only) checks SKILL.md frontmatter and the description budget, that every relative link **and** every backtick `references/*.md` pointer in `SKILL.md` and `references/` resolves, version consistency (SKILL.md `metadata.version` matches the top `CHANGELOG.md` entry), the clean-for-publish forbidden-reference guard, that all required reference files exist, that the rubric defines every gate G1–G10, and that every archetype named in the rubric appears in the catalog.
- `shell` — `shellcheck`, a POSIX syntax check, and the hook behavior test on `install.sh` and `hooks/readme-drift.sh`.
- `python` — byte-compiles `scripts/install-hook.py` and `eval/score.py`, then runs both self-tests (the scorer's self-test asserts its weights match the rubric's sum-29 vectors).
- `markdown` — `markdownlint-cli2` across the docs.

## What's in the box

| Path | What it is |
|------|------------|
| [`skills/readmedaddy/SKILL.md`](skills/readmedaddy/SKILL.md) | the lean skill: triggers + the detect→rank method |
| [`references/multi-gate-rubric.md`](skills/readmedaddy/references/multi-gate-rubric.md) | the ten gates, 0–5 anchors, per-archetype weights, the merge procedure |
| [`references/archetypes.md`](skills/readmedaddy/references/archetypes.md) | the ten archetypes: detection, sections, visuals, exemplars |
| [`references/generation-and-ranking.md`](skills/readmedaddy/references/generation-and-ranking.md) | the generate→rank workflow and the tournament |
| [`references/famous-readme-patterns.md`](skills/readmedaddy/references/famous-readme-patterns.md) | the README canon and exemplars by archetype |
| [`references/auto-update-hook.md`](skills/readmedaddy/references/auto-update-hook.md) | the auto-update hook: drift logic, modes, config, loop safety |
| [`hooks/readme-drift.sh`](skills/readmedaddy/hooks/readme-drift.sh) | the Stop hook that flags a README drifting behind its code |
| [`scripts/install-hook.py`](scripts/install-hook.py) | idempotent installer that wires the Stop hook into `settings.json` |
| [`assets/badges.md`](skills/readmedaddy/assets/badges.md) | copy-paste badge recipes, with the rule for what's allowed |
| [`eval/`](skills/readmedaddy/eval/) | fixtures, the blind judge, `score.py`, the pre-registration |
| [`examples/`](examples/) | worked before/after upgrades (CLI, library) |
| [`docs/`](docs/) | the tournament scorecard and every styled draft |

## Composition and non-goals

readmedaddy decides README content and shape. It yields, highest first, to: host safety policy; an explicit live user instruction; standing project docs (`CLAUDE.md` / `AGENTS.md`) and any existing style guide; then your engineering-discipline skills. When a project already pins a README convention, readmedaddy follows it and ranks *within* it rather than overriding it. It composes with project-finalization pipelines as their README stage, without depending on any specific sibling skill.

What it is **not**:

- **Not a docs-site generator.** It produces one front-page `README.md`, not a documentation website, an API-doc build, or a wiki.
- **A skill, not a binary.** It runs inside an agent that can read the repo to verify claims; there is no standalone CLI to install on its own.
- **It invents nothing.** No fabricated stars, downloads, benchmarks, or testimonials, and no badge for a thing that does not exist. CI, license, version, and "Agent Skill" badges are allowed because they become valid on push. Any quality claim about a generated README traces to a rubric score, or it doesn't get made.

## Contributing

Issues and pull requests are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) and the one rule it enforces: no skill behavior ships without a failing test or eval first. Run `python3 scripts/validate-skill.py` and `shellcheck install.sh` before opening a PR. There are issue templates for a [bug report](.github/ISSUE_TEMPLATE/bug_report.md) and a [README request](.github/ISSUE_TEMPLATE/readme_request.md); report vulnerabilities via [SECURITY.md](SECURITY.md); the [Code of Conduct](CODE_OF_CONDUCT.md) applies; and notable changes are tracked in [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Systemartis. See [LICENSE](LICENSE).
