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

**readmedaddy is a Claude Code Agent Skill that writes — or rebuilds — the best README for whatever repo you point it at.**

Most README tools fill in a template. readmedaddy ranks. Its edge is a
contextual multi-gate ranking system: it detects your project's archetype
(CLI, library, app, agent skill, ten in all), pulls the README patterns that
win for that type, generates competing candidate sections, and scores them
through ten quality gates whose weights shift with the archetype. The winner
is assembled, the best of the runners-up grafted in, and every factual claim
checked against your code before a line ships. The README it hands back earns
its score instead of asserting one.

**Jump to:** [Triggers](#when-readmedaddy-fires) · [Install](#install) ·
[Use it](#use-it) · [The method](#the-method) ·
[The ten gates](#the-ten-gates) · [What it is not](#what-it-is-not) ·
[Verification](#trust-the-output)

## When readmedaddy fires

It is an agent skill, so it triggers on its description the moment a
conversation looks like README work. The frontmatter that does the triggering:

> Use when writing a README from scratch for a new repo, or when an existing
> README is thin, outdated, unscannable, buries the value proposition, has no
> quickstart, or doesn't match its project type; when a project needs a strong
> front page before open-sourcing; or when asked to "improve the README",
> "write a README", "make a good README", or "readme review".

In practice, reach for it when:

- you are starting a repo and need a README from nothing,
- the README is thin, outdated, unscannable, or buries what the project does,
- the README has no quickstart, or reads like the wrong kind of project,
- you are about to open-source something and the front page has to land, or
- you just say "write a README", "improve the README", or "readme review".

## Install

```sh
git clone https://github.com/Systemartis/readmedaddy
cd readmedaddy
./install.sh          # copies the skill into ~/.claude/skills and verifies it landed
```

Install somewhere else with `DEST=/path/to/skills ./install.sh`. The script
makes no network calls, touches nothing outside the destination, and is safe to
re-run.

## Use it

Once installed, ask in plain language or invoke the skill by name:

> Write a README for this repo.

> The README is thin and buries what this does — fix it.

> readme review

readmedaddy reads the repo, detects the archetype, ranks candidate sections,
and hands back a finished README plus the strongest runner-up sections as
labelled alternatives you can swap in without re-running anything.

The move it makes, on an illustrative CLI (full worked upgrades, with scorecards,
live in [`examples/`](examples/)):

> **Before:** A simple command line time tracker written in Rust.
>
> **After:** Track where your hours actually go — without leaving the terminal.

The before line is inert. The after leads with the outcome, in the reader's own
words, and readmedaddy makes that change across every gate the archetype
weights heaviest — then shows you the scoring.

## The method

Five steps, in order:

1. **Detect the archetype.** Read the languages, entrypoints, and manifests
   (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `SKILL.md`) and
   resolve the repo to exactly one of ten archetypes.
2. **Pull the pattern set.** Load that archetype's must-have sections, the right
   visual, the gate weighting, and its exemplars.
3. **Generate candidates.** Draft competing options for each key section — hook,
   quickstart, visual, usage. For a high-stakes front page, draft several whole
   READMEs in distinct styles instead.
4. **Rank through the gates.** Score every candidate on ten gates at the
   archetype's weights, normalized to a 0–100 scale. The score is the selection
   function: the top draft becomes the skeleton, per-gate winners get grafted in.
5. **Assemble, verify, output.** Stitch the winner, reconcile the seams, and
   verify every claim against the repo — no invented benchmarks, no fake stars,
   no badge for a thing that does not exist.

For a flagship or pre-open-source README, readmedaddy escalates to **tournament
mode**: five to six whole-README drafts in different idioms, scored by a
three-judge panel (a craft judge, a cold first-impression judge, and a visual
judge), then grafted into one winner. Everything else takes the fast single
pass, because escalating by default is the same over-engineering the rubric
penalizes in prose.

## The ten gates

Every candidate is scored 0–5 against a concrete anchor on each gate:

| Gate | What it measures |
|------|------------------|
| G1 Hook | First screen says what it is and why you'd care, in one line. |
| G2 Identity / trust | Name, one-liner, and badges that actually resolve. |
| G3 Visual | An ASCII wordmark, diagram, screenshot, or demo that earns its space. |
| G4 Quickstart | Install plus smallest real usage, copy-paste correct, under 30s. |
| G5 Scannability | Heading hierarchy, short paragraphs, tables, a TOC when long. |
| G6 Completeness | Usage, config, examples, links, license — without padding. |
| G7 Credibility | Real examples, CI/test signals, honest limitations and non-goals. |
| G8 Contextual fit | Follows the conventions that archetype's readers expect. |
| G9 Community / maint | Contributing, code of conduct, changelog, support signals. |
| G10 Voice | Plain, confident sentences with zero AI-slop. |

Each gate starts at a **base weight of 2**. Every archetype then bumps its three
heaviest gates by +4, +3, and +2, so the weights always sum to 29 and normalize
against a fixed 145-point ceiling. A CLI loads weight onto the demo (G3) and the
quickstart (G4); a library onto API usage (G4) and badges (G2); an app onto the
hook (G1) and the screenshot (G3). Same ten gates, different center of gravity.

### Held to its own rubric

readmedaddy is itself an agent skill, so this front page is judged on the
agent-skill row, where the hook, the examples, and contextual fit carry the
most weight. Scored against its own rubric:

| Gate | Weight | Score | Weighted |
|------|--------|-------|----------|
| G1 Hook | 6 | 5 | 30 |
| G2 Identity / trust | 2 | 4 | 8 |
| G3 Visual | 2 | 4 | 8 |
| G4 Quickstart | 5 | 5 | 25 |
| G5 Scannability | 2 | 5 | 10 |
| G6 Completeness | 2 | 5 | 10 |
| G7 Credibility | 2 | 4 | 8 |
| G8 Contextual fit | 4 | 5 | 20 |
| G9 Community / maint | 2 | 4 | 8 |
| G10 Voice | 2 | 5 | 10 |
| **Total** | **29** | — | **137 → 94 / 100** |

The four gates held at 4 are honest, not modest: the badges are pre-first-tag,
the visual is a wordmark rather than a live demo, the eval's numbers are not yet
collected, and the project is an early alpha. This is a self-score, not a verdict
— blind judging is what the eval harness below is for.

## What it is not

- **Not a docs-site generator.** It writes one excellent front page, not a manual.
- **It yields,** in order, to host safety policy, your explicit instructions,
  your project's own docs and style guide (`CLAUDE.md` / `AGENTS.md`), and your
  engineering-discipline skills. Where a repo already pins a README convention,
  readmedaddy ranks within it instead of overriding it.
- **It composes** with project-finalization skills as the README stage of a
  delivery pipeline, without depending on any particular one.
- **It invents nothing.** No fake stars, no fabricated download counts, no
  benchmark a repo cannot back. Every badge maps to a fact in the repo, and any
  quality claim traces to a gate score rather than an adjective.

## Trust the output

Three checks keep readmedaddy honest, and they run on its own repo:

- A **structural validator** ([`scripts/validate-skill.py`](scripts/validate-skill.py),
  standard library only) enforced in CI: frontmatter and description budget,
  that every relative link resolves, that `SKILL.md`'s version matches the top
  changelog entry, and a clean-for-publish guard that fails the build on personal
  or company-internal references.
- **CI** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) also runs
  `shellcheck` on `install.sh` and markdownlint across the docs.
- An **eval harness** ([`skills/readmedaddy/eval/`](skills/readmedaddy/eval/))
  with four fixture repos — a Node CLI, a Python library, an agent skill, and a
  research repo — and a pre-registered pass bar: the correct archetype on all
  four, and a blind-judged README that beats a thin baseline on every fixture by
  a fixed margin. The thresholds were committed before any result was collected,
  so the numbers cannot be fit to an outcome after the fact, and results are
  reported when they exist rather than asserted here.

## What's inside

The skill is Markdown-first and dependency-free. Depth lives in `references/`,
loaded on demand:

- [`references/archetypes.md`](skills/readmedaddy/references/archetypes.md) — the
  ten archetypes: detection signals, must-have sections, the right visual, and
  exemplars for each.
- [`references/multi-gate-rubric.md`](skills/readmedaddy/references/multi-gate-rubric.md)
  — the ten gates, the 0–5 anchors, and the per-archetype weight tables.
- [`references/generation-and-ranking.md`](skills/readmedaddy/references/generation-and-ranking.md)
  — the generate-then-rank workflow and the tournament with its judge panel.
- [`references/famous-readme-patterns.md`](skills/readmedaddy/references/famous-readme-patterns.md)
  — the README canon (Art-of-README, Standard-Readme, makeareadme) and exemplars
  by archetype.

Reusable badge recipes are in
[`skills/readmedaddy/assets/badges.md`](skills/readmedaddy/assets/badges.md), and
worked before/after upgrades are in [`examples/`](examples/).

## Contributing and license

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md),
the [code of conduct](CODE_OF_CONDUCT.md), and [SECURITY.md](SECURITY.md) for
reporting. Every change is tracked in [CHANGELOG.md](CHANGELOG.md).

MIT © 2026 Systemartis. See [LICENSE](LICENSE).
