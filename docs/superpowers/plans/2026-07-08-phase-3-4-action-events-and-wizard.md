# Phase 3–4: Action Event Expansion + Init Wizard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The GitHub Action handles every event class the detector supports (PR, merge queue, push-to-main, schedule) reading config from the base ref, and a wizard (`readmedaddy-init.py`) configures the whole system in one sitting.

**Architecture:** Phase 3 is `action.yml` + the dogfood CI workflow only — every decision the action makes goes through `readme-drift.sh --check/--print-config --config` (already tested at 44 cases); the action's bash stays thin glue. Phase 4 adds `scripts/readmedaddy-init.py` (python3-stdlib, same envelope as `install-hook.py`), an `init` section in SKILL.md (agent-face), and `install.sh --uninstall`. All wizard writes are atomic; the default path makes zero network calls.

**Tech Stack:** GitHub Actions composite (bash), python3 stdlib, POSIX sh. Verification: the 44-case harness, `shellcheck`, `validate-skill.py`, new `readmedaddy-init.py --selftest`, `python3 -m py_compile`.

**Spec:** `docs/superpowers/specs/2026-07-07-guard-trigger-modes-and-init-wizard-design.md` §3, §4, plus `install.sh --uninstall` (maintainer-requested corporate-clean removal; extends spec §6's uninstall story to the script installer).

**Deferred to phases 5–7 (do NOT build here):** `readmedaddy-fix.yml` generation (wizard's autofix picker only writes config), ruleset `--apply`/`--issue` (wizard prints the recipe), plugin packaging, and the `--onboard` onboarding-PR mode (spec places it in phase 4, but it needs `gh` + network and the forecast mechanics — deferred to the 5–7 plan so this phase stays zero-network end to end; the flag exists and prints the recipe + a "coming in v0.3.x" note).

---

### Task 1: action.yml — event branching + base-ref config

**Files:** Modify `action.yml` (check step), `skills/readmedaddy/references/auto-update-hook.md` (PR-gate paragraph)

Behavior contract (spec §3):

- `pull_request`: as today, plus: extract base config `git show origin/$BASE_REF:.readmedaddy.json > $RUNNER_TEMP/rmd-config.json` (missing → use `/dev/null`), pass `--config` ALWAYS; gate mode precedence: config `guard.pr` > legacy `mode:` input > default `comment`. **Presence mechanism (new detector flag, ships first in this task):** `--print-config KEY --raw` prints the raw configured value and an EMPTY line when the key is absent (no default substitution) — presence becomes observable through the one parser, no grep. Add one harness case for `--raw` (present → value, absent → empty, still exit 0); harness count becomes 45 — later steps say "full harness", not a number.
- `merge_group`: range `${{ github.event.merge_group.base_sha }}...${{ github.event.merge_group.head_sha }}`; base config from `git show <base_sha>:.readmedaddy.json`; must always report — `comment` degrades to step summary + pass; `fail` fails the job.
- `push`: only meaningful on the default branch (workflow trigger limits it); range `$BEFORE...$SHA`; if `$BEFORE` is all-zeros (branch create/force push) fall back to rangeless `--check`; response per `guard.main` (`off` → skip silently; `issue` → dashboard issue (Task 2); `fail` → fail job). Config from the working tree (the pushed commit IS the source of truth on main).
- `schedule` / `workflow_dispatch`: rangeless `--check`; response per `guard.sweep` (`weekly`/`off` — the schedule itself lives in the consumer's workflow file; the action only decides reporting). Response = same dashboard issue.
- any other event: log a line, emit `drift=false`, exit 0.
- Robustness (all events): missing checkout → the detector's new exit 2 propagates as a failed step with `::error::` guidance; shallow-clone exit 2 likewise.

- [ ] Step 1: rewrite the `check` step with an `EVENT` case statement implementing the table above (keep `set -u`; keep outputs `drift`/`files` exactly — downstream contract).
- [ ] Step 2: randomized heredoc delimiter for the multiline `files` output: `d="RMD_$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"` (od is POSIX; no openssl dependency).
- [ ] Step 3: verify the YAML: `actionlint` if installed (expression-aware shellcheck of run blocks); otherwise copy each run block to a temp file with `${{ }}` expressions replaced by dummy values and `bash -n` it; record the command used.
- [ ] Step 4: update auto-update-hook.md's PR-gate paragraph: the action now also handles merge queues, pushes to the default branch, and scheduled sweeps, configured via `guard.*`.
- [ ] Step 5: commit `feat(action): event branching — merge queues, push-to-main, scheduled sweeps, base-ref config`.

### Task 2: action.yml — sticky-comment resolution + dashboard issue + pagination fix

**Files:** Modify `action.yml` (gate step + new resolve/issue steps)

- [ ] Step 1: **comment resolution** — on `pull_request` with `drift=false`: find the marker comment (`<!-- readmedaddy-drift -->`), and if present PATCH it to a short "✅ resolved — the README was updated alongside the code" body. Keep silent when no marker comment exists. Wrap in the same `set +e` degrade as the gate step — the PATCH fails on fork PRs' read-only token, and resolution is cosmetic.
- [ ] Step 2: **pagination fix** — every `gh api ... --paginate --jq` lookup gains `--slurp` and a flattened jq program (`add | map(select(...)) | .[0].id` guarded for null).
- [ ] Step 3: **dashboard issue** — for `push` events when `guard.main == issue`, and `schedule`/`workflow_dispatch` events when `guard.sweep == weekly`: find the open issue whose body starts with `<!-- readmedaddy-dashboard -->` (jq must add `select(.pull_request == null)` — the issues API returns PRs too); create it ("readmedaddy: README health") or update its body: marker, last-check timestamp, current drifted files (or "fresh"), the waive/config escape hatches. One pinned issue, updated in place, never issue-per-event. Close nothing automatically. Token failures degrade to `::warning::` + step summary exactly like comment mode does today.
- [ ] Step 4: commit `feat(action): resolve sticky comments, README-health dashboard issue, --slurp pagination`.

### Task 3: dogfood CI — merge_group + macOS matrix + guard config

**Files:** Modify `.github/workflows/ci.yml`; create `.readmedaddy.json` (repo root)

- [ ] Step 1: add `merge_group:` to ci.yml's `on:`; widen the drift job's `if:` to `contains(fromJSON('["pull_request","merge_group"]'), github.event_name)`.
- [ ] Step 2: `strategy: matrix: os: [ubuntu-latest, macos-latest]` on the shell-test and python jobs (spec §8).
- [ ] Step 3: dogfood B5 — repo-root `.readmedaddy.json`: `$schema`, watch list = the default pruned to what exists here PLUS `action.yml` and `schema/**`; `guard.pr: comment`.
- [ ] Step 4: run the full local suite (harness 44, shellcheck, validator, `--lint-config` on the new root config) and commit `feat(ci): merge-queue trigger, macOS matrix, dogfooded guard config`.

### Task 4: wizard — `scripts/readmedaddy-init.py`

**Files:** Create `scripts/readmedaddy-init.py`; modify `skills/readmedaddy/references/auto-update-hook.md` (install section pointer)

Contract (spec §4 — binding):

- **Detection pass (zero questions, zero network):** repo root (`git rev-parse`), README path (`git ls-files` case-insensitive match, prefer README.md), default branch (`symbolic-ref refs/remotes/origin/HEAD` → `init.defaultBranch` → main/master by ref existence), GitHub remote (`remote get-url origin` contains github.com), monorepo markers (pnpm-workspace.yaml, "workspaces" in package.json, lerna.json, go.work, turbo.json), existing workflow-name collisions in `.github/workflows/`, pruned watch proposal (default list filtered by `git ls-files` matches, manifests kept when present), existing `.readmedaddy.json` → **reconfigure mode** (defaults seeded from current values), Claude environment (skill dir exists? Stop hook registered? — reuse `install-hook.py` probe logic by import).
- **Questions (≤6, numbered menus, Enter=default):** README path → watch list (Y/edit/full) → nudge mode (auto/notify/enforce/off) → register hook now? (only if Claude settings detected & not registered) → CI gate (comment/fail/skip, only if GitHub remote; show cost line) → enforcement+autofix+badge (recipe print default; autofix runner off/claude/command with token-cost statement; badge Y/n).
- **Flags (complete set, each maps to one question):** `--mode --readme --watch --pr` (alias `--gate`) `--main --sweep --autofix-runner --autofix-command --badge/--no-badge --no-hook --yes --print --apply-required-check --onboard`. Non-TTY without enough flags → exit 2 naming the missing flags. Unknown flag → exit 2. `--yes` = all defaults, zero questions. `--print` → config JSON to stdout, write nothing. `--apply-required-check` and `--onboard` in THIS phase print "coming in v0.3.x — here is the recipe" + the ruleset recipe text (phase 7 wires the apply).
- **Writes (each opt-in, all enumerated in a preview, confirm before writing):** `.readmedaddy.json` (atomic tmp+rename, `$schema` first key, guard section, collision-safe names), `.github/workflows/readmedaddy.yml` (complete workflow: `pull_request` + `merge_group` + `push: branches: [<default>]` + `schedule` (weekly cron on a non-:00 minute) as chosen; job id `readme-drift`; `fetch-depth: 0`; pinned `Systemartis/readmedaddy@v0`; **`permissions: {contents: read, pull-requests: write, issues: write}`** — without it comment/issue modes degrade to warnings on every run), one badge line into the README (workflow-status badge, inserted after the first heading), hook registration via `install-hook.py`.
- **`--yes` exact output (the spec's recommended preset, NOT the detector's absent-key defaults):** `guard: {"pr": "comment", "main": "issue", "sweep": "weekly", "autofix": {"runner": "off", "command": ""}}`, `hook.mode: auto`, detected readme/watch; hook registration defaults to YES when Claude settings are detected and the hook is absent; badge defaults to YES. The detector's `--print-config` defaults (`main=off`, `sweep=off`) are the no-config behavior — the wizard's job is to opt you into the layered preset.
- **Error handling (spec §7, binding):** detection failure degrades to asking; any write failure aborts before partial state (config atomic-first, workflow written last); `gh` absence disables (with explanation) only the steps that need it.
- **Close:** print preview → confirm → write → run `readme-drift.sh --check` live and show the result → next-steps block.
- **Re-run = reconfigure** seeded from existing config; never overwrite-from-scratch; hand-edited keys survive untouched categories.
- **`--selftest`:** temp-repo golden tests: (1) `--yes --print` emits valid JSON that `--lint-config` accepts; (2) run twice → byte-identical config (idempotency); (3) reconfigure preserves a hand-edited watch entry when only `--mode` changes; (4) non-TTY without flags exits 2 naming flags; (5) unknown flag exits 2; (6) `--print` writes nothing to disk. Zero network throughout (assert no socket import).

- [ ] Step 1: implement (single file, stdlib only: argparse/json/os/re/subprocess/sys/tempfile; `subprocess` runs `git`/`python3 install-hook.py` only — the no-network guard scans for primitives, subprocess is fine). To reuse `install-hook.py` (hyphenated name — plain `import` fails): load via `importlib.util.spec_from_file_location`, or shell out to it; do not rename the file.
- [ ] Step 2: `python3 -m py_compile scripts/readmedaddy-init.py` + `python3 scripts/readmedaddy-init.py --selftest` → PASS.
- [ ] Step 3: manual smoke in a /tmp repo: `--yes` writes config+workflow, `--lint-config` passes, second `--yes` run idempotent.
- [ ] Step 4: add a CI step running `--selftest` in the python job.
- [ ] Step 5: commit `feat(wizard): readmedaddy-init — detect-then-confirm setup, flags for CI, atomic writes, selftest`.

### Task 5: agent-face — SKILL.md `init` section

**Files:** Modify `skills/readmedaddy/SKILL.md`

- [ ] Step 1: add a compact `## init — guard a repo` section (keep it <25 lines; SKILL.md token budget matters): trigger phrases ("readmedaddy init", "guard this repo", "set up readmedaddy"); instructions: run the Step-0 detection commands, ask ≤3 questions conversationally (nudge mode, CI gate, watch confirmation) stating detected facts as vetoable assumptions, then **two-step through the script (the single serializer)**: run `readmedaddy-init.py --print` with every answer as a flag → show the user the output as the preview → on approval re-run the same flags without `--print` to write. Never write config JSON directly.
- [ ] Step 2: `python3 scripts/validate-skill.py` still OK (description length, links).
- [ ] Step 3: commit `feat(skill): init section — the agent face of the guard wizard`.

### Task 6: `install.sh --uninstall`

**Files:** Modify `install.sh`, `README.md` (uninstall section)

- [ ] Step 1: add `--uninstall`: removes the three default skill dirs (or `$DEST/readmedaddy` when DEST set), then `python3 scripts/install-hook.py --uninstall` when python3 exists (else prints the manual settings.json instruction). Prints every path it removed; removes nothing outside those dirs. Also guard the install path: `command -v python3` before hook registration; on absence print guidance + exit 0 (audit fix, one line).
- [ ] Step 2: round-trip test in a sandbox HOME: `HOME=$tmp ./install.sh && HOME=$tmp ./install.sh --uninstall` → skill dirs gone, settings.json restored, exit 0.
- [ ] Step 3: README "Uninstall" subsection: one command, what it removes, nothing else touched.
- [ ] Step 4: commit `feat(install): --uninstall — one command removes every installed artifact`.

### Task 7: wrap — CHANGELOG + full suite

- [ ] Step 1: extend `[Unreleased]` Added: action event matrix, dashboard issue, comment resolution, wizard, SKILL init section, install.sh --uninstall, dogfooded guard config, macOS CI.
- [ ] Step 2: full suite: harness 44/44, shellcheck, validator, install-hook selftest, init selftest, root-config lint.
- [ ] Step 3: commit `docs: changelog for action events + wizard`.
