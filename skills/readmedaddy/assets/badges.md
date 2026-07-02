# Badge recipes

Copy-paste badge markdown for a readmedaddy-generated README, templated for
`github.com/Systemartis/readmedaddy`. Swap `Systemartis/readmedaddy` for the
target repo's `owner/name` when generating for another project.

A badge is a **claim**. Ship one only when something true backs it: a CI run, the
LICENSE file, a real release tag, or the skill's own metadata. Quality lives in the
multi-gate rubric score, never in a badge.

## Allowed (each maps to a real fact)

### CI status

Resolves once `.github/workflows/ci.yml` has run on the default branch.

```markdown
[![ci](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml/badge.svg)](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml)
```

### License (MIT)

True because the repo ships a MIT `LICENSE`.

```markdown
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
```

### Release / version

Prefer the dynamic badge — it reads the real latest tag, so it can never lie:

```markdown
[![release](https://img.shields.io/github/v/release/Systemartis/readmedaddy)](https://github.com/Systemartis/readmedaddy/releases)
```

Before the first tag exists, a static badge is fine **only if** it matches
`SKILL.md` `metadata.version` and `CHANGELOG.md`:

```markdown
[![version](https://img.shields.io/badge/version-0.1.0-blue.svg)](CHANGELOG.md)
```

### Agent Skill

True because this repo is a Claude Code Agent Skill (a static descriptor, not a metric):

```markdown
[![Agent Skill](https://img.shields.io/badge/Claude%20Code-Agent%20Skill-8A2BE2.svg)](https://agentskills.io)
```

### Recommended order

Lead with trust, then identity. A tight row reads best:

```markdown
[![ci](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml/badge.svg)](https://github.com/Systemartis/readmedaddy/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Agent Skill](https://img.shields.io/badge/Claude%20Code-Agent%20Skill-8A2BE2.svg)](https://agentskills.io)
```

## Not allowed (vanity or false claims)

Never emit a badge whose number you can't tie to a real source:

- **Fake stars / followers** — hardcoded star, fork, or follower counts. If you want a
  live count, link the repo; GitHub already shows the real number.
- **Fake downloads / installs** — invented install, download, or "used by" counts. Ship
  a download badge only when a registry (npm, PyPI, crates.io, Marketplace) actually
  serves the number.
- **Phantom coverage / benchmark** — coverage %, build-size, or benchmark badges for
  tests or measurements that don't exist in the repo.
- **Self-awarded endorsements** — "production-ready", "battle-tested", "awesome",
  "#1", or a maintainer-applied "verified/featured" badge nobody granted.

Rule of thumb: if removing the badge would require also deleting a fact from the repo,
it's earned. If it would only delete a boast, cut it.
