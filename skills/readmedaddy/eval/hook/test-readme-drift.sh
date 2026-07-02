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

printf '\n--- summary: %d passed, %d failed ---\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
	exit 1
fi
exit 0
