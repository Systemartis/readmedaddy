# changelog-scribe

> An agent skill that turns the commits since your last release tag into a clean, grouped CHANGELOG section — every line traceable to a real commit.

![version](https://img.shields.io/badge/version-0.4.0-blue) ![license](https://img.shields.io/badge/license-MIT-green)

When a release is being cut and the CHANGELOG is empty, stale, or out of sync with the history, changelog-scribe resolves the commit range since the last tag, buckets each commit into Keep a Changelog sections, rewrites developer commit subjects into reader-facing lines, and emits a dated `## [version]` block in your changelog's existing order — breaking changes first, called out explicitly.

## When it fires

The skill auto-triggers when your request matches its description. Phrases it listens for:

> "Update the changelog."

> "Write release notes."

> "What changed since the last release?"

It also fires when a release is being cut and the CHANGELOG no longer matches the commits since the last tag. To skip the auto-trigger, invoke it by name: "use changelog-scribe".

## Install

Copy the skill into the directory your agent scans:

| Agent | Install path |
|-------|--------------|
| Claude Code | `~/.claude/skills/changelog-scribe/` |

```bash
cp -r skills/demo ~/.claude/skills/changelog-scribe
```

## Seeing it work

A typical exchange (output shape shown — entries always come from your actual commits, never invented):

```
you:    Write release notes — we're cutting the next version.

skill:  Range: v0.4.0..HEAD. Dropped merge and formatting-only commits as noise.

        ## [0.5.0] - 2026-07-02

        ### Removed
        - Drops support for the legacy config format. (breaking)

        ### Added
        - Adds a dry-run mode that previews the section without writing it.

        ### Fixed
        - No longer fails on repositories with a single commit.
```

## How it works

1. **Find the range** — latest release tag to `HEAD`. No tag? It uses the full history and says so.
2. **Classify each commit** — into Added / Changed / Fixed / Removed / Deprecated / Security, using the precedence table in [`references/grouping.md`](skills/demo/references/grouping.md). Merge commits, formatting-only changes, and CI tweaks with no user-facing effect are dropped.
3. **Rewrite for readers** — each kept commit becomes a present-tense, user-facing line. A commit subject is a developer note; a changelog line is for the person upgrading.
4. **Assemble** — a dated `## [version]` block in the repo's existing changelog order, breaking changes first.
5. **Verify** — every emitted line traces back to a real commit in the range. Nothing the diff doesn't support.

## Layout

```
skills/demo/
├── SKILL.md              # lean entry point: triggers + the five-step method
└── references/
    └── grouping.md       # commit→section mapping + noise filter, pulled on demand
```

## What it is not

- **Not a version bumper** — it writes the section; you pick the number.
- **Not a tagger or publisher** — no `git tag`, no release creation.
- It **yields to an existing changelog format** already in your repo rather than imposing one.
- It **never invents an entry** that has no commit behind it.

## License

MIT
