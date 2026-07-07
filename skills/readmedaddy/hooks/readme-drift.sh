#!/bin/sh
# readmedaddy readme-drift: README-vs-code drift detector.
#
# Two modes, one drift logic:
#   (default)          Claude Code Stop hook — reads the Stop event on stdin
#                      and prompts an in-session refresh through the skill.
#                      Never edits files, never breaks a session: exits 0 on
#                      any error.
#   --check [--range R] Standalone, agent-agnostic check for CI, git hooks,
#                      or any other harness. No stdin, no cooldown state.
#                      Exit 0 = fresh, 1 = drift (drifted files on stdout),
#                      2 = usage/git error. Working tree by default; with
#                      --range (e.g. origin/main...HEAD) compares commits.
#                      Respects .readmedaddy.json enabled:false; ignores the
#                      session-scoped README_DADDY_HOOK env switch.
#
# Everything here is local git + POSIX sh: no network, no telemetry, and no
# writes outside .git/readmedaddy-state (hook-mode cooldown only).
# POSIX sh, shellcheck-clean. No bashisms.

# Default set of README-relevant signal paths (baked in; overridable via
# .readmedaddy.json "watch"). Newline-separated.
DEFAULT_WATCH='package.json
pyproject.toml
Cargo.toml
go.mod
go.sum
Gemfile
composer.json
build.gradle
pom.xml
bin/**
src/**
cmd/**
cli/**
.github/workflows/**
install.sh
Makefile
Dockerfile
docker-compose.yml
**/SKILL.md'

# Argument parsing (before stdin: --check mode reads nothing).
CHECK_MODE=0
RANGE=
RANGE_SET=0
CONFIG_OVERRIDE=
CONFIG_SET=0
PRINT_MODE=0
PRINT_KEY=
while [ $# -gt 0 ]; do
	case "$1" in
	--check) CHECK_MODE=1 ;;
	--range)
		shift
		RANGE=${1:-}
		RANGE_SET=1
		;;
	--range=*)
		RANGE=${1#--range=}
		RANGE_SET=1
		;;
	--config)
		shift
		CONFIG_OVERRIDE=${1:-}
		CONFIG_SET=1
		;;
	--config=*)
		CONFIG_OVERRIDE=${1#--config=}
		CONFIG_SET=1
		;;
	--print-config)
		shift
		PRINT_KEY=${1:-}
		PRINT_MODE=1
		;;
	--print-config=*)
		PRINT_KEY=${1#--print-config=}
		PRINT_MODE=1
		;;
	*)
		# A typo'd flag must never pass silently green (e.g. --chekc falling
		# through to hook mode and exiting 0 in a CI gate). Loud, always.
		printf 'readmedaddy: unknown argument: %s (supported: --check [--range A...B])\n' "$1" >&2
		exit 2
		;;
	esac
	[ $# -gt 0 ] && shift
done
if [ "$RANGE_SET" = 1 ] && [ "$CHECK_MODE" = 0 ]; then
	printf 'readmedaddy: --range only makes sense with --check\n' >&2
	exit 2
fi
if [ "$CHECK_MODE" = 1 ] && [ "$RANGE_SET" = 1 ] && [ -z "$RANGE" ]; then
	printf 'readmedaddy --check: --range requires a value (e.g. origin/main...HEAD)\n' >&2
	exit 2
fi
if [ "$CONFIG_SET" = 1 ] && [ -z "$CONFIG_OVERRIDE" ]; then
	printf 'readmedaddy: --config requires a file path (use /dev/null for pure defaults)\n' >&2
	exit 2
fi
if [ "$PRINT_MODE" = 1 ] && [ -z "$PRINT_KEY" ]; then
	printf 'readmedaddy: --print-config requires a key (e.g. guard.pr)\n' >&2
	exit 2
fi
if [ "$PRINT_MODE" = 1 ] && [ "$CHECK_MODE" = 1 ]; then
	printf 'readmedaddy: --print-config and --check are mutually exclusive\n' >&2
	exit 2
fi

if [ "$CHECK_MODE" = 0 ] && [ "$PRINT_MODE" = 0 ]; then
	# (a) Read all of stdin.
	stdin_data=$(cat 2>/dev/null)

	# (b) Loop guard: never continue an already-continued Stop.
	if printf '%s' "$stdin_data" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
		exit 0
	fi

	# (c) Global off switch (session-scoped; deliberately not honored by --check).
	if [ "${README_DADDY_HOOK:-}" = off ]; then
		exit 0
	fi
fi

# (d) Resolve repo root from the hook's CWD.
root=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$root" ]; then
	if [ "$PRINT_MODE" = 1 ] && [ "$CONFIG_SET" = 1 ]; then
		: # --print-config with an explicit --config needs no repo
	elif [ "$CHECK_MODE" = 1 ] || [ "$PRINT_MODE" = 1 ]; then
		printf 'readmedaddy: not inside a git repository (missing actions/checkout?)\n' >&2
		exit 2
	else
		exit 0
	fi
fi

# (e) Optional config: .readmedaddy.json (or an explicit --config FILE —
# CI gates pass the base ref's copy so a PR cannot waive its own gate;
# /dev/null is the defaults-only sentinel and fails the -f test below).
if [ "$CONFIG_SET" = 1 ]; then
	config=$CONFIG_OVERRIDE
else
	config=$root/.readmedaddy.json
fi
cfg_mode=
cfg_readme=
cfg_watch=
en=
cfg_guard_pr=
cfg_guard_main=
cfg_guard_sweep=
cfg_guard_runner=
cfg_guard_command=
if [ -f "$config" ]; then
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
		# Print mode reports config; it never gates.
		if [ "$en" = false ] && [ "$PRINT_MODE" = 0 ]; then
			exit 0
		fi
		;;
	esac
	cfg_mode=$(printf '%s' "$cfg_hook" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_readme=$(printf '%s' "$cfg_hook" | sed -n 's/.*"readme"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_watch=$(printf '%s' "$cfg_hook" | sed -n 's/.*"watch"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p')
	# guard.* keys are collision-safe by schema design (names unique file-wide),
	# so flat whole-file extraction is correct for them.
	cfg_guard_pr=$(printf '%s' "$cfg" | sed -n 's/.*"pr"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_guard_main=$(printf '%s' "$cfg" | sed -n 's/.*"main"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_guard_sweep=$(printf '%s' "$cfg" | sed -n 's/.*"sweep"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_guard_runner=$(printf '%s' "$cfg" | sed -n 's/.*"runner"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_guard_command=$(printf '%s' "$cfg" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

# README path (relative to root).
readme_path=README.md
if [ -n "$cfg_readme" ]; then
	readme_path=$cfg_readme
fi

# Watch list.
if [ -n "$cfg_watch" ]; then
	watch_list=$(printf '%s' "$cfg_watch" | grep -o '"[^"]*"' | sed 's/"//g')
else
	watch_list=$DEFAULT_WATCH
fi
if [ -z "$watch_list" ]; then
	watch_list=$DEFAULT_WATCH
fi

# Mode resolution: config, then env override.
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
	# --check has its own contract and ignores mode, print mode never gates).
	if [ "$CHECK_MODE" = 0 ] && [ "$PRINT_MODE" = 0 ]; then
		exit 0
	fi
	;;
*)
	printf 'readmedaddy: unknown mode "%s" in .readmedaddy.json — treating as notify (valid: auto|notify|enforce|off)\n' "$mode" >&2
	mode=notify
	;;
esac

# --print-config KEY: resolved config values through this one parser, for the
# GitHub Action and scripts. Reports the RAW configured value (defaults when
# absent) — it never gates, never validates. Lint with --lint-config.
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

# (f) No README -> do not nag.
if [ ! -f "$root/$readme_path" ]; then
	exit 0
fi

# True if $1 matches any watch pattern (simple prefix/suffix glob handling).
match_watch() {
	mw_path=$1
	mw_old=$IFS
	# Save the caller's noglob state: restoring blindly with `set +f` would
	# re-enable pathname expansion mid-loop for callers that turned it off.
	case $- in *f*) mw_had_f=1 ;; *) mw_had_f=0 ;; esac
	set -f
	IFS='
'
	# shellcheck disable=SC2086
	for mw_pat in $watch_list; do
		if [ -z "$mw_pat" ]; then
			continue
		fi
		case "$mw_pat" in
		*/'**')
			mw_pre=${mw_pat%/'**'}
			case "$mw_path" in
			"$mw_pre" | "$mw_pre"/*)
				IFS=$mw_old
				if [ "$mw_had_f" = 0 ]; then set +f; fi
				return 0
				;;
			esac
			;;
		'**/'*)
			mw_suf=${mw_pat#'**/'}
			case "$mw_path" in
			"$mw_suf" | */"$mw_suf")
				IFS=$mw_old
				if [ "$mw_had_f" = 0 ]; then set +f; fi
				return 0
				;;
			esac
			;;
		*'**'*)
			mw_pre=${mw_pat%%'**'*}
			case "$mw_path" in
			"$mw_pre"*)
				IFS=$mw_old
				if [ "$mw_had_f" = 0 ]; then set +f; fi
				return 0
				;;
			esac
			;;
		*)
			# Exact match or plain glob (docs/*.md). `case` gives fnmatch
			# semantics even under set -f; * crosses / here, documented.
			# shellcheck disable=SC2254  # unquoted on purpose: glob match
			case "$mw_path" in
			$mw_pat)
				IFS=$mw_old
				if [ "$mw_had_f" = 0 ]; then set +f; fi
				return 0
				;;
			esac
			;;
		esac
	done
	IFS=$mw_old
	if [ "$mw_had_f" = 0 ]; then set +f; fi
	return 1
}

# Best-effort committed drift: newest commit touching a watched path is newer
# than the newest commit touching the README. Prints changed file names if so.
committed_drift() {
	cd_readme_ct=$(git -C "$root" -c core.quotePath=false log -1 --format=%ct -- "$readme_path" 2>/dev/null)
	if [ -z "$cd_readme_ct" ]; then
		return 0
	fi
	cd_old=$IFS
	case $- in *f*) cd_had_f=1 ;; *) cd_had_f=0 ;; esac
	set -f
	IFS='
'
	# shellcheck disable=SC2086
	cd_watched_ct=$(git -C "$root" -c core.quotePath=false log -1 --format=%ct -- $watch_list 2>/dev/null)
	# shellcheck disable=SC2086
	cd_files=$(git -C "$root" -c core.quotePath=false log -1 --name-only --format= -- $watch_list 2>/dev/null)
	IFS=$cd_old
	if [ "$cd_had_f" = 0 ]; then set +f; fi
	if [ -z "$cd_watched_ct" ]; then
		return 0
	fi
	if [ "$cd_watched_ct" -gt "$cd_readme_ct" ]; then
		printf '%s' "$cd_files" | grep -v '^$' | sort -u
	fi
	return 0
}

# Standalone range check (--check --range A...B): compare commits, not the
# working tree. Loud on errors — a misconfigured CI gate should fail visibly.
if [ "$CHECK_MODE" = 1 ] && [ -n "$RANGE" ]; then
	if ! range_changed=$(git -C "$root" -c core.quotePath=false diff --name-only "$RANGE" 2>/dev/null); then
		printf 'readmedaddy --check: cannot resolve range: %s\n' "$RANGE" >&2
		exit 2
	fi
	# README updated inside the range -> fresh, regardless of what else moved.
	if printf '%s\n' "$range_changed" | grep -qxF "$readme_path"; then
		exit 0
	fi
	range_drifted=
	# Paths from git are data, never globs: expansion off for the whole loop.
	set -f
	while IFS= read -r rc_path; do
		if [ -z "$rc_path" ]; then
			continue
		fi
		if match_watch "$rc_path"; then
			range_drifted=$(printf '%s\n%s' "$range_drifted" "$rc_path")
		fi
	done <<EOF
$range_changed
EOF
	set +f
	range_drifted=$(printf '%s' "$range_drifted" | grep -v '^$' | sort -u)
	if [ -z "$range_drifted" ]; then
		exit 0
	fi
	printf '%s\n' "$range_drifted"
	printf 'readmedaddy: these README-relevant files changed in %s but %s did not\n' "$RANGE" "$readme_path" >&2
	exit 1
fi

# (g) Compute working-tree drift.
readme_dirty=0
dirty_watched=
porcelain=$(git -C "$root" -c core.quotePath=false status --porcelain 2>/dev/null)
# Porcelain paths are data, never globs: a file named 'README.m?' must not
# expand to README.md and mask real drift. Expansion off for the whole loop.
set -f
while IFS= read -r pline; do
	if [ -z "$pline" ]; then
		continue
	fi
	ppath=$(printf '%s' "$pline" | cut -c4-)
	# A rename lists 'old -> new'; both sides matter — a file renamed OUT of
	# a watched path is drift too (the watched entrypoint vanished).
	ppaths=$ppath
	case "$ppath" in
	*' -> '*)
		ppaths=$(printf '%s\n%s' "${ppath##* -> }" "${ppath%% -> *}")
		;;
	esac
	p_old=$IFS
	IFS='
'
	for pp in $ppaths; do
		IFS=$p_old
		case "$pp" in
		'"'*'"') pp=$(printf '%s' "$pp" | sed 's/^"//; s/"$//') ;;
		esac
		if [ "$pp" = "$readme_path" ]; then
			readme_dirty=1
		elif match_watch "$pp"; then
			dirty_watched=$(printf '%s\n%s' "$dirty_watched" "$pp")
		fi
		IFS='
'
	done
	IFS=$p_old
done <<EOF
$porcelain
EOF
set +f

# README being touched too means a refresh is already in progress: no nag.
if [ "$readme_dirty" = 1 ]; then
	exit 0
fi

dirty_watched=$(printf '%s' "$dirty_watched" | grep -v '^$' | sort -u)

if [ -n "$dirty_watched" ]; then
	signal_files=$dirty_watched
else
	if [ "$CHECK_MODE" = 1 ] && [ "$(git -C "$root" rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then
		printf 'readmedaddy --check: shallow clone — committed-drift comparison needs full history (use fetch-depth: 0)\n' >&2
		exit 2
	fi
	signal_files=$(committed_drift)
fi

if [ -z "$signal_files" ]; then
	exit 0
fi

# Standalone working-tree check: report and exit before any cooldown state —
# a checker must be idempotent and write nothing.
if [ "$CHECK_MODE" = 1 ]; then
	printf '%s\n' "$signal_files" | sort -u
	printf 'readmedaddy: these README-relevant files changed but %s did not\n' "$readme_path" >&2
	exit 1
fi

# (h) Cooldown: signature of the current drift.
head_sha=$(git -C "$root" rev-parse --short HEAD 2>/dev/null)
if [ -z "$head_sha" ]; then
	head_sha=nohead
fi
# Drift class: working-tree edits vs committed-only drift. The signature is
# HEAD + class (NOT the file list): dirtying a second watched file mid-session
# is the same drift event, not a new nag.
if [ -n "$dirty_watched" ]; then
	drift_class=wt
else
	drift_class=committed
fi
signature="$head_sha|$drift_class"
# Cooldown state lives INSIDE .git/ so the hook never litters the target
# repo's working tree with an untracked directory.
git_dir=$(git -C "$root" rev-parse --git-dir 2>/dev/null)
case "$git_dir" in
"") exit 0 ;;
/*) state_file=$git_dir/readmedaddy-state ;;
*) state_file=$root/$git_dir/readmedaddy-state ;;
esac

record_state() {
	printf '%s\n' "$signature" >"$state_file" 2>/dev/null || return 0
	return 0
}

stored=$(cat "$state_file" 2>/dev/null)
if [ "$stored" = "$signature" ]; then
	exit 0
fi

# First sight of this repo (no state yet) + only committed drift = pre-existing
# staleness from before the hook was installed. Seed the cooldown silently so a
# fresh install never opens with a nag. enforce mode is exempt on purpose.
if [ ! -f "$state_file" ] && [ "$drift_class" = committed ] && [ "$mode" != enforce ]; then
	record_state
	exit 0
fi

# Build the human-readable change list (truncated).
list=$(printf '%s' "$signal_files" | sort -u | tr '\n' ',' | sed 's/^,//; s/,$//')
if [ "${#list}" -gt 200 ]; then
	list="$(printf '%s' "$list" | cut -c1-197)..."
fi
reason="readmedaddy: $list changed but $readme_path did not. Refresh it with the readmedaddy skill -- it will re-detect the archetype and re-rank -- then finish."

escape_json() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# (i) Emit by mode.
case "$mode" in
notify)
	printf '%s\n' "$reason" >&2
	record_state
	;;
enforce)
	esc=$(escape_json "$reason")
	printf '{"decision":"block","reason":"%s"}\n' "$esc"
	;;
auto)
	esc=$(escape_json "$reason")
	printf '{"decision":"block","reason":"%s"}\n' "$esc"
	record_state
	;;
*) : ;; # unreachable: mode is validated above; never block by accident
esac

exit 0
