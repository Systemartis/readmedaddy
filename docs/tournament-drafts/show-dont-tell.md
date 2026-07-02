# readmedaddy

[![ci](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml/badge.svg)](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![version](https://img.shields.io/badge/version-0.1.0-blue.svg)](CHANGELOG.md)
[![Agent Skill](https://img.shields.io/badge/Claude%20Code-Agent%20Skill-8A2BE2.svg)](https://agentskills.io)

**A thin README in. A README people star out — with the score to prove it.**

readmedaddy is a [Claude Code](https://claude.ai/code) [Agent Skill](https://agentskills.io) that points at a repo, detects what kind of project it is, drafts competing READMEs, and ranks them through ten quality gates whose weights shift with the project type. It ships the winner and verifies every factual claim against your code first. The README earns its score instead of asserting it.

Don't take the pitch. Look at what it does.

## See it work

readmedaddy looked at a small Rust CLI with a real test suite, CI, and a one-binary install — none of which reached its README. It detected the **CLI** archetype, so it led with the three gates CLI readers care about most (a demo, a 30-second quickstart, a one-line hook) and rewrote the page around them:

<table>
<tr>
<td width="50%" valign="top">

**Before** — inert, ~28 / 100

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

**After** — readmedaddy, ~94 / 100

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

The lift, scored on CLI weighting — the heaviest gates first:

| Gate (CLI weighting) | Before | After |
|----------------------|:------:|:-----:|
| G3 Visual (demo / ASCII) | 0 | 5 |
| G4 Quickstart | 2 | 5 |
| G1 Hook | 1 | 5 |
| **Weighted total (/100)** | **28.5** | **94.0** |

Same repo, same facts — the README just started doing its job. The full ten-gate scorecard is in [`examples/before-after-cli.md`](examples/before-after-cli.md), reproduced here unedited.

## Why it's "contextual"

A perfect CLI README makes a poor library README, so readmedaddy doesn't score every project the same way. It detects the archetype, then **shifts the gate weights to match**. Point it at a library instead and the banner disappears — a library sells itself with a typed code block, not ASCII — and the weight moves to API usage, badges, and completeness:

| | CLI repo (`stint`) | Library repo (`fetchet`) |
|---|---|---|
| Heaviest gates | G3 demo · G4 quickstart · G1 hook | G4 API usage · G2 badges · G6 completeness |
| What led the first screen | ASCII wordmark + terminal demo | typed code hero + badge row, **no banner** |
| Scored lift | 28.5 → 94.0 | 28.0 → 95.5 |

Same ten gates, different weights — that is the whole idea. The library walk-through is in [`examples/before-after-library.md`](examples/before-after-library.md).

## Install

```sh
git clone https://github.com/Systemartis/readmedaddy
cd readmedaddy && ./install.sh   # copies the skill into ~/.claude/skills, then verifies it
```

`install.sh` makes no network calls, touches nothing outside the destination, and is safe to re-run. Then invoke it by name — **readmedaddy** — or let it fire on its description. (Or copy `skills/readmedaddy/` into any agent's skills directory by hand.)

## When it fires

readmedaddy is trigger-described: in Claude Code it activates on the symptoms below, no command needed. Its frontmatter `description` is the trigger —

> Use when writing a README from scratch for a new repo, or when an existing README is thin, outdated, unscannable, buries the value proposition, has no quickstart, or doesn't match its project type; when a project needs a strong front page before open-sourcing; or when asked to "improve the README", "write a README", "make a good README", or "readme review". Not a docs-site generator; yields to existing project style guides.

In other words, reach for it when:

- a new repo has **no README**, or a one-line placeholder;
- an existing README is **thin, outdated, unscannable**, or buries what the project does;
- there's **no copy-pasteable quickstart**, or it's wrong;
- the README **doesn't match its project type** (a CLI with no demo, a library with no API snippet);
- a project needs a **strong front page before open-sourcing**.

## How it works

Five steps, every run:

1. **Detect the archetype.** Read the languages, entrypoints, and manifests and resolve the repo to exactly one of ten types (CLI, library, framework, app/SaaS, infra/devops, data/ML, agent-skill/plugin, research, monorepo, internal-tool).
2. **Pull the pattern set.** Load that archetype's must-have sections, the right visual, the gate weighting, and the exemplars that win for it.
3. **Generate candidates.** Draft competing options per key section — hook, quickstart, visual, examples — so the ranking has something to separate.
4. **Rank through the gates.** Score every candidate 0–5 on the ten gates, apply the archetype's weights, normalize to /100. The per-gate **deficit** (weight × gap) becomes the fix list, highest-leverage first.
5. **Assemble, verify, output.** Stitch the winner, graft the best of the runners-up, then **verify every claim against the repo** — no invented benchmarks, no fake stars, no badge for a thing that doesn't exist.

## The ten gates

Every candidate is scored against these, weighted by archetype. Full anchors and the weight tables live in [`references/multi-gate-rubric.md`](skills/readmedaddy/references/multi-gate-rubric.md).

| | Gate | Measures |
|----|------|----------|
| G1 | Hook | first screen conveys what it is + why you'd care, in one line |
| G2 | Identity / trust | name, tagline, **real** badges, honest social proof |
| G3 | Visual | an apt ASCII / diagram / screenshot / demo that earns its space |
| G4 | Quickstart | install + smallest real usage in under 30s, copy-paste correct |
| G5 | Scannability | headings, short paragraphs, tables, a TOC when long |
| G6 | Completeness | usage, config, examples, links, license — without bloat |
| G7 | Credibility | real examples, CI/test signals, honest limitations & non-goals |
| G8 | Contextual fit | follows the conventions of its archetype |
| G9 | Community / maint | contributing, code of conduct, changelog, support |
| G10 | Voice | distinct, confident, no AI-slop |

readmedaddy itself is the **agent-skill / plugin** archetype, so its own README — this one — is weighted toward G1 (hook), G4 (examples), and G8 (fit), with the trigger description graded under G1 and G8.

## Tournament mode

Most requests are served by a single contextual pass with competing per-section candidates. For high-stakes front pages — a repo about to be open-sourced, a flagship README whose quality moves adoption — readmedaddy escalates to a **tournament**: five to six whole-README drafts in deliberately distinct styles (banner/CLI, diagram-led, story-hook, reference-grade, show-don't-tell, minimal-elegant), a **three-judge panel** (a craft judge, a first-impression judge, an ASCII/design judge), and a grafted winner re-scored until it beats every draft it was built from.

This README went through exactly that. It is held to the same rubric it scores other repos with.

## What's in the skill

```text
skills/readmedaddy/
├── SKILL.md                  # lean entry point + the five-step method
├── references/
│   ├── multi-gate-rubric.md      # the ten gates, 0–5 anchors, weight tables
│   ├── archetypes.md             # ten archetypes: signals, sections, visual, exemplars
│   ├── famous-readme-patterns.md # the README canon + exemplars by archetype
│   └── generation-and-ranking.md # generate → rank → judge-panel → graft → verify
├── assets/badges.md          # badge recipes that map to real facts only
└── eval/                     # fixtures + harness: detection & gate outcomes, RED→GREEN
```

## Non-goals & precedence

readmedaddy is honest about what it is not:

- **Not a docs-site generator.** It writes the front page, not your `/docs` tree.
- **It invents nothing.** No fabricated stars, downloads, benchmarks, or testimonials, and no badge for a thing that doesn't exist. Any quality claim traces to a rubric score or it gets cut.
- **It's a skill, not a binary.** It runs inside an agent that can read the repo; there's no standalone CLI to install on its own.
- **It defers, it doesn't override.** readmedaddy yields, highest first, to host safety policy, an explicit live user instruction, your standing project docs (`CLAUDE.md` / `AGENTS.md`) and any existing style guide, then engineering-discipline skills. Where a repo pins a README convention, it ranks **within** that convention. It composes with project-finalization skills as the README stage of a delivery pipeline.

## How it's verified

Quality claims aren't taken on faith — neither is the skill's own plumbing. CI (badge up top) runs on every push and PR:

```sh
python3 scripts/validate-skill.py   # frontmatter + description budget, relative-link
                                    # integrity, version consistency (SKILL.md ↔ CHANGELOG),
                                    # and the clean-for-publish forbidden-reference guard
shellcheck install.sh && sh -n install.sh
npx markdownlint-cli2 "**/*.md"
```

The `eval/` directory holds sample repos per archetype with expected detection and gate outcomes, run RED→GREEN so behavior is tested rather than asserted.

## Contributing

Issues and PRs are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), and run `python3 scripts/validate-skill.py` before opening a PR. Bugs and README requests have [issue templates](.github/ISSUE_TEMPLATE/). Releases are tracked in [CHANGELOG.md](CHANGELOG.md); see also the [code of conduct](CODE_OF_CONDUCT.md) and [security policy](SECURITY.md).

## License

MIT © 2026 Systemartis. See [LICENSE](LICENSE).
