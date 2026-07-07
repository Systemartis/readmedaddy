# Changelog

All notable changes to readmedaddy are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Config schema v2**: a `guard` section (`pr`, `main`, `sweep`,
  `autofix.runner`, `autofix.command`) with collision-safe key names, consumed
  by the GitHub Action from v0.3.0. A published JSON Schema
  (`schema/readmedaddy.schema.json`) gives editors validation via `$schema`.
- **`--config FILE`**: run the detector against an explicit config (CI gates
  pass the PR base ref's copy — a PR can no longer waive its own gate;
  `/dev/null` = pure defaults).
- **`--print-config KEY`**: resolved config values through the one hardened
  parser, for workflows and scripts.
- **`--lint-config`**: JSON well-formedness + unknown-key detection (python3,
  stdlib only) and enum validation (pure sh), exit 0/1/2.

### Fixed

- **Fresh installs no longer open with a nag**: the Stop hook seeds its cooldown
  on first sight of a repo whose staleness predates the install, and the
  cooldown is keyed per HEAD + drift class — one nudge per drift event, not one
  per newly-touched file. `enforce` mode is exempt by design.
- **Glob-named files can no longer mask drift** (pathname expansion disabled
  around the status/range loops).
- **Non-ASCII watched paths** now match in `--check --range` mode
  (`core.quotePath=false`).
- **`--check` fails loudly (exit 2)** outside a git repo and on shallow clones
  where committed-drift comparison would be meaningless — a misconfigured CI
  gate can no longer pass silently green.
- **References no longer instruct live web checks** — every G2/G7 verification
  step is offline-checkable, matching SKILL.md's operate-offline mandate.
- **README's PR-gate snippet is a complete, valid workflow** pinned to the
  moving `@v0` tag; `validate-skill.py` now fails CI on stale action pins.

## [0.2.1] - 2026-07-02

Fixes from an adversarial deep-dive review (every finding below was confirmed
by execution before being fixed; the behavior changes shipped tests-first).

### Fixed

- **`install.sh` executable bit restored** — the README quickstart failed with
  `permission denied` on a fresh clone. CI now asserts the exec bits so this
  cannot regress.
- **Guard blind spot under `.github/`**: the clean-for-publish and no-network
  scans skipped `.github/` because a substring test conflated it with `.git/`.
  Both walks now test path components; the directory where CI code lives is
  scanned.
- **Plain glob watch patterns** (`docs/*.md`) now match in `--check`,
  `--range`, and working-tree modes — previously they matched only in the
  committed-drift fallback, so the CI Action could miss drift the local hook
  reported.
- **Unknown arguments exit 2** — a typo'd `--check` no longer falls through to
  hook mode and passes a CI gate permanently green.
- **Renames out of watched paths are drift** — `git mv src/main.js retired.js`
  now flags `src/main.js` instead of being missed.
- **Cooldown state moved inside `.git/`** (`.git/readmedaddy-state`) — the hook
  no longer litters target repos with an untracked `.readmedaddy/` directory.
- **Action comment mode degrades gracefully on fork PRs** (read-only token):
  warning + step summary instead of a red advisory check; drifted filenames are
  sanitized against markdown fence injection.
- **`install.sh` no longer ships `eval/`** into agents' skills dirs — the
  fixtures include a decoy SKILL.md an agent could mis-load.
- Docs: SECURITY.md rewritten around the real threat surface (the hook and the
  settings installer) and versions table bumped; README's quoted trigger
  description synced with SKILL.md; SKILL.md's weight pointer corrected;
  rubric's rounding formula matched to `score.py` (one decimal); config-parsing
  and quoted-path ceilings documented; CONTRIBUTING structure refreshed;
  manual uninstall path documented.

## [0.2.0] - 2026-07-02

Every agent, one detector, and a machine-enforced local-only guarantee.

### Added

- **Standalone `--check` mode** on the drift detector
  (`hooks/readme-drift.sh --check [--range A...B]`): agent-agnostic drift
  detection for CI, git pre-commit hooks, and any coding agent. Exit 0 fresh /
  1 drift (files on stdout) / 2 bad range; stateless and idempotent; ignores
  the session-scoped `README_DADDY_HOOK` switch, respects `.readmedaddy.json`.
  Covered by seven new hook tests.
- **Composite GitHub Action** (`action.yml`): runs `--check --range` against a
  PR's base and posts one sticky drift comment (`mode: comment`) or fails the
  job (`mode: fail`). Dogfooded on this repo's own pull requests.
- **Multi-agent install.** `install.sh` now installs for Claude Code
  (`~/.claude/skills`), opencode (`~/.config/opencode/skills`, and it reads the
  Claude path natively), and GitHub Copilot CLI/coding agent
  (`~/.copilot/skills`), verifying each copy. Agents without a skills loader
  (Cursor, Codex, Gemini CLI, Zed, …) hook in via one `AGENTS.md` line;
  `DEST=/path` still installs anywhere.
- **No-network guard** in `scripts/validate-skill.py`: CI fails if a network
  primitive (`curl`, `wget`, `urllib`, `socket`, `requests.`, `/dev/tcp`, …)
  appears in any shipped `.sh`/`.py` file — the local-only claim is enforced,
  not asserted. SKILL.md now also instructs the model explicitly to operate
  offline, an instruction that travels into every agent that loads the skill.
- **README:** "Install — works with any agent" matrix and a "Local-only by
  design" section (no telemetry, bounded atomic writes, what stays on-device,
  and the one boundary readmedaddy cannot police — the host agent's own model
  traffic). SECURITY.md documents the guard and the CI action's exact scope.

## [0.1.0] - 2026-07-02

Initial release of the readmedaddy skill: generate or upgrade the best possible
README for a repo by detecting its archetype and ranking candidate sections
through a contextual multi-gate rubric.

### Added

- **Archetype detection.** The skill resolves a repo to exactly one of ten
  archetypes (CLI, library, framework, app/SaaS, infra/devops, data/ML,
  agent-skill/plugin, research, monorepo, internal-tool) from languages,
  entrypoints, and manifests. Detection signals, must-have sections, the right
  visual, and per-archetype exemplars live in `references/archetypes.md`.
- **Contextual multi-gate rubric.** Ten quality gates (hook, identity/trust,
  visual, quickstart, scannability, completeness, credibility, contextual fit,
  community/maintenance, voice) scored 0–5, with weights that shift by archetype
  so a CLI leans on demo and quickstart while a library leans on API usage and
  badges. The rubric and weighting table live in `references/multi-gate-rubric.md`.
- **Generation and ranking.** Candidate sections — or, for high-stakes work, N
  competing whole-README drafts — are generated, ranked through the weighted
  gates, and assembled, grafting the best of the runners-up. Every factual claim
  is verified against the repo before output. See `references/generation-and-ranking.md`.
- **Tournament mode.** An optional judge-panel pass for high-stakes READMEs,
  documented alongside the ranking flow.
- **Famous-README canon.** Curated patterns and per-archetype exemplars
  (Art-of-README, Standard-Readme, makeareadme.com, Best-README-Template, and
  exemplar projects) in `references/famous-readme-patterns.md`.
- **Assets.** A clean ASCII wordmark (`assets/ascii-banner.txt`) and reusable
  badge snippets (`assets/badges.md`) for the visual and identity gates.
- **Eval fixtures and harness** (`skills/readmedaddy/eval/`) — sample repos per
  archetype with expected detection and gate outcomes, run RED→GREEN so behavior
  is tested rather than asserted. First run (2026-07-02) passed every
  pre-registered threshold: 4/4 detection, mean lift +65.7, all fixtures above
  the 70/100 floor — full report in `eval/results/2026-07-02/`.
- **CI** (`.github/workflows/ci.yml`) + `scripts/validate-skill.py`:
  frontmatter and budget checks, relative-link and backtick reference-pointer
  integrity, version consistency (SKILL.md `metadata.version` matches the top
  CHANGELOG entry), the clean-for-publish forbidden-reference guard, shellcheck
  and a hook behavior test on the shell scripts, the installer and scorer
  self-tests (scorer weights mirror the rubric), and markdownlint.
- **Auto-update hook.** A `readme-drift` Claude Code Stop hook
  (`hooks/readme-drift.sh`) that watches a project's signal files — manifests,
  entrypoints, CI, install scripts — and, when they change while the README does
  not, prompts an in-session refresh through the skill. It detects drift and asks;
  it never rewrites files on its own and never breaks a session (it exits clean on
  every path). Modes are `auto` / `notify` / `enforce`, configurable per-project via
  `.readmedaddy.json` or globally via `README_DADDY_HOOK`. Documented in
  `references/auto-update-hook.md`.
- **One-step install.** `install.sh` now copies the skill *and* registers the Stop
  hook (user-global by default; `--no-hook` to skip), wiring it through the
  idempotent `scripts/install-hook.py` settings merger (with `--uninstall`,
  `--dry-run`, and `--selftest`).
- **Hook eval and tests.** Coverage for the drift detector and the installer —
  drift/no-drift cases, mode behavior, cooldown state, and merge idempotency — so
  the hook's behavior is tested rather than asserted.
- **Open-source scaffolding:** README, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT,
  issue and PR templates, and `install.sh` (one-command install into the Claude
  Code skills directory).
