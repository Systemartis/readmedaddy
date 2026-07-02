# readmedaddy

```
    r e a d m e d a d d y

     repo
      │
      ▼
 ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
 │ detect  │  │  pull   │  │generate │  │  rank   │  │assemble │
 │   the   │─▶│ winning │─▶│candidate│─▶│ through │─▶│ winner  │
 │archetype│  │patterns │  │sections │  │10 gates │  │+ verify │
 └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘
```

*Point readmedaddy at a repo; out comes a README that earns its rubric score
instead of asserting it. The `rank through 10 gates` step is the differentiator:
the gate weights shift with the detected archetype.*

[![ci](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml/badge.svg)](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![version](https://img.shields.io/badge/version-0.1.0-blue.svg)](CHANGELOG.md)
[![Agent Skill](https://img.shields.io/badge/Claude%20Code-Agent%20Skill-8A2BE2.svg)](https://agentskills.io)

**readmedaddy writes the README your repo deserves, and scores every draft so the
winner is chosen, not guessed.** It is a [Claude Code](https://claude.ai/code)
[Agent Skill](https://agentskills.io). Point it at a repo and it detects what kind
of project the repo is, pulls the README patterns that win for that project type,
drafts competing candidates, and ranks them through ten quality gates weighted for
that archetype. The winner is assembled, the best of the runners-up grafted in,
and every factual claim verified against the repo before output.

Most README helpers fill one template. readmedaddy runs a contest and ships the
result with the receipts.

## Table of Contents

- [How it works](#how-it-works)
- [The contextual multi-gate rubric](#the-contextual-multi-gate-rubric)
- [The ten archetypes](#the-ten-archetypes)
- [Install](#install)
- [Usage](#usage)
- [Examples](#examples)
- [Tournament mode](#tournament-mode)
- [Non-goals](#non-goals)
- [Composition and precedence](#composition-and-precedence)
- [How it's verified](#how-its-verified)
- [Project layout](#project-layout)
- [Contributing](#contributing)
- [License](#license)

## How it works

The pipeline in the banner is the whole method. Five steps, in order:

1. **Detect the archetype first.** Read the languages, entrypoints, and manifests
   (`package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` / `SKILL.md`) and
   resolve the repo to exactly one of ten archetypes. The archetype sets the gate
   weights and the visual the README should lead with.
2. **Pull the winning pattern set.** Load that archetype's must-have sections, its
   right visual, its gate weighting, and its exemplars.
3. **Generate candidate content.** Draft two to three genuinely different
   candidates per key section (hook, quickstart, visual, usage). For high-stakes
   work, draft whole competing READMEs instead.
4. **Rank through the ten gates.** Score every candidate 0–5 on each gate, apply
   the archetype's weights, and normalize to `/100`. The score is the selection
   function, not a report card.
5. **Assemble, verify, output.** Build the winner, graft the per-gate winners from
   the runners-up, then check every claim against the repo. No invented
   benchmarks, no fake stars, no badge for a thing that does not exist.

The full method lives in
[`SKILL.md`](skills/readmedaddy/SKILL.md) and
[`references/generation-and-ranking.md`](skills/readmedaddy/references/generation-and-ranking.md).

## The contextual multi-gate rubric

Ten gates, each scored 0–5 against a concrete anchor. This is the core IP.

| Gate | Measures |
|------|----------|
| **G1 Hook** | first screen says what it is and why you'd care, in one line |
| **G2 Identity / trust** | name, one-liner, and real badges (CI, version, license) |
| **G3 Visual** | an apt wordmark, diagram, screenshot, or demo that earns its space |
| **G4 Quickstart** | install + smallest real usage in under 30s, copy-paste correct |
| **G5 Scannability** | heading hierarchy, short paragraphs, tables, a TOC when long |
| **G6 Completeness** | usage, config, examples, links, contributing, license, no bloat |
| **G7 Credibility** | real examples, CI/test signals, honest limits and non-goals |
| **G8 Contextual fit** | follows the conventions of its archetype |
| **G9 Community / maint** | contributing, code of conduct, changelog, support/roadmap |
| **G10 Voice** | distinct, confident, free of AI-slop |

The weights are what make the score contextual. Every gate starts at a base
weight of 2. Each archetype bumps its three most important gates by +4, +3, and
+2, so every archetype's weights total 29 and the maximum weighted score is always
`29 × 5 = 145`. The normalized total is `round(Σ(weightᵢ × scoreᵢ) / 145 × 100)`.

The same numbers drive the merge. Each gate's **deficit** (`weightᵢ × (5 −
scoreᵢ)`) is how many normalized points that gate leaves on the table, so the fix
list ranks itself, highest-leverage first. A weak gate the archetype cares about
always outranks a weak gate it doesn't.

readmedaddy's own archetype is **agent skill / plugin**, so this very README is
scored on the row that bumps the hook, the examples, and archetype fit:

| Gate | G1 | G2 | G3 | G4 | G5 | G6 | G7 | G8 | G9 | G10 |
|------|----|----|----|----|----|----|----|----|----|-----|
| Weight | **6** | 2 | 2 | **5** | 2 | 2 | 2 | **4** | 2 | 2 |

The anchors, the per-archetype weight table, and a worked scorecard are in
[`references/multi-gate-rubric.md`](skills/readmedaddy/references/multi-gate-rubric.md).

## The ten archetypes

A README is only good relative to what the project is. A perfect CLI README makes
a poor library README. readmedaddy classifies the repo first, then loads that
archetype's heaviest gates and its right visual.

| Archetype | Heaviest gates | The right visual |
|-----------|----------------|------------------|
| CLI tool | G3, G4, G1 | ASCII wordmark and/or a demo gif |
| Library | G4, G2, G6 | a tight code block; usually no banner |
| Framework | G4, G2, G6 (+ G1, G3) | logo + architecture / lifecycle diagram |
| App / SaaS | G1, G3, G9 | product screenshot or hero demo |
| Infra / devops | G4, G7, G6 | architecture diagram + compatibility matrix |
| Data / ML | G1, G7, G6 | benchmark plot/table + sample outputs |
| **Agent skill / plugin** | **G1, triggers, G4, G8** | small wordmark or concept diagram; often a before/after block |
| Research | G1, G7, G6 | key results figure or method diagram |
| Monorepo | G5, G6, G1 | packages table + dependency diagram |
| Internal tool | G5, G6, G4/G7 | architecture + setup-flow diagram |

Detection signals, must-have sections, tie-breakers, and exemplars for each live
in [`references/archetypes.md`](skills/readmedaddy/references/archetypes.md). The
README canon they draw on (Art-of-README, Standard-Readme, makeareadme,
Best-README-Template, awesome-readme) is in
[`references/famous-readme-patterns.md`](skills/readmedaddy/references/famous-readme-patterns.md).

## Install

```sh
git clone https://github.com/Systemartis/readmedaddy
cd readmedaddy && ./install.sh   # copies the skill into ~/.claude/skills, then verifies it landed
```

[`install.sh`](install.sh) makes no network calls, touches nothing outside the
destination, and is safe to re-run. Install elsewhere with `DEST=/path
./install.sh`, or copy `skills/readmedaddy/` into any agent's skills directory by
hand.

## Usage

In Claude Code, invoke it by name, **readmedaddy**, or just describe the symptom
and let it fire on its description:

- "improve the README"
- "write a README for this repo"
- "this README is thin and buries the value prop, fix it"
- "make a good README before I open-source this"
- "readme review"

readmedaddy triggers when a repo needs a README from scratch, or when an existing
one is thin, outdated, unscannable, missing a quickstart, or mismatched to its
project type. It analyzes the repo it is run in, so no arguments are required.

## Examples

Two worked before/after upgrades, each showing the thin README, the upgraded one,
and how the gates scored the lift. Both projects are invented and generic; the
point is the shape of the upgrade and the scoring, not the exact words.

- [A CLI tool](examples/before-after-cli.md) — detected as **CLI**, so the upgrade
  leads with hook, demo, and a 30-second quickstart (G1, G3, G4).
- [A library](examples/before-after-library.md) — detected as **library**, so the
  upgrade leads with API usage, trust badges, and completeness (G4, G2, G6).

## Tournament mode

For a high-stakes front page, the project about to be open-sourced, the flagship
repo, an explicit "make this the best possible README", readmedaddy escalates from
per-section candidates to a full tournament: five to six whole-README drafts in
deliberately different styles (banner/CLI, diagram-led, story-hook,
reference-grade, show-don't-tell, minimal-elegant), judged by a three-judge panel
(a craft judge, a first-impression judge, and an ASCII/design judge). The
top-scoring draft becomes the skeleton; each gate's winner is grafted in where it
beats the skeleton by two points or more; the merge is accepted only once a
re-score proves it beats every draft it was built from.

This very README was produced by that tournament, then held to the same
agent-skill rubric every generated README is scored against. Escalation is
deliberate, not the default, over-engineering the process is the same waste the
voice gate penalizes in prose.

## Non-goals

- **Not a docs-site generator.** readmedaddy produces one excellent README, not a
  documentation website.
- **It yields to your style guide.** When a project already pins a README
  convention, readmedaddy follows it and ranks within it.
- **It invents nothing.** No fabricated benchmarks, star counts, download numbers,
  or testimonials, and no badge for a thing that does not exist. Any quality claim
  about a generated README traces to a rubric score or it isn't made.
- **It does not replace engineering discipline.** It composes with delivery and
  code-quality skills rather than standing in for them.

## Composition and precedence

readmedaddy yields, highest first, to: (1) host safety policy; (2) an explicit
live user instruction; (3) standing project docs (`CLAUDE.md` / `AGENTS.md`) and
any existing style guide; (4) engineering-discipline skills. It composes with
project-finalization skills, run it as the README stage of a delivery pipeline,
without naming or depending on any specific sibling skill.

## How it's verified

The skill is tested, not asserted.

- **CI** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs three jobs
  on every push and pull request: structural validation, `shellcheck` plus a POSIX
  syntax check on `install.sh`, and `markdownlint`.
- **The validator**
  ([`scripts/validate-skill.py`](scripts/validate-skill.py), standard library
  only) checks SKILL.md frontmatter and description budget, relative-link
  integrity, version consistency (SKILL.md `metadata.version` matches the top
  CHANGELOG entry), that every gate `G1`–`G10` is defined, and the clean-for-publish
  guard that keeps shipped files free of personal and internal references.
- **The eval harness**
  ([`skills/readmedaddy/eval/`](skills/readmedaddy/eval/README.md)) proves two
  things RED→GREEN: that readmedaddy detects the right archetype, and that its
  README beats a thin baseline through the gates, scored by a blind judge that does
  not know which README is which. The hypothesis, margins, and falsifiers are fixed
  in advance in
  [`PREREGISTRATION.md`](skills/readmedaddy/eval/PREREGISTRATION.md) and were not
  edited to fit a result.

## Project layout

| Path | What it is |
|------|------------|
| [`skills/readmedaddy/SKILL.md`](skills/readmedaddy/SKILL.md) | the lean skill: triggers + the five-step method |
| [`references/multi-gate-rubric.md`](skills/readmedaddy/references/multi-gate-rubric.md) | the ten gates, anchors, and per-archetype weights |
| [`references/archetypes.md`](skills/readmedaddy/references/archetypes.md) | the ten archetypes: detection, sections, visuals, exemplars |
| [`references/generation-and-ranking.md`](skills/readmedaddy/references/generation-and-ranking.md) | the generate→rank workflow and the judge panel |
| [`references/famous-readme-patterns.md`](skills/readmedaddy/references/famous-readme-patterns.md) | the README canon and exemplars by archetype |
| [`assets/badges.md`](skills/readmedaddy/assets/badges.md) | copy-paste badge recipes, with the rules for what's allowed |
| [`examples/`](examples/before-after-cli.md) | worked before/after README upgrades |
| [`eval/`](skills/readmedaddy/eval/README.md) | fixtures, blind judge, and the score recomputation script |

## Contributing

Issues and pull requests are welcome. Start with
[CONTRIBUTING.md](CONTRIBUTING.md), and see [SECURITY.md](SECURITY.md) for
reporting vulnerabilities and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for
community expectations. Released changes are tracked in
[CHANGELOG.md](CHANGELOG.md). The one rule: no behavioral change without a failing
eval scenario first.

## License

MIT © 2026 Systemartis. See [LICENSE](LICENSE).
