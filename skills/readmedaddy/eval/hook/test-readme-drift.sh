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

printf '\n--- summary: %d passed, %d failed ---\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
	exit 1
fi
exit 0
