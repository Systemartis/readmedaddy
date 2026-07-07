# Phase 1–2: Detector Hardening + Config Schema v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the four shipped Phase-0 defects (hook over-nagging, offline-mandate contradiction, broken README action snippet, config misparse) plus four confirmed detector correctness bugs, then land config schema v2 with a hardened parser, `--config`/`--print-config`/`--lint-config` flags, and a published JSON Schema.

**Architecture:** All detector work happens inside `skills/readmedaddy/hooks/readme-drift.sh` (POSIX sh, shellcheck-clean, no bashisms, no network) with tests-first additions to `skills/readmedaddy/eval/hook/test-readme-drift.sh`. Doc fixes touch `README.md` and two reference files. The validator (`scripts/validate-skill.py`, python3-stdlib) gains one new numbered section. Nothing here touches `action.yml` (that is phase 3).

**Tech Stack:** POSIX sh, git, python3 stdlib. Test harness: `sh skills/readmedaddy/eval/hook/test-readme-drift.sh` (throwaway repos under mktemp; PASS/FAIL lines; nonzero exit on failure). Lint: `shellcheck skills/readmedaddy/hooks/readme-drift.sh` must stay clean. Validator: `python3 scripts/validate-skill.py`.

**Spec:** `docs/superpowers/specs/2026-07-07-guard-trigger-modes-and-init-wizard-design.md` (§1 Phase 0, §2 Config schema v2, §8 Testing).

**Conventions for this plan:**
- Test letters continue the harness's existing sequence (`(a)…(p)` plus `(i2)` — **17 cases today**): new cases are `(q)…(aq)`.
- `committed_drift` compares commit timestamps with second granularity and strict `-gt` — back-to-back commits in a test share `%ct` and never register as drift. Every test commit that must read as *newer* sets an explicit future committer date: `GIT_COMMITTER_DATE="@$(($(date +%s)+60)) +0000" GIT_AUTHOR_DATE="@$(($(date +%s)+60)) +0000" git -C "$d" commit …` (bump the offset by +60 per successive commit in the same test).
- `readme-drift.sh` line numbers below refer to the file as of commit `10cb52f`; they shift as tasks land — always locate edits by the quoted anchor text, not the number.
- Every task ends by running the full harness + shellcheck. Commit per task.
- Work on a branch: `git checkout -b feat/v0.3.0-phase-1-2` before Task 1.

---

### Task 1: Characterization tests for modes and env overrides (baseline lock)

The emission logic changes in Tasks 2 and 9. First, lock the CURRENT correct behavior of `notify`/`enforce` modes and `README_DADDY_HOOK` overrides so regressions surface immediately. These tests must pass unchanged against today's code.

**Files:**
- Modify: `skills/readmedaddy/eval/hook/test-readme-drift.sh` (insert before the `printf '\n--- summary'` line)

- [ ] **Step 1: Add the test cases**

Insert before the summary block:

```sh
# --- modes and env overrides (characterization: current documented behavior) ---

# (q) NOTIFY mode: stderr message, empty stdout, state recorded.
# ONE invocation capturing both streams — notify records cooldown state, so a
# second run would be silent on stderr and a two-invocation capture mis-fails.
d=$(setup_repo)
printf '{"hook":{"mode":"notify"}}\n' >"$d/.readmedaddy.json"
git -C "$d" add -A && git -C "$d" commit -qm cfg
printf '{"name":"x","v":2}\n' >"$d/package.json"
out=$( (cd "$d" && printf '%s' "$STDIN_CONT_FALSE" | sh "$HOOK" 2>"$d/.err.txt") )
errout=$(cat "$d/.err.txt")
if [ -z "$out" ] && printf '%s' "$errout" | grep -q 'readmedaddy:'; then
	note ok "NOTIFY mode is stderr-only"
else
	note fail "NOTIFY expected empty stdout + stderr message (out: $out | err: $errout)"
fi

# (r) ENFORCE mode: blocks on every Stop (no cooldown recording).
d=$(setup_repo)
printf '{"hook":{"mode":"enforce"}}\n' >"$d/.readmedaddy.json"
git -C "$d" add -A && git -C "$d" commit -qm cfg
printf '{"name":"x","v":2}\n' >"$d/package.json"
out1=$(run_hook "$d" "$STDIN_CONT_FALSE")
out2=$(run_hook "$d" "$STDIN_CONT_FALSE")
enforce_ok=1
case "$out1" in *'"decision":"block"'*) : ;; *) enforce_ok=0 ;; esac
case "$out2" in *'"decision":"block"'*) : ;; *) enforce_ok=0 ;; esac
if [ "$enforce_ok" = 1 ]; then
	note ok "ENFORCE blocks on every Stop"
else
	note fail "ENFORCE expected block twice (got1: $out1 | got2: $out2)"
fi

# (s) ENV off: README_DADDY_HOOK=off silences hook mode even with drift.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
out=$( (cd "$d" && printf '%s' "$STDIN_CONT_FALSE" | README_DADDY_HOOK=off sh "$HOOK") )
if [ -z "$out" ]; then
	note ok "ENV off silences hook mode"
else
	note fail "ENV off should be silent (got: $out)"
fi

# (t) ENV notify overrides config auto; --check ignores ENV off.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
out=$( (cd "$d" && printf '%s' "$STDIN_CONT_FALSE" | README_DADDY_HOOK=notify sh "$HOOK" 2>/dev/null) )
(cd "$d" && README_DADDY_HOOK=off sh "$HOOK" --check >/dev/null 2>&1)
rc=$?
if [ -z "$out" ] && [ "$rc" = 1 ]; then
	note ok "ENV notify forces stderr-only; --check ignores ENV off"
else
	note fail "ENV override expected empty stdout + check rc=1 (out: $out, rc=$rc)"
fi
```

- [ ] **Step 2: Run the harness — all cases including the new four must PASS**

Run: `sh skills/readmedaddy/eval/hook/test-readme-drift.sh`
Expected: `--- summary: 21 passed, 0 failed ---` (17 existing + 4 new). If any new case fails, the test encodes a wrong expectation — fix the TEST (this task changes no hook behavior).

- [ ] **Step 3: Commit**

```bash
git add skills/readmedaddy/eval/hook/test-readme-drift.sh
git commit -m "test(hook): characterize notify/enforce modes and README_DADDY_HOOK overrides"
```

---

### Task 2: A1 — stop the fresh-install nag (seeded cooldown, per-HEAD signature)

Behavior change (spec §1.1): (1) the cooldown signature becomes `<HEAD>|<drift-class>` (`wt` or `committed`) instead of `<HEAD>|<file-list>`, so newly-dirtied files at the same HEAD no longer re-arm the nag; (2) on the FIRST sight of a repo (no state file) where the only drift is committed drift (clean tree), `auto` and `notify` modes record state and exit silently — pre-existing staleness never greets a fresh install. `enforce` mode is exempt (explicitly aggressive). Working-tree drift on first sight still fires (that is real in-session drift).

**Files:**
- Modify: `skills/readmedaddy/hooks/readme-drift.sh` (cooldown section, anchor: `# (h) Cooldown: signature of the current drift.`)
- Modify: `skills/readmedaddy/eval/hook/test-readme-drift.sh`
- Modify: `skills/readmedaddy/references/auto-update-hook.md` (Loop safety section)

- [ ] **Step 1: Write the failing tests**

Insert before the summary block:

```sh
# --- A1: fresh-install seeding + per-HEAD cooldown ---

# (u) FRESH-INSTALL: committed drift only, no state file -> silent, state seeded.
# The drift commit gets a +60s committer date: %ct is second-granular and
# committed_drift needs strictly-newer to register (see plan conventions).
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
GIT_COMMITTER_DATE="@$(($(date +%s)+60)) +0000" GIT_AUTHOR_DATE="@$(($(date +%s)+60)) +0000" \
	git -C "$d" commit -qam "bump manifest"              # committed drift, clean tree
out=$(run_hook "$d" "$STDIN_CONT_FALSE")
if [ -z "$out" ] && [ -f "$d/.git/readmedaddy-state" ]; then
	note ok "FRESH-INSTALL committed drift is seeded silently"
else
	note fail "FRESH-INSTALL expected silence + seeded state (got: $out)"
fi

# (v) POST-SEED: a NEW commit touching a watched file fires exactly once.
printf '{"name":"x","v":3}\n' >"$d/package.json"
GIT_COMMITTER_DATE="@$(($(date +%s)+120)) +0000" GIT_AUTHOR_DATE="@$(($(date +%s)+120)) +0000" \
	git -C "$d" commit -qam "bump again"
out1=$(run_hook "$d" "$STDIN_CONT_FALSE")
out2=$(run_hook "$d" "$STDIN_CONT_FALSE")
seed_ok=1
case "$out1" in *'"decision":"block"'*) : ;; *) seed_ok=0 ;; esac
[ -n "$out2" ] && seed_ok=0
if [ "$seed_ok" = 1 ]; then
	note ok "POST-SEED new committed drift blocks once, then silent"
else
	note fail "POST-SEED expected block then silence (got1: $out1 | got2: $out2)"
fi

# (w) PER-HEAD: second dirty watched file at the same HEAD does NOT re-fire.
d=$(setup_repo)
mkdir -p "$d/src"
printf 'a\n' >"$d/src/a.js"
git -C "$d" add -A && git -C "$d" commit -qm src
printf 'a2\n' >"$d/src/a.js"
out1=$(run_hook "$d" "$STDIN_CONT_FALSE")
printf 'b\n' >"$d/src/b.js"
out2=$(run_hook "$d" "$STDIN_CONT_FALSE")
perhead_ok=1
case "$out1" in *'"decision":"block"'*) : ;; *) perhead_ok=0 ;; esac
[ -n "$out2" ] && perhead_ok=0
if [ "$perhead_ok" = 1 ]; then
	note ok "PER-HEAD cooldown: new dirty file at same HEAD stays silent"
else
	note fail "PER-HEAD expected block then silence (got1: $out1 | got2: $out2)"
fi

# (x) ENFORCE is exempt from seeding: fresh repo, committed drift -> still blocks.
d=$(setup_repo)
printf '{"hook":{"mode":"enforce"}}\n' >"$d/.readmedaddy.json"
git -C "$d" add -A && git -C "$d" commit -qm cfg
printf '{"name":"x","v":2}\n' >"$d/package.json"
GIT_COMMITTER_DATE="@$(($(date +%s)+60)) +0000" GIT_AUTHOR_DATE="@$(($(date +%s)+60)) +0000" \
	git -C "$d" commit -qam "bump manifest"
out=$(run_hook "$d" "$STDIN_CONT_FALSE")
case "$out" in
*'"decision":"block"'*) note ok "ENFORCE exempt from first-sight seeding" ;;
*) note fail "ENFORCE fresh committed drift should block (got: $out)" ;;
esac

# (y) --check is unaffected by seeding: committed drift still exits 1.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
GIT_COMMITTER_DATE="@$(($(date +%s)+60)) +0000" GIT_AUTHOR_DATE="@$(($(date +%s)+60)) +0000" \
	git -C "$d" commit -qam "bump manifest"
(cd "$d" && sh "$HOOK" --check >/dev/null 2>&1)
rc=$?
if [ "$rc" = 1 ]; then
	note ok "CHECK still reports committed drift (no seeding in check mode)"
else
	note fail "CHECK committed drift expected rc=1 (rc=$rc)"
fi
```

- [ ] **Step 2: Run — (u), (v), (w) must FAIL; (x), (y) must PASS**

Run: `sh skills/readmedaddy/eval/hook/test-readme-drift.sh`
Expected: `(u)` FAILS (current code blocks on fresh committed drift), `(w)` FAILS (current signature includes the file list). `(v)`, `(x)`, `(y)` may already pass — that's fine; they pin the fix's boundaries.

- [ ] **Step 3: Implement**

In `readme-drift.sh`, replace (anchor `# (h) Cooldown`):

```sh
files_sig=$(printf '%s' "$signal_files" | sort -u | tr '\n' ',')
signature="$head_sha|$files_sig"
```

with:

```sh
# Drift class: working-tree edits vs committed-only drift. The signature is
# HEAD + class (NOT the file list): dirtying a second watched file mid-session
# is the same drift event, not a new nag.
if [ -n "$dirty_watched" ]; then
	drift_class=wt
else
	drift_class=committed
fi
signature="$head_sha|$drift_class"
```

Then, immediately after the `stored=$(cat "$state_file" 2>/dev/null)` / `if [ "$stored" = "$signature" ]` block, insert:

```sh
# First sight of this repo (no state yet) + only committed drift = pre-existing
# staleness from before the hook was installed. Seed the cooldown silently so a
# fresh install never opens with a nag. enforce mode is exempt on purpose.
if [ ! -f "$state_file" ] && [ "$drift_class" = committed ] && [ "$mode" != enforce ]; then
	record_state
	exit 0
fi
```

Note: `record_state` is currently defined AFTER this point in the file — move the `record_state()` function definition up, directly below the `case "$git_dir"` block that computes `state_file`, so it is defined before first use.

- [ ] **Step 4: Run tests — all PASS**

Run: `sh skills/readmedaddy/eval/hook/test-readme-drift.sh`
Expected: all cases pass, including the pre-existing `(f)` COOLDOWN case (same working-tree drift → same `wt` signature → still silent on second run).

- [ ] **Step 5: shellcheck**

Run: `shellcheck skills/readmedaddy/hooks/readme-drift.sh`
Expected: no output.

- [ ] **Step 6: Update the docs to match**

In `skills/readmedaddy/references/auto-update-hook.md`, Loop safety section: replace the cooldown sentence describing the signature ("the short HEAD sha plus the sorted set of dirty watched files") with the new contract:

```markdown
- **Cooldown state:** the hook writes a signature of the drift it just handled —
  the short HEAD sha plus the drift class (working-tree or committed) — to
  `.git/readmedaddy-state`. Dirtying more watched files at the same HEAD is the
  same drift event: one nudge per HEAD, not one per file. A new commit is what
  re-arms it. On the **first** run in a repo where the only drift predates the
  hook (clean tree, stale README from before install), the hook seeds this state
  silently instead of nagging — a fresh install never opens with a complaint
  about history it didn't witness. (`enforce` mode skips both the seeding and
  the recording, so it re-prompts until the README moves.)
```

Also fix the stale header comment in `readme-drift.sh` line ~18: change `no writes outside .readmedaddy/state (hook-mode cooldown only)` to `no writes outside .git/readmedaddy-state (hook-mode cooldown only)` (confirmed doc-drift finding; we are editing this file anyway).

- [ ] **Step 7: Commit**

```bash
git add skills/readmedaddy/hooks/readme-drift.sh skills/readmedaddy/eval/hook/test-readme-drift.sh skills/readmedaddy/references/auto-update-hook.md
git commit -m "fix(hook): seed cooldown on first sight, key per HEAD+class — fresh installs never open with a nag"
```

---

### Task 3: Glob-named files can mask all drift (set -f discipline)

Confirmed bug: the porcelain loop runs `for pp in $ppaths` with pathname expansion ON, so an untracked file literally named `README.m?` glob-expands to `README.md`, sets `readme_dirty=1`, and silences ALL drift. Additionally `match_watch` and `committed_drift` unconditionally `set +f` on exit, re-enabling globbing even for callers that had it off.

**Files:**
- Modify: `skills/readmedaddy/hooks/readme-drift.sh`
- Modify: `skills/readmedaddy/eval/hook/test-readme-drift.sh`

- [ ] **Step 1: Write the failing test**

```sh
# (z) GLOB-NAMED FILE must not mask drift: untracked 'README.m?' expands to
# README.md under pathname expansion and silences everything (the bug).
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
touch "$d/README.m?"
out=$( (cd "$d" && sh "$HOOK" --check 2>/dev/null) )
rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'package.json'; then
	note ok "GLOB-NAMED file does not mask drift"
else
	note fail "GLOB-NAMED expected rc=1 naming package.json (rc=$rc, out: $out)"
fi
```

- [ ] **Step 2: Run — (z) must FAIL** (current rc=0: the glob-named file masks the drift)

- [ ] **Step 3: Implement**

Three edits in `readme-drift.sh`:

1. `match_watch()` — replace the unconditional `set -f` / `set +f` pairs with save/restore. There are **five** `set +f` occurrences in the function (four in the return-0 arms — the `*/'**'`, `'**/'*`, `*'**'*`, and plain-glob cases — plus one before `return 1`); replace ALL of them, and verify with `grep -c 'set +f'` on the function body afterwards. At function start (anchor `mw_old=$IFS`):

```sh
	mw_old=$IFS
	case $- in *f*) mw_had_f=1 ;; *) mw_had_f=0 ;; esac
	set -f
```

and replace every one of the five `set +f` inside `match_watch` with:

```sh
	[ "$mw_had_f" = 0 ] && set +f
```

2. `committed_drift()` — same pattern: capture `cd_had_f` next to `cd_old=$IFS`, replace its `set +f` with `[ "$cd_had_f" = 0 ] && set +f`.

3. Wrap the porcelain while-loop AND the `--range` while-loop in `set -f` … `set +f`: add `set -f` on the line before `while IFS= read -r pline; do` (porcelain) and before `while IFS= read -r rc_path; do` (range block); add `set +f` immediately after each loop's closing `EOF` heredoc terminator line.

- [ ] **Step 4: Run tests — all PASS.** Then: `shellcheck skills/readmedaddy/hooks/readme-drift.sh` — clean. (shellcheck will not flag `[ "$mw_had_f" = 0 ] && set +f`; if it warns SC2015-style, convert to an `if`.)

- [ ] **Step 5: Commit**

```bash
git add skills/readmedaddy/hooks/readme-drift.sh skills/readmedaddy/eval/hook/test-readme-drift.sh
git commit -m "fix(hook): disable pathname expansion around porcelain/range loops — glob-named files can no longer mask drift"
```

---

### Task 4: Non-ASCII paths (core.quotePath) + shallow clones + missing-repo exit 2

Three confirmed `--check`-mode bugs, one task (they share test plumbing):
(a) `git diff --name-only` C-quotes non-ASCII paths (`"src/na\303\257ve.js"`), defeating watch matching in `--range` mode; (b) depth-1 clones make the committed-drift timestamps equal, so clean-tree `--check` always exits 0; (c) `--check` outside a git repo exits 0 — a missing `actions/checkout` reads as "fresh".

**Files:**
- Modify: `skills/readmedaddy/hooks/readme-drift.sh`
- Modify: `skills/readmedaddy/eval/hook/test-readme-drift.sh`
- Modify: `skills/readmedaddy/references/auto-update-hook.md` (honesty note)

- [ ] **Step 1: Write the failing tests**

```sh
# (aa) NON-ASCII watched path matches in --range mode (quotePath off).
d=$(setup_repo)
mkdir -p "$d/src"
naive="$d/src/na$(printf '\303\257')ve.js"
printf 'x\n' >"$naive"
git -C "$d" add -A && git -C "$d" commit -qm unicode
base=$(git -C "$d" rev-parse HEAD)
printf 'y\n' >"$naive"
git -C "$d" commit -qam "bump unicode file"
(cd "$d" && sh "$HOOK" --check --range "$base..HEAD" >/dev/null 2>&1)
rc=$?
if [ "$rc" = 1 ]; then
	note ok "RANGE matches non-ASCII watched paths"
else
	note fail "RANGE non-ASCII expected rc=1 (rc=$rc)"
fi

# (ab) SHALLOW clone: clean-tree --check exits 2 loudly, never a silent 0.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
git -C "$d" commit -qam "bump manifest"
shal=$(mktemp -d "$TMPROOT/shallow.XXXXXX")
git clone -q --depth 1 "file://$d" "$shal/clone" 2>/dev/null
(cd "$shal/clone" && sh "$HOOK" --check >/dev/null 2>&1)
rc=$?
if [ "$rc" = 2 ]; then
	note ok "SHALLOW clean-tree --check exits 2"
else
	note fail "SHALLOW --check expected rc=2 (rc=$rc)"
fi

# (ac) NOT-A-REPO: --check outside git exits 2 (hook mode stays silent 0).
d=$(mktemp -d "$TMPROOT/norepo.XXXXXX")
printf 'readme\n' >"$d/README.md"
(cd "$d" && sh "$HOOK" --check >/dev/null 2>&1)
rc=$?
if [ "$rc" = 2 ]; then
	note ok "CHECK outside a git repo exits 2"
else
	note fail "CHECK outside git expected rc=2 (rc=$rc)"
fi
```

- [ ] **Step 2: Run — all three must FAIL** ((aa) rc=0 because the quoted path never matches `src/**`; (ab) rc=0 equal timestamps; (ac) rc=0 silent).

- [ ] **Step 3: Implement**

1. quotePath: change the five git read commands to disable quoting —
   - `git -C "$root" diff --name-only "$RANGE"` → `git -C "$root" -c core.quotePath=false diff --name-only "$RANGE"`
   - `git -C "$root" status --porcelain` → `git -C "$root" -c core.quotePath=false status --porcelain`
   - all **three** `git -C "$root" log -1 …` calls in `committed_drift` (`cd_readme_ct`, `cd_watched_ct`, `cd_files`) get `-c core.quotePath=false` likewise — `cd_files` (`--name-only`) is the load-bearing one, it emits the paths that get matched.
   Keep the existing surrounding-quote strip in the porcelain loop (control characters are still quoted).
2. Missing repo: in the root-resolution block (anchor `root=$(git rev-parse --show-toplevel`):

```sh
if [ -z "$root" ]; then
	if [ "$CHECK_MODE" = 1 ]; then
		printf 'readmedaddy --check: not inside a git repository (missing actions/checkout?)\n' >&2
		exit 2
	fi
	exit 0
fi
```

3. Shallow guard: in the signal computation (anchor `signal_files=$(committed_drift)`), replace:

```sh
if [ -n "$dirty_watched" ]; then
	signal_files=$dirty_watched
else
	signal_files=$(committed_drift)
fi
```

with:

```sh
if [ -n "$dirty_watched" ]; then
	signal_files=$dirty_watched
else
	if [ "$CHECK_MODE" = 1 ] && [ "$(git -C "$root" rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then
		printf 'readmedaddy --check: shallow clone — committed-drift comparison needs full history (use fetch-depth: 0)\n' >&2
		exit 2
	fi
	signal_files=$(committed_drift)
fi
```

- [ ] **Step 4: Run tests — all PASS; shellcheck clean.**

- [ ] **Step 5: Soften the honesty note**

In `skills/readmedaddy/references/auto-update-hook.md` (anchor `## Honesty note`), replace the quoted-path ceiling paragraph with:

```markdown
Known ceiling: paths containing control characters are still compared in git's
quoted form and may be mis-detected. Non-ASCII paths (accents, CJK) are handled
exactly — the detector reads git output with `core.quotePath=false`.
```

Also update the `--check` exit-code table in the same file: exit `2` row becomes `usage or git error (bad --range, not a git repo, shallow clone in committed-drift mode) — loud on purpose, so a misconfigured CI gate fails visibly`, and the exit `0` row drops "no git repo" from its parenthetical.

- [ ] **Step 6: Commit**

```bash
git add skills/readmedaddy/hooks/readme-drift.sh skills/readmedaddy/eval/hook/test-readme-drift.sh skills/readmedaddy/references/auto-update-hook.md
git commit -m "fix(check): non-ASCII watch matching, loud exit 2 on shallow clones and missing repos"
```

---

### Task 5: A2 — remove the live-web-check instructions (offline mandate)

Doc-only task, no tests to write; verification is by grep. The skill's SKILL.md forbids all network access, but two reference files instruct the agent to fetch live pages.

**Files:**
- Modify: `skills/readmedaddy/references/famous-readme-patterns.md` (rule 2, lines ~16–19)
- Modify: `skills/readmedaddy/references/multi-gate-rubric.md` (G2 litmus ~line 60; Scoring discipline ~line 299)

- [ ] **Step 1: Invert the swipe-file rule**

In `famous-readme-patterns.md`, replace:

```markdown
- **Verify before you copy.** Every entry cites an `owner/repo` or domain. Check
  the live README first — projects rewrite their front pages, and a stale quote
  is worse than none.
```

with:

```markdown
- **Never fetch the live README.** This skill operates offline; every pattern
  here is baked in so nothing needs fetching. The `owner/repo` citations are
  provenance, not links to follow. Quoted taglines may have drifted since they
  were recorded — one more reason to imitate the *move*, never paste the words.
```

- [ ] **Step 2: Make G2 offline-checkable**

In `multi-gate-rubric.md`, replace the G2 litmus line:

```markdown
- **Litmus:** do the trust signals here actually resolve? A badge that 404s or a star count nobody can verify scores 0, not 5.
```

with:

```markdown
- **Litmus:** do the trust signals correspond to anything real *in the repo*? A CI badge with no workflow file under `.github/workflows/`, a version badge that contradicts the manifest, or a star count nobody can verify scores 0, not 5. (Checkable offline by construction — never fetch a URL to verify.)
```

- [ ] **Step 3: Make Scoring discipline offline-checkable**

Replace (anchor `Before scoring G2 or G7`):

```markdown
- Before scoring G2 or G7, confirm that badges, benchmarks, and links **resolve and are real**. CI/version/license badges that become valid on push are allowed; an unverifiable trust claim scores low, never high.
```

with:

```markdown
- Before scoring G2 or G7, confirm that badges, benchmarks, and links **refer to things the repo itself declares** — a CI badge needs a workflow file in `.github/workflows/`, a version badge must match the manifest, a link must point at a path that exists in the tree or a URL the repo's own metadata declares. All of this is checkable offline; **never fetch a URL to verify anything**. Badges that become valid on push are allowed; an unverifiable trust claim scores low, never high.
```

- [ ] **Step 4: Verify no fetch instructions remain**

Run: `grep -rn -i "check the live\|resolve and are real\|live README first" skills/readmedaddy/references/ skills/readmedaddy/SKILL.md`
Expected: zero hits. (The replacement texts deliberately contain "never fetch" phrasing — the grep above avoids the bare word "fetch" so prohibitions don't false-positive.)

- [ ] **Step 5: Run the validator** (it checks reference-file links/structure): `python3 scripts/validate-skill.py` — expected OK.

- [ ] **Step 6: Commit**

```bash
git add skills/readmedaddy/references/famous-readme-patterns.md skills/readmedaddy/references/multi-gate-rubric.md
git commit -m "fix(skill): make every verification instruction offline-checkable — references no longer order live web checks"
```

---

### Task 6: A4 — valid README workflow snippet, moving @v0 tag, validator pin check

**Files:**
- Modify: `README.md` (~lines 236, 258–266)
- Modify: `scripts/validate-skill.py` (new section 10, before the `# Report` block at ~line 309)

- [ ] **Step 1: Write the failing validator check FIRST**

Append to `scripts/validate-skill.py` immediately before the `# Report ---` section:

```python
# 10. Action version-pin consistency ------------------------------------------
# README (and docs) must never pin the GitHub Action to a superseded release.
# Allowed pins: the moving major tag (@v<MAJOR>) or the exact current version
# (@v<CHANGELOG top entry>). Anything else rots the quickstart.
changelog_path = os.path.join(ROOT, "CHANGELOG.md")
pin_files = [
    os.path.join(ROOT, "README.md"),
    os.path.join(REF_DIR, "auto-update-hook.md"),
]
if os.path.exists(changelog_path):
    cm = re.search(r"^## \[(\d+)\.(\d+)\.(\d+)\]", read(changelog_path), re.M)
    if not cm:
        warn("CHANGELOG.md: no '## [x.y.z]' entry found — version-pin check skipped")
    else:
        cur_full = f"{cm.group(1)}.{cm.group(2)}.{cm.group(3)}"
        cur_major = cm.group(1)
        pins_checked = 0
        for pf in pin_files:
            if not os.path.exists(pf):
                continue
            for pin in re.findall(r"Systemartis/readmedaddy@v([0-9][0-9A-Za-z.]*)", read(pf)):
                pins_checked += 1
                if pin not in (cur_major, cur_full):
                    err(
                        f"{os.path.relpath(pf, ROOT)}: action pinned to @v{pin} "
                        f"(current: v{cur_full}; recommended pin: @v{cur_major})"
                    )
        note(f"action version pins checked: {pins_checked}")
```

- [ ] **Step 2: Run — must FAIL**

Run: `python3 scripts/validate-skill.py`
Expected: `FAIL  README.md: action pinned to @v0.2.0 (current: v0.2.1; recommended pin: @v0)` and exit 1.

- [ ] **Step 3: Fix the README snippet**

Replace the block at README.md ~lines 258–266 (anchor `**Pull-request gate** with the bundled GitHub Action`):

```yaml
on: pull_request
permissions: { contents: read, pull-requests: write }
steps:
  - uses: actions/checkout@v4
    with: { fetch-depth: 0 }        # the range diff needs the merge-base
  - uses: Systemartis/readmedaddy@v0.2.0
    with: { mode: comment }         # one sticky PR comment; 'fail' = required check
```

with a complete, pasteable workflow:

```yaml
# .github/workflows/readme-drift.yml
name: readme drift
on: pull_request
permissions: { contents: read, pull-requests: write }
jobs:
  readme-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }    # the range diff needs the merge-base
      - uses: Systemartis/readmedaddy@v0
        with: { mode: comment }     # one sticky PR comment; 'fail' = required check
```

(The job id `readme-drift` matters: the spec's phase-7 ruleset recipe names it as the required-check context.)

- [ ] **Step 4: Fix the env-var line while in the file**

README.md ~line 236: change `force a mode for one session with `README_DADDY_HOOK=notify|enforce|off`. Disable it entirely with `README_DADDY_HOOK=off`.` to `force a mode for one session with `README_DADDY_HOOK=auto|notify|enforce`, or disable it for the session with `README_DADDY_HOOK=off`.` (confirmed doc-drift: `auto` is accepted).

- [ ] **Step 5: Run validator — PASS.** `python3 scripts/validate-skill.py` → `OK — validate-skill passed`.

- [ ] **Step 6: Create the moving major tag (LOCAL ONLY — pushing is gated)**

```bash
git tag -f v0
```

Do NOT push the tag from this plan. Surface to the user at the end of phase 1: pushing `v0` to the public repo is an outward-facing release action — it must happen together with (or after) the v0.3.0 release commit reaching main, and only on the user's go-ahead: `git push -f origin v0`.

- [ ] **Step 7: Commit**

```bash
git add README.md scripts/validate-skill.py
git commit -m "fix(docs): pasteable PR-gate workflow pinned to @v0, validator enforces pin freshness"
```

---

### Task 7: Phase 1 wrap — CHANGELOG + full suite

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add the unreleased section** (top of file, above `## [0.2.1]`):

```markdown
## [Unreleased]

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
```

- [ ] **Step 2: Full suite**

Run: `sh skills/readmedaddy/eval/hook/test-readme-drift.sh && shellcheck skills/readmedaddy/hooks/readme-drift.sh && python3 scripts/validate-skill.py && python3 scripts/install-hook.py --selftest`
Expected: harness summary with 0 failed (**30** cases: 17 baseline + 4 Task 1 + 5 Task 2 + 1 Task 3 + 3 Task 4), no shellcheck output, validator OK, selftest PASS.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for phase-1 detector and docs fixes"
```

---

### Task 8: Parser hardening — hook-scoped extraction, mode validation, `"off"`

Phase 2 begins. Confirmed defect: `"mode": "off"` (the natural guess) falls through the `auto | *)` catch-all and BLOCKS; any typo'd mode likewise resolves to the most intrusive behavior. And the greedy whole-file `sed` means any future config section could corrupt `hook` parsing (the spec's §2 constraint).

**Files:**
- Modify: `skills/readmedaddy/hooks/readme-drift.sh` (config block, anchor `# (e) Optional config`)
- Modify: `skills/readmedaddy/eval/hook/test-readme-drift.sh`

- [ ] **Step 1: Write the failing tests**

```sh
# --- config schema v2: parser hardening ---

# (ad) "mode":"off" disables the hook (today it BLOCKS — the worst fallback).
d=$(setup_repo)
printf '{"hook":{"mode":"off"}}\n' >"$d/.readmedaddy.json"
git -C "$d" add -A && git -C "$d" commit -qm cfg
printf '{"name":"x","v":2}\n' >"$d/package.json"
out=$(run_hook "$d" "$STDIN_CONT_FALSE")
if [ -z "$out" ]; then
	note ok "mode:off disables the hook"
else
	note fail "mode:off should be silent (got: $out)"
fi

# (ae) Unknown mode degrades to notify + stderr warning, never to blocking.
d=$(setup_repo)
printf '{"hook":{"mode":"blokc"}}\n' >"$d/.readmedaddy.json"
git -C "$d" add -A && git -C "$d" commit -qm cfg
printf '{"name":"x","v":2}\n' >"$d/package.json"
out=$( (cd "$d" && printf '%s' "$STDIN_CONT_FALSE" | sh "$HOOK" 2>/dev/null) )
errout=$( (cd "$d" && printf '%s' "$STDIN_CONT_FALSE" | sh "$HOOK" 2>&1 >/dev/null) )
if [ -z "$out" ] && printf '%s' "$errout" | grep -qi 'unknown mode'; then
	note ok "unknown mode degrades to notify with a warning"
else
	note fail "unknown mode expected notify+warning (out: $out | err: $errout)"
fi

# (af) Keys OUTSIDE the hook object no longer corrupt parsing: a SIBLING
# section's enabled:false must not disable the hook. (Today the greedy
# whole-file sed reads it and silences the hook — this is the exact hazard
# that blocks adding new config sections.)
d=$(setup_repo)
printf '{"hook":{"mode":"auto"},"future":{"enabled":false}}\n' >"$d/.readmedaddy.json"
git -C "$d" add -A && git -C "$d" commit -qm cfg
printf '{"name":"x","v":2}\n' >"$d/package.json"
out=$(run_hook "$d" "$STDIN_CONT_FALSE")
case "$out" in
*'"decision":"block"'*) note ok "sibling section's enabled:false is ignored" ;;
*) note fail "sibling enabled:false must not disable the hook (got: $out)" ;;
esac
```

- [ ] **Step 2: Run — (ad), (ae), (af) must FAIL** ((ad) blocks today; (ae) blocks today; (af) goes silent today because the greedy whole-file sed reads the sibling section's `"enabled": false`).

- [ ] **Step 3: Implement**

Replace the config-extraction block (anchor `cfg=$(tr -d '\n' <"$config"`), keeping the surrounding `if [ -f "$config" ]`:

```sh
	cfg=$(tr -d '\n' <"$config" 2>/dev/null)
	# Scope extraction to the hook object: everything from `"hook" : {` to the
	# first `}`. The hook object holds only scalars and one array, so the first
	# closing brace ends it. Falls back to whole-file scan when no hook object
	# exists (historical configs).
	cfg_hook=$(printf '%s' "$cfg" | sed -n 's/.*"hook"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p')
	if [ -z "$cfg_hook" ]; then
		cfg_hook=$cfg
	fi
	case "$cfg_hook" in
	*'"enabled"'*)
		en=$(printf '%s' "$cfg_hook" | sed -n 's/.*"enabled"[[:space:]]*:[[:space:]]*\([A-Za-z]*\).*/\1/p')
		if [ "$en" = false ]; then
			exit 0
		fi
		;;
	esac
	cfg_mode=$(printf '%s' "$cfg_hook" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_readme=$(printf '%s' "$cfg_hook" | sed -n 's/.*"readme"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_watch=$(printf '%s' "$cfg_hook" | sed -n 's/.*"watch"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p')
```

Then extend the mode-resolution block (anchor `mode=auto`) so unknown values can never block. Replace:

```sh
mode=auto
if [ -n "$cfg_mode" ]; then
	mode=$cfg_mode
fi
case "${README_DADDY_HOOK:-}" in
notify | auto | enforce) mode=$README_DADDY_HOOK ;;
esac
```

with:

```sh
mode=auto
if [ -n "$cfg_mode" ]; then
	mode=$cfg_mode
fi
case "${README_DADDY_HOOK:-}" in
notify | auto | enforce) mode=$README_DADDY_HOOK ;;
esac
case "$mode" in
auto | notify | enforce) ;;
off)
	# "off" is a natural guess and must mean what it says (hook mode only;
	# --check has its own contract and ignores mode).
	if [ "$CHECK_MODE" = 0 ]; then
		exit 0
	fi
	;;
*)
	printf 'readmedaddy: unknown mode "%s" in .readmedaddy.json — treating as notify (valid: auto|notify|enforce|off)\n' "$mode" >&2
	mode=notify
	;;
esac
```

Finally, change the emit `case "$mode" in` at the bottom: the `auto | *)` arm becomes plain `auto)` — after validation, `mode` is always one of the three known values, and an explicit arm list keeps a future regression from silently blocking. Add `*) : ;;` as the final arm (unreachable, satisfies exhaustiveness).

- [ ] **Step 4: Run tests — all PASS** (the existing `(e)` DISABLED and `(f)` COOLDOWN cases guard the refactor). shellcheck clean.

- [ ] **Step 5: Fix the docs this change obsoletes**

Task 8 makes two shipped doc claims false — update both now, not in Task 12:

1. `skills/readmedaddy/references/auto-update-hook.md`, "One parsing caveat" paragraph (anchor `reads the **last** occurrence of each key`): replace with

```markdown
One parsing caveat (deliberately simple, no JSON parser in POSIX sh): the hook
reads its keys from the **`hook` object** — everything between `"hook": {` and
the first `}`. Keys elsewhere in the file (doc strings, other sections) are
ignored. Keep the `hook` object free of nested objects; validate the whole
file any time with `readme-drift.sh --lint-config`.
```

2. Mode value lists gain `off`: in the same file's config table, the `hook.mode` row becomes `"auto"`, `"notify"`, `"enforce"`, or `"off"`; in `README.md`'s three-mode table section (anchor `Three modes pick how insistent`), add one sentence after the table: `A fourth value, "off", disables the Stop hook for the repo; the standalone --check still runs (use "enabled": false to turn off every surface).`

- [ ] **Step 6: Commit**

```bash
git add skills/readmedaddy/hooks/readme-drift.sh skills/readmedaddy/eval/hook/test-readme-drift.sh skills/readmedaddy/references/auto-update-hook.md README.md
git commit -m "fix(config): hook-scoped key extraction, mode validation — misconfiguration can never resolve to blocking"
```

---

### Task 9: `--config FILE` flag

The action (phase 3) will pass the base-ref's config so a PR cannot waive its own gate; `/dev/null` is the defaults-only sentinel. Detector-side support lands now, with the parser work fresh.

**Files:**
- Modify: `skills/readmedaddy/hooks/readme-drift.sh` (arg parsing + config path resolution)
- Modify: `skills/readmedaddy/eval/hook/test-readme-drift.sh`

- [ ] **Step 1: Write the failing tests**

```sh
# --- --config FILE (base-ref config injection) ---

# (ag) --config /dev/null ignores the working tree's enabled:false.
d=$(setup_repo)
printf '{"hook":{"enabled":false}}\n' >"$d/.readmedaddy.json"
printf '{"name":"x","v":2}\n' >"$d/package.json"
(cd "$d" && sh "$HOOK" --check --config /dev/null >/dev/null 2>&1)
rc=$?
if [ "$rc" = 1 ]; then
	note ok "--config /dev/null overrides working-tree config (defaults apply)"
else
	note fail "--config /dev/null expected rc=1 (rc=$rc)"
fi

# (ah) --config FILE uses that file's watch list, not the working tree's.
d=$(setup_repo)
mkdir -p "$d/docs"
printf 'g\n' >"$d/docs/g.md" && git -C "$d" add -A && git -C "$d" commit -qm docs
alt=$(mktemp "$TMPROOT/alt.XXXXXX")
printf '{"hook":{"watch":["docs/*.md"]}}\n' >"$alt"
printf 'g2\n' >"$d/docs/g.md"
out=$( (cd "$d" && sh "$HOOK" --check --config "$alt" 2>/dev/null) )
rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'docs/g.md'; then
	note ok "--config FILE supplies the effective watch list"
else
	note fail "--config FILE expected rc=1 naming docs/g.md (rc=$rc, out: $out)"
fi

# (ai) --config without a value exits 2.
d=$(setup_repo)
(cd "$d" && sh "$HOOK" --check --config </dev/null >/dev/null 2>&1)
rc=$?
if [ "$rc" = 2 ]; then
	note ok "--config without a value exits 2"
else
	note fail "--config missing value expected rc=2 (rc=$rc)"
fi
```

- [ ] **Step 2: Run — (ag), (ah) FAIL (unknown argument exits 2 today); (ai) passes incidentally (also exit 2) — keep it as the contract pin.**

- [ ] **Step 3: Implement**

1. Arg parsing (anchor `--range)`): add sibling cases:

```sh
	--config)
		shift
		CONFIG_OVERRIDE=${1:-}
		CONFIG_SET=1
		;;
	--config=*)
		CONFIG_OVERRIDE=${1#--config=}
		CONFIG_SET=1
		;;
```

Initialize `CONFIG_OVERRIDE=` and `CONFIG_SET=0` next to `RANGE=`/`RANGE_SET=0`. After the parse loop, add validation alongside the `--range` checks:

```sh
if [ "$CONFIG_SET" = 1 ] && [ -z "$CONFIG_OVERRIDE" ]; then
	printf 'readmedaddy: --config requires a file path (use /dev/null for pure defaults)\n' >&2
	exit 2
fi
```

2. Config path resolution (anchor `config=$root/.readmedaddy.json`): replace with:

```sh
if [ "$CONFIG_SET" = 1 ]; then
	config=$CONFIG_OVERRIDE
else
	config=$root/.readmedaddy.json
fi
```

`/dev/null` needs no special-casing: the existing `[ -f "$config" ]` guard is false for it, so every default applies.

- [ ] **Step 4: Run tests — all PASS; shellcheck clean.**

- [ ] **Step 5: Document the flag**

In `skills/readmedaddy/references/auto-update-hook.md`, Standalone `--check` section, add after the two example command lines:

```sh
readme-drift.sh --check --config /path/to/config.json  # explicit config (CI: the base ref's copy)
```

and one sentence below the exit-code table: `--config FILE makes FILE the effective .readmedaddy.json (all keys); --config /dev/null runs on pure defaults. CI gates use this to read the config from the PR's base ref, so a PR cannot waive its own gate.`

- [ ] **Step 6: Commit**

```bash
git add skills/readmedaddy/hooks/readme-drift.sh skills/readmedaddy/eval/hook/test-readme-drift.sh skills/readmedaddy/references/auto-update-hook.md
git commit -m "feat(check): --config FILE flag — CI reads the base ref's config, PRs cannot waive their own gate"
```

---

### Task 10: `guard.*` keys + `--print-config KEY`

The action's phase-3 gate steps need `guard.*` values through the hardened parser, never ad-hoc grep in workflow bash.

**Files:**
- Modify: `skills/readmedaddy/hooks/readme-drift.sh`
- Modify: `skills/readmedaddy/eval/hook/test-readme-drift.sh`

**Defaults contract** (absent key → printed default): `hook.enabled=true`, `hook.mode=auto`, `hook.readme=README.md`, `guard.pr=comment`, `guard.main=off`, `guard.sweep=off`, `guard.autofix.runner=off`, `guard.autofix.command=` (empty line). An absent `guard` section reproduces today's behavior exactly (PR comment gate only).

**Raw-vs-resolved note (for phase-3 consumers):** `--print-config` reports the RAW configured value (a config with `"mode":"blokc"` prints `blokc`), not the validated/resolved behavior — validation happens in `--lint-config` and at hook emission. Workflows should lint first, then print.

- [ ] **Step 1: Write the failing tests**

```sh
# --- --print-config KEY ---

# (aj) guard keys print configured values; unknown key exits 2.
d=$(setup_repo)
cat >"$d/.readmedaddy.json" <<'CFG'
{"hook":{"mode":"notify"},"guard":{"pr":"fail","main":"issue","sweep":"weekly","autofix":{"runner":"claude","command":""}}}
CFG
git -C "$d" add -A && git -C "$d" commit -qm cfg
pc() { (cd "$d" && sh "$HOOK" --print-config "$1" 2>/dev/null); }
v1=$(pc guard.pr); v2=$(pc guard.main); v3=$(pc guard.sweep)
v4=$(pc guard.autofix.runner); v5=$(pc hook.mode)
(cd "$d" && sh "$HOOK" --print-config guard.nope >/dev/null 2>&1); rcu=$?
if [ "$v1 $v2 $v3 $v4 $v5" = "fail issue weekly claude notify" ] && [ "$rcu" = 2 ]; then
	note ok "--print-config resolves guard + hook keys, unknown key exits 2"
else
	note fail "--print-config got: pr=$v1 main=$v2 sweep=$v3 runner=$v4 mode=$v5 rcu=$rcu"
fi

# (ak) defaults when no config exists.
d=$(setup_repo)
def=$( (cd "$d" && sh "$HOOK" --print-config guard.pr 2>/dev/null); (cd "$d" && sh "$HOOK" --print-config guard.main 2>/dev/null); (cd "$d" && sh "$HOOK" --print-config guard.autofix.runner 2>/dev/null) )
if [ "$def" = "comment
off
off" ]; then
	note ok "--print-config defaults: pr=comment, main=off, runner=off"
else
	note fail "--print-config defaults wrong (got: $def)"
fi

# (al) --print-config composes with --config FILE.
d=$(setup_repo)
alt=$(mktemp "$TMPROOT/alt.XXXXXX")
printf '{"guard":{"pr":"off"}}\n' >"$alt"
v=$( (cd "$d" && sh "$HOOK" --print-config guard.pr --config "$alt" 2>/dev/null) )
if [ "$v" = off ]; then
	note ok "--print-config honors --config"
else
	note fail "--print-config with --config expected 'off' (got: $v)"
fi
```

- [ ] **Step 2: Run — all three FAIL (unknown argument).**

- [ ] **Step 3: Implement**

1. Arg parsing: add `--print-config` (takes the KEY as its value, same shift pattern as `--config`), setting `PRINT_KEY` and `PRINT_MODE=1`. Validation: `--print-config` with empty KEY → usage message, exit 2. `--print-config` and `--check` together → exit 2 (one job per invocation). `PRINT_MODE` skips stdin reading exactly like `CHECK_MODE` (adjust the `if [ "$CHECK_MODE" = 0 ]` stdin guard to `if [ "$CHECK_MODE" = 0 ] && [ "$PRINT_MODE" = 0 ]`). Root resolution: print mode outside a repo behaves like check mode (exit 2) UNLESS `--config` was given (config file needs no repo); implement as: resolve root, and if empty AND `CONFIG_SET=0` → exit 2 loudly.

2. Guard extraction, placed with the other config parsing. The guard keys are collision-safe by schema design (unique names file-wide), so flat greedy extraction is correct here:

```sh
cfg_guard_pr=
cfg_guard_main=
cfg_guard_sweep=
cfg_guard_runner=
cfg_guard_command=
if [ -f "$config" ]; then
	cfg_guard_pr=$(printf '%s' "$cfg" | sed -n 's/.*"pr"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_guard_main=$(printf '%s' "$cfg" | sed -n 's/.*"main"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_guard_sweep=$(printf '%s' "$cfg" | sed -n 's/.*"sweep"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_guard_runner=$(printf '%s' "$cfg" | sed -n 's/.*"runner"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_guard_command=$(printf '%s' "$cfg" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi
```

(Note: `$cfg` is already the flattened file from Task 8; guard extraction reads the WHOLE file, not `$cfg_hook`.)

3. Emission, placed after config parsing and before the README-existence check (print mode must answer even when no README exists):

```sh
if [ "$PRINT_MODE" = 1 ]; then
	case "$PRINT_KEY" in
	hook.enabled) printf '%s\n' "${en:-true}" ;;
	hook.mode) printf '%s\n' "${cfg_mode:-auto}" ;;
	hook.readme) printf '%s\n' "${cfg_readme:-README.md}" ;;
	guard.pr) printf '%s\n' "${cfg_guard_pr:-comment}" ;;
	guard.main) printf '%s\n' "${cfg_guard_main:-off}" ;;
	guard.sweep) printf '%s\n' "${cfg_guard_sweep:-off}" ;;
	guard.autofix.runner) printf '%s\n' "${cfg_guard_runner:-off}" ;;
	guard.autofix.command) printf '%s\n' "$cfg_guard_command" ;;
	*)
		printf 'readmedaddy --print-config: unknown key: %s\n' "$PRINT_KEY" >&2
		exit 2
		;;
	esac
	exit 0
fi
```

Placement caveats: this block must run AFTER config parsing but BEFORE (f) README-existence, the mode-resolution `off` early-exit must not fire first in print mode (guard the `exit 0` in the Task-8 `off)` arm with `[ "$PRINT_MODE" = 0 ]` too), and the `enabled:false` early-exit must ALSO be skipped in print mode (move print-mode emission above it, or guard it: `if [ "$en" = false ] && [ "$PRINT_MODE" = 0 ]`). Print mode reports config; it never gates.

- [ ] **Step 4: Run tests — all PASS; shellcheck clean.**

- [ ] **Step 5: Commit**

```bash
git add skills/readmedaddy/hooks/readme-drift.sh skills/readmedaddy/eval/hook/test-readme-drift.sh
git commit -m "feat(config): guard.* keys + --print-config KEY — one hardened parser for every consumer"
```

---

### Task 11: `--lint-config`

**Files:**
- Modify: `skills/readmedaddy/hooks/readme-drift.sh`
- Modify: `skills/readmedaddy/eval/hook/test-readme-drift.sh`

**Contract:** exit 0 = config valid (or no config file: nothing to lint, prints a note), 1 = invalid (findings on stderr), 2 = usage error. JSON well-formedness via python3 when available (stdlib only, still zero network — the no-network CI guard scans for network *primitives*, `json` is safe); without python3, degrade to enum checks + a stderr note.

- [ ] **Step 1: Write the failing tests**

```sh
# --- --lint-config ---

# (am) valid config lints clean (exit 0).
d=$(setup_repo)
cat >"$d/.readmedaddy.json" <<'CFG'
{"hook":{"enabled":true,"mode":"auto","readme":"README.md","watch":["src/**"]},"guard":{"pr":"comment","main":"issue","sweep":"weekly","autofix":{"runner":"off","command":""}}}
CFG
(cd "$d" && sh "$HOOK" --lint-config >/dev/null 2>&1); rc=$?
if [ "$rc" = 0 ]; then note ok "lint: valid config exits 0"; else note fail "lint valid expected 0 (rc=$rc)"; fi

# (an) malformed JSON exits 1 (when python3 is present).
if command -v python3 >/dev/null 2>&1; then
	d=$(setup_repo)
	printf '{"hook":{' >"$d/.readmedaddy.json"
	(cd "$d" && sh "$HOOK" --lint-config >/dev/null 2>&1); rc=$?
	if [ "$rc" = 1 ]; then note ok "lint: malformed JSON exits 1"; else note fail "lint malformed expected 1 (rc=$rc)"; fi
fi

# (ao) bad enum exits 1 and names the key.
d=$(setup_repo)
printf '{"hook":{"mode":"blokc"}}\n' >"$d/.readmedaddy.json"
errout=$( (cd "$d" && sh "$HOOK" --lint-config 2>&1 >/dev/null) ); rc=$?
if [ "$rc" = 1 ] && printf '%s' "$errout" | grep -q 'mode'; then
	note ok "lint: bad enum exits 1 naming the key"
else
	note fail "lint bad enum expected 1 naming mode (rc=$rc, err: $errout)"
fi

# (ap) no config file exits 0 with a note.
d=$(setup_repo)
(cd "$d" && sh "$HOOK" --lint-config >/dev/null 2>&1); rc=$?
if [ "$rc" = 0 ]; then note ok "lint: no config is fine (exit 0)"; else note fail "lint no-config expected 0 (rc=$rc)"; fi
```

- [ ] **Step 2: Run — all FAIL (unknown argument).**

- [ ] **Step 3: Implement**

Arg parsing: add `--lint-config` setting `LINT_MODE=1` (mutually exclusive with `--check` and `--print-config` → exit 2; skips stdin like the others; composes with `--config`). After config parsing (reusing `$config`, `$cfg`, `$cfg_hook`, and the guard vars), before any gating logic:

```sh
if [ "$LINT_MODE" = 1 ]; then
	if [ ! -f "$config" ]; then
		printf 'readmedaddy --lint-config: no config at %s — nothing to lint.\n' "$config" >&2
		exit 0
	fi
	lint_fail=0
	if command -v python3 >/dev/null 2>&1; then
		if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$config" 2>/dev/null; then
			printf 'readmedaddy --lint-config: %s is not valid JSON\n' "$config" >&2
			lint_fail=1
		fi
	else
		printf 'readmedaddy --lint-config: python3 not found — skipping JSON well-formedness, checking enums only\n' >&2
	fi
	lint_enum() {
		le_key=$1
		le_val=$2
		le_allowed=$3
		if [ -z "$le_val" ]; then
			return 0
		fi
		case " $le_allowed " in
		*" $le_val "*) return 0 ;;
		esac
		printf 'readmedaddy --lint-config: %s: "%s" is not one of: %s\n' "$le_key" "$le_val" "$le_allowed" >&2
		lint_fail=1
		return 0
	}
	lint_enum hook.mode "$cfg_mode" "auto notify enforce off"
	lint_enum guard.pr "$cfg_guard_pr" "off comment fail"
	lint_enum guard.main "$cfg_guard_main" "off issue fail"
	lint_enum guard.sweep "$cfg_guard_sweep" "off weekly"
	lint_enum guard.autofix.runner "$cfg_guard_runner" "off claude command"
	# Known-key walk (spec §2): a typo'd key must not lint clean. python3 only —
	# the sh parser can't enumerate keys; the degraded path already warned above.
	if command -v python3 >/dev/null 2>&1; then
		if ! python3 - "$config" <<'PYEOF' >&2; then
import json, sys
KNOWN = {
    "": {"$schema", "hook", "guard", "_README"},
    "hook": {"enabled", "mode", "readme", "watch"},
    "guard": {"pr", "main", "sweep", "autofix"},
    "guard.autofix": {"runner", "command"},
}
try:
    cfg = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)  # well-formedness already reported above
bad = []
def walk(obj, path):
    if not isinstance(obj, dict):
        return
    allowed = KNOWN.get(path)
    if allowed is None:
        return
    for k, v in obj.items():
        if k not in allowed:
            bad.append(f"{path + '.' if path else ''}{k}")
        else:
            walk(v, f"{path + '.' if path else ''}{k}")
walk(cfg, "")
for b in bad:
    print(f"readmedaddy --lint-config: unknown key: {b}")
sys.exit(1 if bad else 0)
PYEOF
			lint_fail=1
		fi
	fi
	if [ "$lint_fail" = 1 ]; then
		exit 1
	fi
	printf 'readmedaddy --lint-config: %s OK\n' "$config"
	exit 0
fi
```

Add one more failing test alongside (am)–(ap):

```sh
# (aq) unknown key exits 1 naming it (python3 machines).
if command -v python3 >/dev/null 2>&1; then
	d=$(setup_repo)
	printf '{"guard":{"prr":"fail"}}\n' >"$d/.readmedaddy.json"
	errout=$( (cd "$d" && sh "$HOOK" --lint-config 2>&1 >/dev/null) ); rc=$?
	if [ "$rc" = 1 ] && printf '%s' "$errout" | grep -q 'prr'; then
		note ok "lint: unknown key exits 1 naming it"
	else
		note fail "lint unknown key expected 1 naming prr (rc=$rc, err: $errout)"
	fi
fi
```

Placement: same region as `--print-config` emission (after parsing, before gating); the `enabled:false` and `mode: off` early-exits must not fire in lint mode either (extend their guards to `&& [ "$LINT_MODE" = 0 ]`, or restructure: lint/print emission blocks run before both early-exits).

- [ ] **Step 4: Run tests — all PASS; shellcheck clean. Also confirm the no-network CI guard still passes:** `python3 scripts/validate-skill.py` (the new `python3 -c 'import json…'` line contains no network primitive).

- [ ] **Step 5: Commit**

```bash
git add skills/readmedaddy/hooks/readme-drift.sh skills/readmedaddy/eval/hook/test-readme-drift.sh
git commit -m "feat(config): --lint-config — misconfigurations fail loudly instead of resolving to defaults"
```

---

### Task 12: JSON Schema + example + docs

**Files:**
- Create: `schema/readmedaddy.schema.json`
- Modify: `skills/readmedaddy/.readmedaddy.json.example`
- Modify: `skills/readmedaddy/references/auto-update-hook.md` (config table)

- [ ] **Step 1: Write the schema**

Create `schema/readmedaddy.schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://raw.githubusercontent.com/Systemartis/readmedaddy/main/schema/readmedaddy.schema.json",
  "title": ".readmedaddy.json",
  "description": "Per-repo configuration for readmedaddy: the readme-drift hook/detector and the CI guard. Every key is optional; omit a key to keep its default.",
  "type": "object",
  "properties": {
    "hook": {
      "type": "object",
      "description": "The drift detector: Claude Code Stop hook and standalone --check.",
      "properties": {
        "enabled": {
          "type": "boolean",
          "default": true,
          "description": "false turns the detector off for this repo (all surfaces)."
        },
        "mode": {
          "type": "string",
          "enum": ["auto", "notify", "enforce", "off"],
          "default": "auto",
          "description": "Stop-hook insistence. auto: one nudge per drift event. notify: stderr only. enforce: every Stop until the README moves. off: hook disabled (--check unaffected)."
        },
        "readme": {
          "type": "string",
          "default": "README.md",
          "description": "Path (relative to repo root) of the README the detector watches."
        },
        "watch": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Patterns whose changes imply README drift: exact paths, dir/** (prefix), **/name (suffix), or plain globs like docs/*.md."
        }
      },
      "additionalProperties": false
    },
    "guard": {
      "type": "object",
      "description": "CI guard behavior (consumed by the GitHub Action from v0.3.0).",
      "properties": {
        "pr": {
          "type": "string",
          "enum": ["off", "comment", "fail"],
          "default": "comment",
          "description": "Pull-request response: sticky advisory comment, failing check, or nothing."
        },
        "main": {
          "type": "string",
          "enum": ["off", "issue", "fail"],
          "default": "off",
          "description": "Default-branch push response: pinned dashboard issue, failing job, or nothing."
        },
        "sweep": {
          "type": "string",
          "enum": ["off", "weekly"],
          "default": "off",
          "description": "Scheduled freshness sweep; reports into the same dashboard issue."
        },
        "autofix": {
          "type": "object",
          "description": "Opt-in tier 3: an agent refreshes the README and opens a fix PR. Costs LLM tokens; requires an API-key secret.",
          "properties": {
            "runner": {
              "type": "string",
              "enum": ["off", "claude", "command"],
              "default": "off",
              "description": "off: no auto-fix. claude: anthropics/claude-code-action. command: run guard.autofix.command verbatim as the agent step."
            },
            "command": {
              "type": "string",
              "default": "",
              "description": "Agent CLI invocation used when runner is \"command\". Contract: edit the working tree only — no commit, no push, no PR."
            }
          },
          "additionalProperties": false
        }
      },
      "additionalProperties": false
    }
  }
}
```

- [ ] **Step 2: Validate the schema is itself valid JSON and matches the lint enums**

Run: `python3 -c "import json; s=json.load(open('schema/readmedaddy.schema.json')); assert s['properties']['hook']['properties']['mode']['enum']==['auto','notify','enforce','off']; print('schema OK')"`
Expected: `schema OK` (and nothing else — the assert runs before the print).

- [ ] **Step 3: Update the shipped example**

In `skills/readmedaddy/.readmedaddy.json.example`: add `"$schema": "https://raw.githubusercontent.com/Systemartis/readmedaddy/main/schema/readmedaddy.schema.json"` as the first key and a `guard` section mirroring the schema defaults (`pr: comment`, `main: off`, `sweep: off`, `autofix.runner: off`), keeping the existing `_README`-style guidance conventions of the file (read it first; keep the real `hook` object positioned per its own documented caveat).

- [ ] **Step 4: Extend the config table**

In `skills/readmedaddy/references/auto-update-hook.md`, add rows to the config table:

```markdown
| `guard.pr` | string | `"comment"` | PR gate: `"off"`, `"comment"` (sticky advisory), `"fail"` (red check). Consumed by the GitHub Action from v0.3.0. |
| `guard.main` | string | `"off"` | Default-branch push response: `"off"`, `"issue"` (pinned dashboard issue), `"fail"`. From v0.3.0. |
| `guard.sweep` | string | `"off"` | `"weekly"` re-checks freshness on a schedule. From v0.3.0. |
| `guard.autofix.runner` | string | `"off"` | Opt-in fix tier: `"claude"` or `"command"` (uses `guard.autofix.command`). Costs LLM tokens. From v0.3.0. |
```

and a short `### Validate your config` subsection documenting `--lint-config` + the `$schema` editor story.

- [ ] **Step 5: Run everything**

Run: `sh skills/readmedaddy/eval/hook/test-readme-drift.sh && shellcheck skills/readmedaddy/hooks/readme-drift.sh && python3 scripts/validate-skill.py`
Expected: all green. (validate-skill.py's link checker sees the new relative links in auto-update-hook.md — make sure any link you add resolves.)

- [ ] **Step 6: Commit**

```bash
git add schema/readmedaddy.schema.json skills/readmedaddy/.readmedaddy.json.example skills/readmedaddy/references/auto-update-hook.md
git commit -m "feat(config): published JSON Schema, example config with guard section, documented lint story"
```

---

### Task 13: Phase 2 wrap — CHANGELOG, full suite, handoff notes

**Files:**
- Modify: `CHANGELOG.md` (extend the `[Unreleased]` section)

- [ ] **Step 1: Extend `[Unreleased]`** with an `### Added` block:

```markdown
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
- **`--lint-config`**: JSON well-formedness (python3 when available) + enum
  validation, exit 0/1/2.
```

- [ ] **Step 2: Full suite, one last time**

Run: `sh skills/readmedaddy/eval/hook/test-readme-drift.sh && shellcheck skills/readmedaddy/hooks/readme-drift.sh && python3 scripts/validate-skill.py && python3 scripts/install-hook.py --selftest`
Expected: harness `0 failed` — **44** cases (30 after phase 1 + 3 Task 8 + 3 Task 9 + 3 Task 10 + 5 Task 11); **42** on a machine without python3 (cases (an) and (aq) are conditional). shellcheck silent, validator OK, selftest PASS.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for config schema v2 and detector flags"
```

- [ ] **Step 4: Surface the two gated/outward items to the user (do NOT do them autonomously):**
  1. Push the `v0` moving tag (`git push -f origin v0`) — belongs with the v0.3.0 release.
  2. Merge `feat/v0.3.0-phase-1-2` to main (or open a PR) — user's call per repo workflow.

---

## Out of scope (later phase groups)

- `action.yml` event expansion, sticky-comment resolution, base-ref config extraction in CI (phase 3 — consumes `--config`/`--print-config` built here).
- Wizard (`readmedaddy-init.py`), onboarding PR (phase 4).
- Tier-3 generated workflow (phase 5), plugin packaging (phase 6), ruleset apply (phase 7).
- macOS CI matrix (ships with phase 3's CI edits; noted here so it isn't lost).
