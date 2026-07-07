#!/bin/sh
# RED->GREEN test for the readme-drift Stop hook.
# Creates throwaway git repos under a mktemp dir and asserts the hook's
# documented behavior. POSIX sh, shellcheck-clean. Exits nonzero on any failure.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
HOOK=$(cd "$SCRIPT_DIR/../.." && pwd)/hooks/readme-drift.sh

if [ ! -f "$HOOK" ]; then
	printf 'FATAL: hook not found at %s\n' "$HOOK" >&2
	exit 2
fi

# Keep the test hermetic regardless of caller environment.
unset README_DADDY_HOOK 2>/dev/null || true

TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/rmd-hook.XXXXXX")
PASS=0
FAIL=0

# shellcheck disable=SC2329,SC2317  # invoked indirectly via trap
cleanup() {
	rm -rf "$TMPROOT"
}
trap cleanup EXIT INT TERM

note() {
	if [ "$1" = ok ]; then
		PASS=$((PASS + 1))
		printf 'PASS: %s\n' "$2"
	else
		FAIL=$((FAIL + 1))
		printf 'FAIL: %s\n' "$2"
	fi
}

# Create a committed git repo with a clean README and package.json.
setup_repo() {
	d=$(mktemp -d "$TMPROOT/repo.XXXXXX")
	git init -q "$d"
	git -C "$d" config user.email test@example.invalid
	git -C "$d" config user.name test
	git -C "$d" config commit.gpgsign false
	printf 'readme\n' >"$d/README.md"
	printf '{"name":"x"}\n' >"$d/package.json"
	git -C "$d" add -A
	git -C "$d" commit -qm init
	printf '%s' "$d"
}

# Run the hook in $1 (CWD) feeding $2 on stdin; capture stdout.
run_hook() {
	(cd "$1" && printf '%s' "$2" | sh "$HOOK")
}

STDIN_CONT_FALSE='{"stop_hook_active": false}'
STDIN_CONT_TRUE='{"stop_hook_active": true}'

# (a) DRIFT: watched file dirty, README clean -> block decision on stdout.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
out=$(run_hook "$d" "$STDIN_CONT_FALSE")
case "$out" in
*'"decision":"block"'*) note ok "DRIFT emits block decision" ;;
*) note fail "DRIFT emits block decision (got: $out)" ;;
esac

# (b) NO-DRIFT: watched file AND README both touched -> empty stdout.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
printf 'readme changed\n' >"$d/README.md"
out=$(run_hook "$d" "$STDIN_CONT_FALSE")
if [ -z "$out" ]; then
	note ok "NO-DRIFT (README also touched) is silent"
else
	note fail "NO-DRIFT should be silent (got: $out)"
fi

# (c) LOOP-GUARD: stop_hook_active true -> empty stdout even with drift.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
out=$(run_hook "$d" "$STDIN_CONT_TRUE")
if [ -z "$out" ]; then
	note ok "LOOP-GUARD (stop_hook_active true) is silent"
else
	note fail "LOOP-GUARD should be silent (got: $out)"
fi

# (d) NOT-A-GIT: non-git dir -> empty stdout.
d=$(mktemp -d "$TMPROOT/nogit.XXXXXX")
printf 'readme\n' >"$d/README.md"
printf '{}\n' >"$d/package.json"
out=$(run_hook "$d" "$STDIN_CONT_FALSE")
if [ -z "$out" ]; then
	note ok "NOT-A-GIT is silent"
else
	note fail "NOT-A-GIT should be silent (got: $out)"
fi

# (e) DISABLED: .readmedaddy.json hook.enabled=false -> empty stdout.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
printf '{"hook":{"enabled":false}}\n' >"$d/.readmedaddy.json"
out=$(run_hook "$d" "$STDIN_CONT_FALSE")
if [ -z "$out" ]; then
	note ok "DISABLED config is silent"
else
	note fail "DISABLED config should be silent (got: $out)"
fi

# (f) COOLDOWN: identical drift signature blocks once, then is silent (auto).
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
out1=$(run_hook "$d" "$STDIN_CONT_FALSE")
out2=$(run_hook "$d" "$STDIN_CONT_FALSE")
cooldown_ok=1
case "$out1" in
*'"decision":"block"'*) : ;;
*) cooldown_ok=0 ;;
esac
if [ -n "$out2" ]; then
	cooldown_ok=0
fi
if [ "$cooldown_ok" = 1 ]; then
	note ok "COOLDOWN blocks first, silent on identical second"
else
	note fail "COOLDOWN expected block then silence (got1: $out1 | got2: $out2)"
fi

# --- standalone --check mode (agent-agnostic: CI, pre-commit, any harness) ---

# (g) CHECK-DRIFT: watched file dirty, README clean -> exit 1, names the file.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
out=$( (cd "$d" && sh "$HOOK" --check) )
rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'package.json'; then
	note ok "CHECK drift exits 1 and names the watched file"
else
	note fail "CHECK drift expected rc=1 naming package.json (rc=$rc, out: $out)"
fi

# (h) CHECK-CLEAN: nothing changed -> exit 0, silent stdout.
d=$(setup_repo)
out=$( (cd "$d" && sh "$HOOK" --check) )
rc=$?
if [ "$rc" = 0 ] && [ -z "$out" ]; then
	note ok "CHECK clean exits 0 silently"
else
	note fail "CHECK clean expected rc=0 silent (rc=$rc, out: $out)"
fi

# (i) CHECK is idempotent: no cooldown state consumed; second run still exits 1.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
(cd "$d" && sh "$HOOK" --check >/dev/null 2>&1)
out=$( (cd "$d" && sh "$HOOK" --check) )
rc=$?
if [ "$rc" = 1 ] && [ ! -e "$d/.readmedaddy" ]; then
	note ok "CHECK is idempotent and writes no cooldown state"
else
	note fail "CHECK second run expected rc=1 and no state dir (rc=$rc)"
fi

# (i2) HOOK mode keeps the working tree clean: cooldown state lives inside
# .git/, never as a new untracked directory in the target repo.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
run_hook "$d" "$STDIN_CONT_FALSE" >/dev/null
extra=$(git -C "$d" status --porcelain | grep -cv 'package.json')
if [ "$extra" = 0 ] && [ -f "$d/.git/readmedaddy-state" ]; then
	note ok "HOOK cooldown state lives inside .git/, tree stays clean"
else
	note fail "HOOK state should be .git/readmedaddy-state, no untracked litter (extra=$extra)"
fi

# (j) CHECK-RANGE drift: commit changes package.json only -> exit 1 over range.
d=$(setup_repo)
base=$(git -C "$d" rev-parse HEAD)
printf '{"name":"x","v":2}\n' >"$d/package.json"
git -C "$d" commit -qam "bump manifest"
out=$( (cd "$d" && sh "$HOOK" --check --range "$base..HEAD") )
rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'package.json'; then
	note ok "CHECK --range drift exits 1 and names the file"
else
	note fail "CHECK --range drift expected rc=1 naming package.json (rc=$rc, out: $out)"
fi

# (k) CHECK-RANGE clean: README updated in the same range -> exit 0.
d=$(setup_repo)
base=$(git -C "$d" rev-parse HEAD)
printf '{"name":"x","v":2}\n' >"$d/package.json"
printf 'readme v2\n' >"$d/README.md"
git -C "$d" commit -qam "bump manifest + readme"
out=$( (cd "$d" && sh "$HOOK" --check --range "$base..HEAD") )
rc=$?
if [ "$rc" = 0 ]; then
	note ok "CHECK --range with README updated exits 0"
else
	note fail "CHECK --range clean expected rc=0 (rc=$rc, out: $out)"
fi

# (l) CHECK respects project opt-out (.readmedaddy.json enabled:false) -> exit 0.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
printf '{"hook":{"enabled":false}}\n' >"$d/.readmedaddy.json"
out=$( (cd "$d" && sh "$HOOK" --check) )
rc=$?
if [ "$rc" = 0 ]; then
	note ok "CHECK respects enabled:false"
else
	note fail "CHECK with enabled:false expected rc=0 (rc=$rc)"
fi

# (m) CHECK with a bad range fails loudly (exit 2), unlike session mode.
d=$(setup_repo)
out=$( (cd "$d" && sh "$HOOK" --check --range "nonexistent..HEAD" 2>/dev/null) )
rc=$?
if [ "$rc" = 2 ]; then
	note ok "CHECK bad range exits 2"
else
	note fail "CHECK bad range expected rc=2 (rc=$rc)"
fi

# (n) Plain glob watch patterns (docs/*.md) match in --check mode.
d=$(setup_repo)
mkdir -p "$d/docs"
printf 'guide\n' >"$d/docs/guide.md"
git -C "$d" add -A && git -C "$d" commit -qm docs
printf '{"hook":{"watch":["docs/*.md"]}}\n' >"$d/.readmedaddy.json"
printf 'guide v2\n' >"$d/docs/guide.md"
out=$( (cd "$d" && sh "$HOOK" --check 2>/dev/null) )
rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'docs/guide.md'; then
	note ok "CHECK matches plain glob watch patterns"
else
	note fail "CHECK glob docs/*.md expected rc=1 naming the file (rc=$rc, out: $out)"
fi

# (o) Unknown arguments exit 2 loudly — a typo'd --check must never pass green.
d=$(setup_repo)
printf '{"name":"x","v":2}\n' >"$d/package.json"
out=$( (cd "$d" && sh "$HOOK" --chekc </dev/null 2>/dev/null) )
rc=$?
if [ "$rc" = 2 ]; then
	note ok "unknown argument exits 2"
else
	note fail "unknown argument expected rc=2 (rc=$rc, out: $out)"
fi

# (p) A staged rename OUT of a watched path is drift (the entrypoint vanished).
d=$(setup_repo)
mkdir -p "$d/src"
printf 'main\n' >"$d/src/main.js"
git -C "$d" add -A && git -C "$d" commit -qm src
git -C "$d" mv src/main.js retired.js
out=$( (cd "$d" && sh "$HOOK" --check 2>/dev/null) )
rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'src/main.js'; then
	note ok "CHECK catches rename out of a watched path"
else
	note fail "CHECK rename expected rc=1 naming src/main.js (rc=$rc, out: $out)"
fi

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

printf '\n--- summary: %d passed, %d failed ---\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
	exit 1
fi
exit 0
