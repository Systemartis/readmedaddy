# readmedaddy

**Writes the README your repo deserves — by detecting its type and ranking competing drafts through gates weighted for that type.**

[![ci](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml/badge.svg)](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml)
[![version](https://img.shields.io/badge/version-0.1.0-blue.svg)](CHANGELOG.md)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Agent Skill](https://img.shields.io/badge/Claude%20Code-Agent%20Skill-8A2BE2.svg)](https://agentskills.io)

```
   any repo
      │   detect its archetype      CLI · library · app · skill · …
      │   draft & rank candidates   ten gates, weighted by type
      │   graft the runners-up      keep each gate's best
      │   verify every claim        against the code, never invented
      ▼
   the README it deserves
```

readmedaddy is a [Claude Code](https://claude.ai/code) [Agent Skill](https://agentskills.io). Because a great CLI README makes a poor library README, it never grades against one fixed checklist: it detects the repo's archetype, pulls the patterns that win for that type, and ranks candidate drafts through ten quality gates whose weights shift with the type — then verifies every claim against the code before output.

## Quickstart

```sh
git clone https://github.com/Systemartis/readmedaddy
cd readmedaddy && ./install.sh    # copies the skill into ~/.claude/skills, verifies it landed
```

In Claude Code, open a repo and ask for a README: readmedaddy fires on its description, or invoke it by name. Worked runs: [CLI before/after](examples/before-after-cli.md) · [library before/after](examples/before-after-library.md).

## Triggers when

A repo has no README, or one that is thin, outdated, unscannable, buries its value proposition, has no quickstart, or doesn't fit its project type — and when you ask to *write a README*, *improve the README*, or do a *readme review*.

## What it weighs

Ten gates, ten archetypes. The weights move so the README is judged the way that kind of project is actually read:

| Project type | Gates it weights heaviest |
|---|---|
| CLI | demo · quickstart · hook |
| Library / framework | API usage · badges · completeness |
| App / SaaS | hook · screenshot · community |
| Agent skill *(this repo)* | hook · triggers · examples · fit |

The full ten-archetype catalog and the 0–5 gate anchors live in [`references/`](skills/readmedaddy/references/). readmedaddy is scored on its own agent-skill row, and this page is the winner of its own tournament.

## Scope & honesty

- **Tournament mode** — for a front page that moves adoption, readmedaddy drafts several whole READMEs, runs a three-judge panel, and grafts the winner.
- **Verifies, never invents** — no fake stars, downloads, or benchmarks; a badge ships only when something true backs it.
- **Not a docs-site generator,** and it yields to your project's existing style guide and docs.

## More

The skill: [SKILL.md](skills/readmedaddy/SKILL.md). References: [archetype catalog](skills/readmedaddy/references/archetypes.md) · [gate rubric](skills/readmedaddy/references/multi-gate-rubric.md) · [generation & ranking](skills/readmedaddy/references/generation-and-ranking.md) · [README canon](skills/readmedaddy/references/famous-readme-patterns.md). Every change is gated by [`scripts/validate-skill.py`](scripts/validate-skill.py) and CI: structure, links, frontmatter, clean-for-publish, shellcheck, markdownlint.

[Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Code of conduct](CODE_OF_CONDUCT.md) · [Changelog](CHANGELOG.md)

## License

MIT © 2026 Systemartis. See [LICENSE](LICENSE).
