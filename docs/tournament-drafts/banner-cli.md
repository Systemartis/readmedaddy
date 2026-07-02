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

**Generate or upgrade the README your repo actually deserves — readmedaddy detects your project's archetype, ranks competing drafts through ten quality gates weighted for that archetype, and checks every claim against your code before it writes a word you can't back up.**

readmedaddy is a [Claude Code](https://claude.ai/code) [Agent Skill](https://agentskills.io). Point it at a repo and it returns a README that *earns* its score instead of asserting it. The difference from a one-shot template is the ranking: a CLI's README is judged on its demo and quickstart, a library's on its API snippet and badges, an app's on its hook and screenshot — and readmedaddy weights the gates to match before it picks a winner.

## Quickstart

```sh
git clone https://github.com/Systemartis/readmedaddy
cd readmedaddy && ./install.sh   # copies the skill into ~/.claude/skills, then verifies it landed
```

`install.sh` makes no network calls, touches nothing outside the destination, and is safe to re-run. Install elsewhere with `DEST=/path ./install.sh`, or copy `skills/readmedaddy/` into any agent's skills directory by hand.

Then, in Claude Code, just ask:

```text
readmedaddy: write a README for this repo
```

Or let it fire on its own description — "improve the README", "write a README", "make a good README", "readme review". No flags, no config.

## Why it's not a template

A README is only "good" relative to what the project *is*. readmedaddy runs five steps in order:

1. **Detect the archetype.** Read the manifests, entrypoints, and languages; resolve the repo to exactly one of ten archetypes. When the signals genuinely tie, it states the assumption in one line and proceeds.
2. **Pull that archetype's pattern set.** Its must-have sections, the right visual, the gate weighting, and exemplars to adapt from.
3. **Generate competing candidates.** Two to three real variants per key section — or, for high-stakes work, N whole-README drafts in distinct styles.
4. **Rank through the gates.** Score every candidate 0–5 on ten gates, apply the archetype's weights, normalize to `/100`, and let the per-gate deficits order the fix list.
5. **Assemble, verify, output.** Stitch the winner, graft the best of the runners-up, and **verify every factual claim against the repo** — no invented benchmarks, no fake stars or downloads, no badge for a thing that doesn't exist.

## The ten gates

Each candidate is scored 0–5 against a concrete anchor on every gate.

| Gate | What it scores |
|------|----------------|
| G1 Hook | does the first screen say what it is and why you'd care, in one line |
| G2 Identity / trust | name, one-liner, real badges — never a fabricated count |
| G3 Visual | a wordmark, diagram, screenshot, or demo that is apt and earns its space |
| G4 Quickstart | install + smallest real usage, copy-paste correct in under 30s |
| G5 Scannability | heading hierarchy, short paragraphs, tables, a TOC once it's long |
| G6 Completeness | usage, config, examples, links — without bloat |
| G7 Credibility | real examples, a CI/test signal, honest limitations and non-goals |
| G8 Contextual fit | follows the conventions of its archetype |
| G9 Community / maintenance | contributing, changelog, support, roadmap |
| G10 Voice | confident and distinct, with zero AI-slop |

**The weighting is the whole trick.** Every gate starts at weight 2. Each archetype bumps its three heaviest gates by +4, +3, and +2 — the bumps always sum to +9, so every archetype's weights total 29 and normalize against the same 145-point ceiling. The score isn't a grade you file away; it's the selection function. The top draft becomes the skeleton, per-gate winners get grafted in, and `deficit = weight × (5 − score)` ranks exactly what to fix first.

## The ten archetypes

readmedaddy classifies before it ranks, because the heaviest gates change with the type.

| Archetype | Heaviest gates |
|-----------|----------------|
| CLI tool | G3 demo/ASCII · G4 quickstart · G1 hook |
| Library | G4 API usage · G2 badges · G6 completeness |
| Framework | G4 · G2 · G6, leaning on G1 positioning + G3 architecture |
| App / SaaS | G1 hook · G3 screenshot · G9 community |
| Infra / devops | G4 quickstart · G7 credibility · G6 completeness |
| Data / ML | G1 hook · G7 results/benchmarks · G6 citations |
| Agent skill / plugin | G1 hook · trigger quality · G4 examples · G8 fit |
| Research | G1 finding · G7 reproducibility · G6 citations |
| Monorepo | G5 scannability · G6 completeness · navigation |
| Internal tool | G5 · G6 · navigation, plus G4 setup + G7 runbook |

readmedaddy itself is the **agent-skill / plugin** archetype, so this very front page was scored on the row that bumps **G1 (hook)**, **G4 (examples)**, and **G8 (fit)** heaviest. The skill is held to its own rubric.

## Tournament mode

Most requests are well served by a single contextual pass with per-section candidates. When the README is a public front page that materially moves adoption, escalate:

- **5–6 whole-README drafts** in deliberately distinct styles (banner/CLI, diagram-led, story-hook, reference-grade, show-don't-tell, minimal-elegant).
- **A three-judge panel** — a craft judge (does it run, is it complete and honest), a first-impression judge (would a cold visitor trust it in five seconds), and an ASCII/design judge (does the visual earn its space) — each scoring every draft through the contextual rubric.
- **A grafted winner**, re-scored until it beats every draft it was built from.

This README was produced by exactly that tournament.

## See it work

Two full before/after walkthroughs ship in the repo, each showing the raw Markdown readmedaddy emits and the gates the upgrade moves:

- [`examples/before-after-cli.md`](examples/before-after-cli.md) — a thin CLI README rebuilt around its demo, wordmark, and a working quickstart.
- [`examples/before-after-library.md`](examples/before-after-library.md) — a library README rebuilt around a typed code hero and real badges, with ASCII deliberately *under*-weighted.

## When it fires

readmedaddy triggers when a repo needs a front page and the current one doesn't deliver — writing a README from scratch for a new repo, or when an existing one is thin, outdated, unscannable, buries the value proposition, has no quickstart, or doesn't match its project type; when a project needs a strong front page before open-sourcing; or on a direct "improve the README" / "readme review". It is **not** a docs-site generator, and it yields to an existing project style guide.

## Verified, not asserted

readmedaddy ships an eval harness instead of adjectives. Four fixture repos — CLI, library, agent-skill, and research, spanning three languages — are blind-judged through the same rubric against a deliberately thin baseline. The thresholds and falsifiers are **pre-registered before any run**: 4/4 correct archetype detection, at least +20 weighted points of lift on *every* fixture, and an absolute floor of 70/100, with `score.py` re-checking the judge's arithmetic. A null or reversed result is reported as-is — the eval can say no. See [`skills/readmedaddy/eval/`](skills/readmedaddy/eval/).

CI backs it on every push: [`scripts/validate-skill.py`](scripts/validate-skill.py) checks frontmatter budget, relative-link integrity, version consistency, and a clean-for-publish guard; `shellcheck` lints the installer; markdownlint lints the docs.

## What's in the box

| Path | What it is |
|------|------------|
| `skills/readmedaddy/SKILL.md` | the lean skill — the five-step method and triggers |
| `skills/readmedaddy/references/multi-gate-rubric.md` | the ten gates, 0–5 anchors, and per-archetype weight tables |
| `skills/readmedaddy/references/archetypes.md` | detection signals, must-have sections, and the right visual per type |
| `skills/readmedaddy/references/generation-and-ranking.md` | the generate→rank workflow and the tournament |
| `skills/readmedaddy/references/famous-readme-patterns.md` | the README canon and exemplars by archetype |
| `skills/readmedaddy/eval/` | fixtures, blind judge prompt, scorer, and the pre-registration |
| `examples/` | the before/after walkthroughs |

## Composition and non-goals

readmedaddy yields, highest first, to: host safety policy, an explicit live instruction, your standing project docs (`CLAUDE.md` / `AGENTS.md`) and any existing style guide, and your engineering-discipline skills. It composes with project-finalization pipelines as their README stage. When a project already pins a README convention, it ranks *within* that convention rather than overriding it. It invents nothing — no fake stars, no fake downloads, no badge for a feature that doesn't exist, and no quality claim that isn't backed by a gate score.

## Contributing

Issues and pull requests are welcome. The Iron Law: no behavior change without a failing eval or test first. Read [CONTRIBUTING.md](CONTRIBUTING.md) before you start; report vulnerabilities via [SECURITY.md](SECURITY.md); the [Code of Conduct](CODE_OF_CONDUCT.md) applies. Release history lives in [CHANGELOG.md](CHANGELOG.md).

## License

MIT © Systemartis. See [LICENSE](LICENSE).
