# Changelog

All notable changes to readmedaddy are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
