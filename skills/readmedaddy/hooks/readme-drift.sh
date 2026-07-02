#!/bin/sh
# readmedaddy readme-drift: Claude Code Stop hook.
# Detects when README-relevant files changed but the README did not, and
# prompts an in-session refresh through the readmedaddy skill. It never edits
# files itself and never breaks a session: it exits 0 on any error.
#
# POSIX sh. shellcheck-clean. No bashisms.

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

# (a) Read all of stdin.
stdin_data=$(cat 2>/dev/null)

# (b) Loop guard: never continue an already-continued Stop.
if printf '%s' "$stdin_data" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
	exit 0
fi

# (c) Global off switch.
if [ "${README_DADDY_HOOK:-}" = off ]; then
	exit 0
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
