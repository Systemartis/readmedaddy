# readmedaddy

Most READMEs bury the one thing that matters. A reader lands, scans for five
seconds to learn *what is this and why would I use it*, finds "a project for X"
or a paragraph of backstory instead, and leaves before they ever reach your
quickstart.

**readmedaddy** fixes the front page. It is a Claude Code Agent Skill that
detects what *kind* of project you have, ranks competing README drafts through
ten quality gates weighted for that kind of project, assembles the winner from
the best of every draft, and verifies every claim against your repo. The page
ends up earning its score instead of asserting it.

[![ci](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml/badge.svg)](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml)
[![version](https://img.shields.io/badge/version-0.1.0-blue.svg)](CHANGELOG.md)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Agent Skill](https://img.shields.io/badge/Claude%20Code-Agent%20Skill-8A2BE2.svg)](https://agentskills.io)

> A good README for a CLI is a bad README for a library. readmedaddy scores each
> one against *its own* archetype, not a generic checklist.

```text
   any repo
      │
      ▼
   detect archetype          ·  1 of 10 types, from the manifest + entrypoints
      │
      ▼
   generate competing drafts ·  per-section variants, or whole READMEs
      │
      ▼
   rank through 10 gates     ·  weights bumped for this archetype
      │
      ▼
   assemble + graft          ·  winner's spine, best of the runners-up grafted in
      │
      ▼
   verify every claim        ·  against the repo — no invented stars or benchmarks
      │
      ▼
   a README that earns its score
```

## Contents

- [Quickstart](#quickstart)
- [Why ranking, not a template](#why-ranking-not-a-template)
- [The ten gates](#the-ten-gates)
- [Contextual weighting](#contextual-weighting)
- [Tournament mode](#tournament-mode)
- [See it work](#see-it-work)
- [When readmedaddy fires](#when-readmedaddy-fires)
- [What it will not do](#what-it-will-not-do)
- [How it verifies itself](#how-it-verifies-itself)
- [Composes with your stack](#composes-with-your-stack)
- [Project layout](#project-layout)
- [Contributing](#contributing)
- [License](#license)

## Quickstart

Install the skill into your Claude Code skills directory:

```sh
git clone https://github.com/Systemartis/readmedaddy.git
cd readmedaddy
./install.sh          # copies the skill into ~/.claude/skills/readmedaddy, then verifies
```

Then open any repo in Claude Code and ask:

> improve the README

That is the whole setup. readmedaddy triggers on its description, so a plain
request works — "write a README", "make a good README", "readme review" — or you
can invoke it by name: `readmedaddy`. To install somewhere else, set a
destination: `DEST=/path/to/skills ./install.sh`.

## Why ranking, not a template

Template READMEs hand every project the same skeleton and hope it fits. It does
not. The value of a README depends on what the reader came for, and that depends
on the kind of project they are looking at.

readmedaddy starts by classifying the repo into exactly one of ten archetypes
from its languages, entrypoints, and manifests:

> CLI tool · library · framework · app / SaaS · infra / devops · data / ML ·
> agent skill / plugin · research · monorepo · internal tool

The archetype decides which patterns to pull, which visual to lead with, and how
the ten gates are weighted. Then readmedaddy generates competing candidates,
scores them, keeps each gate's winner, and grafts the best of the losers into
the highest-scoring skeleton. The score is the selection function, not a grade
filed at the end.

## The ten gates

Every candidate is scored 0–5 against a concrete anchor on each gate.

| Gate | Asks |
|------|------|
| **G1 Hook** | does the first screen say what it is and why you'd care, in one line? |
| **G2 Identity / trust** | name, one-liner, and *real* badges (no fabricated counts) |
| **G3 Visual** | a wordmark, diagram, screenshot, or demo that is apt, not noise |
| **G4 Quickstart** | install plus smallest real usage in under 30s, copy-pasteable |
| **G5 Scannability** | heading hierarchy, short paragraphs, tables, a TOC when long |
| **G6 Completeness** | usage, config, examples, links, license — without bloat |
| **G7 Credibility** | real examples, CI/test signals, honest limits and non-goals |
| **G8 Contextual fit** | follows the conventions of its archetype |
| **G9 Community / maint** | contributing, code of conduct, changelog, support signals |
| **G10 Voice** | distinct, confident, free of AI-slop |

The full 0- and 5-anchors, the scoring discipline, and a worked scorecard live
in [`multi-gate-rubric.md`](skills/readmedaddy/references/multi-gate-rubric.md).

## Contextual weighting

The gates are the same everywhere; their weights are not. Each archetype bumps
the three gates that decide whether *its* kind of README lands.

| Archetype | Leans hardest on |
|-----------|------------------|
| CLI tool | demo / ASCII · quickstart · hook |
| Library / framework | API usage · badges · completeness |
| App / SaaS | hook · screenshot · community |
| Data / ML | hook · results / benchmarks · completeness |
| **Agent skill / plugin** (this repo) | **hook · examples · archetype fit** |

So a CLI is judged mostly on its demo and a one-paste quickstart, while a library
is judged on its first import block and its badges. The weighting also drives the
fix list: a weak gate the archetype cares about always outranks a weak gate it
does not, so the rubric tells you *what to fix first*, not just how thin the page
is. The per-archetype weight vectors are in
[`multi-gate-rubric.md`](skills/readmedaddy/references/multi-gate-rubric.md);
detection signals and must-have sections per type are in
[`archetypes.md`](skills/readmedaddy/references/archetypes.md).

## Tournament mode

For a front page that materially affects adoption — a repo about to go
open-source, a flagship project — readmedaddy escalates. It drafts five or six
*whole* READMEs in deliberately different styles (banner/CLI, diagram-led,
story-hook, reference-grade, show-don't-tell, minimal-elegant), then convenes a
three-judge panel:

| Judge | Reads for | Decides |
|-------|-----------|---------|
| **First-impression** | the first screen, five seconds, cold | G1 hook, G2 trust |
| **Craft** | the editor/engineer | G4 quickstart, G6/G7 substance, G10 voice |
| **ASCII / design** | the visual critic | G3 visual, G5 scannability |

The top draft becomes the spine; each gate's winner is grafted in where it beats
the spine by a clear margin; the merge is re-scored and only kept if it beats
every draft it was built from. For everything else, a single contextual pass is
faster and nearly as good — escalating by default is the same over-engineering
the voice gate penalizes in prose.

*This very README was produced by that tournament: six styled drafts, the
three-judge panel, a winner grafted from the best of the rest. readmedaddy
dogfoods its own ranking.*

## See it work

Two worked, clearly-labelled illustrative upgrades show the shape of the lift —
raw Markdown in, raw Markdown out, with the gate-by-gate reading of why the
"after" scores higher:

- [`examples/before-after-cli.md`](examples/before-after-cli.md) — a thin,
  inert CLI README becomes a demo-led front page with a wordmark, a real
  terminal demo block, a one-paste quickstart, and an honest non-goals section.
- [`examples/before-after-library.md`](examples/before-after-library.md) — a
  library README rebuilt around the first import block and a real badge row.

## When readmedaddy fires

It is built to trigger on the symptoms of a bad front page, so you rarely have
to name it. readmedaddy activates when:

- you are writing a README from scratch for a new repo;
- an existing README is thin, outdated, unscannable, buries the value
  proposition, has no quickstart, or does not match its project type;
- a project needs a strong front page before open-sourcing;
- you ask to "improve the README", "write a README", "make a good README", or
  "readme review".

## What it will not do

- **It will not generate a docs site.** readmedaddy writes the front page, not a
  documentation portal.
- **It will not invent trust.** No fabricated stars, downloads, benchmarks, or
  "production-ready" badges. A badge ships only when a real fact backs it; any
  quality claim about the output traces to a rubric score, never an assertion.
- **It yields to your conventions.** If a project already pins a README style
  guide, readmedaddy follows it and ranks within it rather than overriding it.
- **It runs inside Claude Code.** This is an Agent Skill, not a standalone
  binary; it reads your repo to verify claims, it does not run your build.

## How it verifies itself

readmedaddy holds its own output to the standard it preaches, and proves the
skill rather than asserting it.

**CI** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs on every
push and PR:

- `scripts/validate-skill.py` — frontmatter and budget checks, relative-link
  integrity, version consistency (SKILL.md `metadata.version` matches the top
  CHANGELOG entry), and the clean-for-publish guard that blocks personal paths
  and internal references from shipping;
- `shellcheck` + `sh -n` on `install.sh`;
- `markdownlint` across the Markdown.

**Eval harness** ([`skills/readmedaddy/eval/`](skills/readmedaddy/eval/)) — four
minimal-but-real repo skeletons (CLI, library, agent-skill, research) with a
detection answer key, plus a *blind* judge that scores readmedaddy's README
against a thin baseline without being told which is which. Thresholds for
detection accuracy and per-fixture lift are committed up front in
[`PREREGISTRATION.md`](skills/readmedaddy/eval/PREREGISTRATION.md); `score.py` is
stdlib-only and runs its own self-tests. No fixture is averaged away — one
mis-detected archetype or one tied baseline falsifies the claim, and the result
is reported as-is.

## Composes with your stack

readmedaddy yields, highest priority first, to: host safety policy, an explicit
live instruction from you, your standing project docs and style guide, and your
engineering-discipline tooling. It composes cleanly with project-finalization
workflows — run it as the README stage of a delivery pipeline — without
depending on any particular sibling skill.

## Project layout

```text
readmedaddy/
├─ skills/readmedaddy/
│  ├─ SKILL.md                       # triggers + the five-step method
│  ├─ references/
│  │  ├─ archetypes.md               # 10 archetypes: signals, sections, visual, weights
│  │  ├─ multi-gate-rubric.md        # the 10 gates, 0–5 anchors, per-archetype weights
│  │  ├─ generation-and-ranking.md   # generate → rank → graft → verify; tournament
│  │  └─ famous-readme-patterns.md   # the README canon + exemplars by archetype
│  ├─ assets/badges.md               # earned-badge recipes
│  └─ eval/                          # fixtures + blind judge + score.py + preregistration
├─ examples/                         # worked before → after upgrades
├─ install.sh                        # one-command install into ~/.claude/skills
└─ scripts/validate-skill.py         # CI structural + clean-for-publish checks
```

## Contributing

Issues and pull requests are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, [SECURITY.md](SECURITY.md)
for reporting, and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for the ground rules.
Run `python3 scripts/validate-skill.py` and `shellcheck install.sh` before
opening a PR; changes are tracked in [CHANGELOG.md](CHANGELOG.md). Current
status: **v0.1.0, initial release.**

## License

MIT © 2026 Systemartis. See [LICENSE](LICENSE).
