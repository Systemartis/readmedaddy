# readmedaddy guard: trigger modes, enforcement, and the init wizard

**Status:** approved design, pre-implementation
**Date:** 2026-07-07
**Target release:** v0.3.0

## 1. Overview

readmedaddy today detects README drift on two surfaces: a Claude Code Stop
hook (in-session) and a composite GitHub Action that only handles
`pull_request` events. This design adds the remaining trigger surfaces
(merge-to-main, scheduled sweep, comment command), a graduated enforcement
story (advisory → required check → auto-fix), and a wizard (`init`) that
configures all of it in one sitting and saves the result to
`.readmedaddy.json`.

Guiding invariant, unchanged: **detection is pure local git** — POSIX sh, no
network, no LLM, no telemetry. The LLM-powered auto-fix tier is opt-in,
explicitly priced, and architecturally separated from detection.

### Goals

- A repo can be "guarded" in one command: config + workflow + badge +
  (optionally) a required check.
- Every trigger surface is configurable from one file with one vocabulary.
- The auto-fix tier works with any agent CLI; the Claude path is the
  best-tested default.
- Re-running the wizard reconfigures; it never destroys user edits.

### Non-goals (this release)

- Monorepo / multiple-README support (`targets[]`) — future.
- Machine-owned README blocks (deterministic inject/verify) — future.
- Runnable-quickstart verification (`--exec`) — future.
- Windows-native support (documented as Git Bash/WSL only).

### Prerequisites (Phase 0 — fix before building on top)

Four confirmed defects in the shipped product are sequenced ahead of this
work; they are planned separately and only summarized here:

1. Stop-hook committed-drift fallback over-triggers on fresh installs
   (drop/demote in hook mode; seed cooldown on first sight; cooldown per
   HEAD).
2. Reference files instruct live web checks, contradicting the skill's
   offline mandate (invert the rule; rewrite rubric G2/G7 offline-checkable).
3. README's action snippet is invalid YAML and pins a superseded tag (fix
   snippet; publish moving `@v0` tag; extend `validate-skill.py` with a
   version-pin consistency check).
4. Config misparse resolves to the most intrusive behavior (`"mode":"off"`
   blocks) — folded into the parser hardening below.

## 2. Config schema v2

`.readmedaddy.json` grows a `guard` section. Key names are collision-safe:
the current sh parser greedily matches the last occurrence of `"enabled"`,
`"mode"`, `"readme"`, `"watch"` anywhere in the file, so the new section
must not reuse those names — and the parser is hardened anyway.

```json
{
  "$schema": "https://raw.githubusercontent.com/Systemartis/readmedaddy/main/schema/readmedaddy.schema.json",
  "hook":  { "enabled": true, "mode": "auto", "readme": "README.md", "watch": ["..."] },
  "guard": {
    "pr":    "comment",
    "main":  "issue",
    "sweep": "weekly",
    "autofix": { "runner": "off", "command": "" }
  }
}
```

- `guard.pr`: `off | comment | fail` — PR-event response.
- `guard.main`: `off | issue | fail` — default-branch push response.
  `issue` maintains ONE pinned "README health" dashboard issue (sticky
  marker comment pattern), never issue-per-event.
- `guard.sweep`: `off | weekly` — scheduled re-check; response is the same
  dashboard issue.
- `guard.autofix.runner`: `off | claude | command`. `command` uses
  `guard.autofix.command` verbatim as the agent step. No nested `enabled`
  key, no `mode` key — collision-safe by construction.

Parser hardening (ships with the schema):

- `readme-drift.sh` scopes its key extraction to the `hook` object instead
  of the whole file; unknown `mode` values resolve to **notify + stderr
  warning**, never to blocking; `"off"` is accepted as a mode.
- New `readme-drift.sh --lint-config`: validates JSON well-formedness (via
  python3 when available, degraded sh checks otherwise), known keys, and
  enum values. Exit 0/1/2 contract matches `--check`.
- A published JSON Schema (`schema/readmedaddy.schema.json`) referenced via
  `$schema` in wizard-written configs gives editor validation for free.
- Compatibility: every v1 key keeps parsing forever; migrations live in the
  reader and are never emitted as per-run warnings.

## 3. Trigger surfaces and the action

`action.yml` branches on `github.event_name` instead of hard-skipping
non-PR events:

- `pull_request` (+ `merge_group`): current behavior — `--check --range
  origin/$BASE...HEAD`; `comment` posts/updates one sticky comment and
  **resolves it** (PATCH to a "resolved" body) when a later push fixes the
  drift; `fail` fails the job. Merge-queue events pass through so a
  required check cannot stall queues.
- `push` (default branch): `--check --range $BEFORE...$SHA`, guarding the
  all-zeros SHA (branch creation / force push → fall back to rangeless
  `--check`). Response per `guard.main`.
- `schedule` / `workflow_dispatch`: rangeless `--check` (committed-drift
  logic). Response per `guard.sweep`.
- `issue_comment`: handled by the generated tier-3 workflow, not the
  composite action (see §5).

Robustness fixes shipping with this extension: `--check` with no resolvable
repo root exits 2 (a missing `actions/checkout` must not read as "fresh");
config for PR gating is read from the **base ref** (`git show
origin/$BASE:.readmedaddy.json`) so a PR cannot waive its own gate; sticky
comment lookup uses `--paginate --slurp`; multiline `GITHUB_OUTPUT` uses a
randomized heredoc delimiter.

Default recommendation (wizard default, documented): layered
T1 Stop hook + PR `comment` + `main: issue` + weekly sweep. Escalation to
`fail` + required check is an explicit wizard choice, not the default —
advisory-first matches both the false-positive reality and ecosystem
practice.

## 4. The init wizard

One outcome — `.readmedaddy.json` + optional `.github/workflows/
readmedaddy.yml` + optional badge line — reachable through three faces that
share **one serializer**:

- **Agent-face**: "readmedaddy init" inside any agent with the skill loaded.
  The agent runs the detection pass, asks at most 3 conversational questions
  (nudge mode, CI gate, watch confirmation), states every detected fact as a
  vetoable assumption, then shells to `init --print` + flags. SKILL.md gains
  a short `init` section; the agent never writes the config directly.
- **Script-face**: `scripts/readmedaddy-init.py` (python3-stdlib, same
  dependency envelope as `install-hook.py`; the *detector* stays POSIX sh).
  Numbered menus, Enter = detected default. Every question has a flag
  (`--mode --readme --watch --gate --main --sweep --autofix-runner
  --no-hook --yes --print --apply-required-check`); non-TTY without
  sufficient flags is a hard error naming the missing flags; `--yes` runs
  with zero questions; unknown flags are hard errors.
- **Onboarding PR** (opt-in, needs `gh`): `--onboard` opens a PR adding
  config + workflow + badge. The PR body contains a forecast — a dry-run of
  `--check --range` over the last ~10 merged PRs ("these N would have been
  flagged"). Merging is consent; closing is opt-out.

Flow: silent local detection pass (repo root, README path, default branch,
GitHub remote, monorepo markers, workflow-name collisions, which default
watch patterns match `git ls-files`, existing config → reconfigure mode,
Claude settings / hook registration state), then at most 6 questions:
README path → watch list (pruned proposal, show what was dropped) → nudge
mode → register hook now? → CI gate (cost shown per choice) → enforcement +
autofix + badge. Repo visibility is never detected (needs network); the
plan gate is explained in the printed recipe instead.

Close: npm-init-style preview — print the exact files to be written and the
full side-effect list, confirm, write, then immediately run
`readme-drift.sh --check` and show the live result, then a next-steps
block.

Behavioral rules (binding):

- Touches exactly three artifacts (config, workflow, badge edit) plus the
  optional hook registration — all enumerated in the preview.
- Re-run = reconfigure seeded from current values; never
  overwrite-from-scratch; a template-inherited config must not make init
  unreachable.
- Humor lives in copy only; every offered option is honored.
- The default path makes zero network calls. Only `--apply-required-check`
  and `--onboard` use the user's own `gh` auth, after an explicit
  confirmation naming the side effect.

## 5. Enforcement and tier 3 (auto-fix)

**Required check.** The wizard writes the workflow with a deterministic job
id (`readme-drift`) and, on request, applies a **ruleset** via `gh api`
(`required_status_checks` targeting `~DEFAULT_BRANCH`), offering
`enforcement: evaluate` before `active`. Classic branch protection is never
PUT (it replaces the whole object); if classic must be touched, only the
narrow additive contexts POST is used. Degradation ladder: print recipe
(default) → `--apply` via user's gh → on 403/404 diagnose (not-admin vs
Free-plan-private) and fall back to recipe, optionally `--issue`. Never
silent-skip.

**Team-wide local tier.** The wizard's enforcement step also offers plugin
pinning: a project `.claude/settings.json` with `extraKnownMarketplaces` +
`enabledPlugins` enforces the Stop hook for every Claude Code teammate via
version control. Depends on plugin packaging (below).

**Tier-3 generated workflow** (written by the wizard when
`autofix.runner != off`): triggers on `issue_comment` (`@readmedaddy fix`)
and optionally on default-branch push. Fixed pipeline:

1. Job-level `if:` pre-filter (`author_association` in
   OWNER/MEMBER/COLLABORATOR, never CONTRIBUTOR; bot commenters excluded;
   `[skip readmedaddy]` honored on push).
2. Authoritative permission check (`getCollaboratorPermissionLevel` ≥
   write) **before any checkout**; 👀 reaction as ack.
3. Fork PRs refused outright; checkout pins the resolved head **SHA**.
4. Free drift check first (`--check --range`); exit early with a "nothing
   to fix" comment when fresh — zero LLM spend on fresh READMEs.
5. Skill exposure: `cp -R skills/readmedaddy .claude/skills/` (project
   skills auto-load from the checkout).
6. **Swappable agent block** — the pluggability contract: the agent edits
   the working tree only; no commit, no push, no PR. Default runtime is
   `anthropics/claude-code-action@v1` (`anthropic_api_key` or
   `claude_code_oauth_token`; `--max-turns` as the cost lever); the
   generated file documents drop-in alternatives (opencode, aider
   `--no-auto-commits`, codex, copilot) as comment blocks, and
   `runner: command` substitutes `autofix.command` verbatim. The prompt
   always instructs reading the skill file explicitly so non-Claude
   runtimes behave identically.
7. `peter-evans/create-pull-request` opens/updates the fix PR — idempotent
   by stable branch name (`readmedaddy/fix-<n>`), never reopens a
   human-closed PR, `delete-branch: true`. Default `GITHUB_TOKEN` gives
   structural loop immunity (its PRs trigger no workflows); the no-CI-checks
   trade-off and the PAT/App upgrade are documented in the generated file.
8. 🚀 reaction + comment linking the PR.

The generated workflow warns (in comments) against rewiring onto
`pull_request_target`.

## 6. Plugin packaging

Two new files make the repo a Claude Code plugin: `.claude-plugin/
plugin.json` (name, version — bumped per release) and `hooks/hooks.json`
registering the Stop hook via `${CLAUDE_PLUGIN_ROOT}`. Add
`.claude-plugin/marketplace.json` so `/plugin marketplace add
Systemartis/readmedaddy` works. For Claude users this supersedes
`install-hook.py` (clean uninstall, updates via `/plugin update`);
`install.sh` + `install-hook.py` remain for opencode/copilot. The wizard
and installer must detect the both-installed state (plugin + legacy
settings hook = double firing) and migrate by running
`install-hook.py --uninstall`. To verify during implementation: hook-consent
UX at plugin install; whether project-scope uninstall cleans settings
entries.

## 7. Error handling

- Wizard: any detection failure degrades to asking; any write failure
  aborts before partial state (config written atomically, workflow written
  last); `gh` absence disables (with explanation) only the steps that need
  it.
- Action: exit 2 paths are always loud (`::error::` + guidance); unknown
  events no-op with a log line, never fail.
- Tier-3 workflow: agent-step failure leaves no branch/PR (create-pull-
  request only runs when a diff exists); permission failures comment the
  reason on the PR.

## 8. Testing

- `--lint-config` and the parser hardening get cases in
  `eval/hook/test-readme-drift.sh`, plus the audit-identified gaps that
  this design builds on: committed-drift fallback, notify/enforce modes,
  env overrides, glob-named files, non-ASCII paths, shallow clones,
  missing-repo exit 2.
- Wizard: golden-file tests — given a fixture repo + flag set, assert the
  exact config/workflow written; idempotency test (run twice, identical
  result); reconfigure test (hand-edited key survives).
- Action event matrix: `pull_request`, `merge_group`, `push` (incl.
  all-zeros before-SHA), `schedule` — asserted via the existing dogfood CI
  plus fixture-repo range tests.
- Tier-3: YAML validity (actionlint) + a dry-run mode where the agent step
  is stubbed by a script that touches the README, asserting the PR
  mechanics end-to-end without LLM spend.
- CI runs the shell + python jobs on ubuntu and macos.

## 9. Implementation order

1. Phase 0 defect fixes (§1 prerequisites) + test-harness gaps.
2. Config schema v2 + parser hardening + `--lint-config` + JSON Schema.
3. Action event expansion + robustness fixes (§3).
4. Wizard script-face + agent-face + badge; onboarding PR mode.
5. Tier-3 generated workflow (Claude path tested end-to-end; alternates
   documented).
6. Plugin packaging + migration detection.
7. Enforcement recipes/`--apply` + team pinning docs.

Each phase lands independently shippable; the wizard is useful after
phase 4 even if 5–7 slip.
