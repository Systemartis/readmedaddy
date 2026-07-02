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
# writes outside .readmedaddy/state (hook-mode cooldown only).
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
	esac
	[ $# -gt 0 ] && shift
done
if [ "$CHECK_MODE" = 1 ] && [ "$RANGE_SET" = 1 ] && [ -z "$RANGE" ]; then
	printf 'readmedaddy --check: --range requires a value (e.g. origin/main...HEAD)\n' >&2
	exit 2
fi

if [ "$CHECK_MODE" = 0 ]; then
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
	exit 0
fi

# (e) Optional config: .readmedaddy.json
config=$root/.readmedaddy.json
cfg_mode=
cfg_readme=
cfg_watch=
if [ -f "$config" ]; then
	cfg=$(tr -d '\n' <"$config" 2>/dev/null)
	case "$cfg" in
	*'"enabled"'*)
		en=$(printf '%s' "$cfg" | sed -n 's/.*"enabled"[[:space:]]*:[[:space:]]*\([A-Za-z]*\).*/\1/p')
		if [ "$en" = false ]; then
			exit 0
		fi
		;;
	esac
	cfg_mode=$(printf '%s' "$cfg" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_readme=$(printf '%s' "$cfg" | sed -n 's/.*"readme"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	cfg_watch=$(printf '%s' "$cfg" | sed -n 's/.*"watch"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p')
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

# (f) No README -> do not nag.
if [ ! -f "$root/$readme_path" ]; then
	exit 0
fi

# True if $1 matches any watch pattern (simple prefix/suffix glob handling).
match_watch() {
	mw_path=$1
	mw_old=$IFS
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
				set +f
				return 0
				;;
			esac
			;;
		'**/'*)
			mw_suf=${mw_pat#'**/'}
			case "$mw_path" in
			"$mw_suf" | */"$mw_suf")
				IFS=$mw_old
				set +f
				return 0
				;;
			esac
			;;
		*'**'*)
			mw_pre=${mw_pat%%'**'*}
			case "$mw_path" in
			"$mw_pre"*)
				IFS=$mw_old
				set +f
				return 0
				;;
			esac
			;;
		*)
			if [ "$mw_path" = "$mw_pat" ]; then
				IFS=$mw_old
				set +f
				return 0
			fi
			;;
		esac
	done
	IFS=$mw_old
	set +f
	return 1
}

# Best-effort committed drift: newest commit touching a watched path is newer
# than the newest commit touching the README. Prints changed file names if so.
committed_drift() {
	cd_readme_ct=$(git -C "$root" log -1 --format=%ct -- "$readme_path" 2>/dev/null)
	if [ -z "$cd_readme_ct" ]; then
		return 0
	fi
	cd_old=$IFS
	set -f
	IFS='
'
	# shellcheck disable=SC2086
	cd_watched_ct=$(git -C "$root" log -1 --format=%ct -- $watch_list 2>/dev/null)
	# shellcheck disable=SC2086
	cd_files=$(git -C "$root" log -1 --name-only --format= -- $watch_list 2>/dev/null)
	IFS=$cd_old
	set +f
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
	if ! range_changed=$(git -C "$root" diff --name-only "$RANGE" 2>/dev/null); then
		printf 'readmedaddy --check: cannot resolve range: %s\n' "$RANGE" >&2
		exit 2
	fi
	# README updated inside the range -> fresh, regardless of what else moved.
	if printf '%s\n' "$range_changed" | grep -qxF "$readme_path"; then
		exit 0
	fi
	range_drifted=
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
porcelain=$(git -C "$root" status --porcelain 2>/dev/null)
while IFS= read -r pline; do
	if [ -z "$pline" ]; then
		continue
	fi
	ppath=$(printf '%s' "$pline" | cut -c4-)
	case "$ppath" in
	*' -> '*) ppath=${ppath##* -> } ;;
	esac
	case "$ppath" in
	'"'*'"') ppath=$(printf '%s' "$ppath" | sed 's/^"//; s/"$//') ;;
	esac
	if [ "$ppath" = "$readme_path" ]; then
		readme_dirty=1
		continue
	fi
	if match_watch "$ppath"; then
		dirty_watched=$(printf '%s\n%s' "$dirty_watched" "$ppath")
	fi
done <<EOF
$porcelain
EOF

# README being touched too means a refresh is already in progress: no nag.
if [ "$readme_dirty" = 1 ]; then
	exit 0
fi

dirty_watched=$(printf '%s' "$dirty_watched" | grep -v '^$' | sort -u)

if [ -n "$dirty_watched" ]; then
	signal_files=$dirty_watched
else
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
files_sig=$(printf '%s' "$signal_files" | sort -u | tr '\n' ',')
signature="$head_sha|$files_sig"
state_dir=$root/.readmedaddy
state_file=$state_dir/state
stored=$(cat "$state_file" 2>/dev/null)
if [ "$stored" = "$signature" ]; then
	exit 0
fi

record_state() {
	mkdir -p "$state_dir" 2>/dev/null || return 0
	printf '%s\n' "$signature" >"$state_file" 2>/dev/null || return 0
	return 0
}

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
auto | *)
	esc=$(escape_json "$reason")
	printf '{"decision":"block","reason":"%s"}\n' "$esc"
	record_state
	;;
esac

exit 0
