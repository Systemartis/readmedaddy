# Before / after: a CLI tool (`stint`)

> **Illustrative example.** `stint` is an invented, generic CLI used to show the
> lift readmedaddy produces on a **CLI-tool** README. The repo, commands, and
> output are fictional. The point is the *shape* of the upgrade and how it scores,
> not these exact words. Both READMEs are shown as raw Markdown so you can see
> exactly what readmedaddy emits; on GitHub the banner renders as an ASCII
> wordmark and the badge lines render as shields.

readmedaddy detected the **CLI** archetype (single binary, `<verb> <noun>`
command surface, terminal-only). CLI weighting puts the most weight on **G3
Visual** (a demo block or wordmark that conveys the idea in seconds), then
**G4 Quickstart** (working in under 30 seconds), then **G1 Hook**. The thin
README scored on none of those; the upgrade leads with all three.

## The repo readmedaddy looked at

A small Rust CLI that tracks time from the shell. It has a test suite and CI, ships
as one binary, and stores entries in a local SQLite file. None of that reached the
old README — the reader could not tell what it was for, whether it was trustworthy,
or how to try it without reading the source.

## Before — the thin README

````markdown
# stint

A simple command line time tracker written in Rust.

## Installation

Install with cargo:

```
cargo install stint
```

## Usage

To start tracking, run:

```
stint start "task name"
```

To stop, run:

```
stint stop
```

You can also run `stint today` to see what you did today, and there is a
report command as well.

## License

This project is licensed under the MIT license.
````

It is not *wrong* — it is just inert. No value proposition, no visual, no proof it
works, no honest scope. A reader bounces before the install line.

## After — the readmedaddy upgrade

````markdown
```text
███████╗████████╗██╗███╗   ██╗████████╗
██╔════╝╚══██╔══╝██║████╗  ██║╚══██╔══╝
███████╗   ██║   ██║██╔██╗ ██║   ██║
╚════██║   ██║   ██║██║╚██╗██║   ██║
███████║   ██║   ██║██║ ╚████║   ██║
╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝   ╚═╝
```

[![ci](https://github.com/acme/stint/actions/workflows/ci.yml/badge.svg)](https://github.com/acme/stint/actions/workflows/ci.yml)
[![crates.io](https://img.shields.io/crates/v/stint.svg)](https://crates.io/crates/stint)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Track where your hours actually go — without leaving the terminal.**

`stint` is a single-binary time tracker for people who live in a shell. One
command to clock in, one to clock out, one to see the day. No app, no login, no
cloud: your hours stay in a local SQLite file you own.

## Quickstart

```sh
brew install acme/tap/stint        # or: cargo install stint
stint start "first task"           # you are now tracking. that is the whole setup.
```

## Demo

```text
$ stint start "writing the Q3 report"
● tracking · writing the Q3 report · started 09:14

$ stint status
● writing the Q3 report · 1h 47m elapsed

$ stint stop
■ stopped · writing the Q3 report · 1h 52m logged

$ stint today
  writing the Q3 report      1h 52m
  code review                0h 38m
  ──────────────────────────────────
  total                      2h 30m
```

## Commands

| Command | What it does |
|---------|--------------|
| `stint start "<task>"` | Clock in on a task (stops the current one first). |
| `stint stop` | Clock out of the running task. |
| `stint status` | Show the running task and elapsed time. |
| `stint today` | Summarize today's entries. |
| `stint report --week` | Roll up the last 7 days by task. |
| `stint edit` | Open the raw log in `$EDITOR` to fix a mistake. |

## Configuration

`stint` reads a few environment variables; all are optional.

| Variable | Default | Purpose |
|----------|---------|---------|
| `STINT_DB` | `~/.local/share/stint/stint.db` | Path to the SQLite log. |
| `STINT_ROUND` | `1` | Round durations to N minutes in reports. |
| `NO_COLOR` | unset | Disable colored output when set. |

## Why stint

- **One binary, zero services.** Drop it on a box and go; nothing to host.
- **Your data, plain SQLite.** Query it, back it up, or delete it — it is one file.
- **Fast.** Start and stop are a single write; `today` is one query.

## Non-goals

- Not a team tracker — one user, one machine. No shared server, no seats.
- No cloud sync, no invoicing, no browser extension.
- Not a Pomodoro timer; it records time, it does not nag you.

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) and run `cargo test`
before opening a PR. Changes are logged in [CHANGELOG.md](CHANGELOG.md).

## License

MIT © acme. See [LICENSE](LICENSE).
````

## What changed, and why it scores higher

- **G1 Hook (1 → 5).** "A simple command line time tracker" became "Track where
  your hours actually go — without leaving the terminal." Outcome first, in the
  reader's words.
- **G3 Visual (0 → 5).** An ANSI-Shadow wordmark for brand recall plus a real
  terminal **demo block** that shows the whole loop — start, status, stop, today —
  in five seconds. For a CLI this is the single highest-leverage change.
- **G4 Quickstart (2 → 5).** Install and first real use collapse into one
  copy-pasteable block that works in under 30 seconds.
- **G5 / G6.** A command table and a config table make it skimmable and complete
  without padding.
- **G7 Credibility (1 → 4).** A CI badge, a version badge, and an explicit
  **Non-goals** section signal that the tool is tested and honest about its scope.
- **G2 / G9 / G10.** Badges add trust at a glance, a Contributing section invites
  participation, and the voice is concrete and confident with no AI-slop.

## Gate scores (CLI weighting)

Each gate is scored 0–5, then multiplied by its CLI-archetype weight from the
rubric's resolved vectors (weights sum to 29, max raw total 145, normalized to
/100 as `round(raw / 145 × 100, 1)`).

| Gate | Wt | Before | After | Wt·Before | Wt·After |
|------|----|--------|-------|-----------|----------|
| G1 Hook | 4 | 1 | 5 | 4 | 20 |
| G2 Identity / trust | 2 | 2 | 4 | 4 | 8 |
| G3 Visual (demo / ASCII) | 6 | 0 | 5 | 0 | 30 |
| G4 Quickstart | 5 | 2 | 5 | 10 | 25 |
| G5 Scannability | 2 | 2 | 5 | 4 | 10 |
| G6 Completeness | 2 | 2 | 4 | 4 | 8 |
| G7 Credibility | 2 | 1 | 4 | 2 | 8 |
| G8 Contextual fit | 2 | 2 | 5 | 4 | 10 |
| G9 Community / maint | 2 | 1 | 4 | 2 | 8 |
| G10 Voice | 2 | 2 | 5 | 4 | 10 |
| Raw total (/145) | 29 | — | — | 38 | 137 |
| **Normalized (/100)** | — | — | — | **26.2** | **94.5** |

**Lift: 26.2 → 94.5 (+68.3).** The biggest single jump is G3, exactly where the CLI
weighting says the most points live: a demo block plus a wordmark is what turns a
correct-but-inert CLI README into one a reader trusts and tries.
