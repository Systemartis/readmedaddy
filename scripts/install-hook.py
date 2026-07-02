#!/usr/bin/env python3
"""Register (or remove) the readmedaddy readme-drift Stop hook in a Claude Code
settings.json.

The hook keeps a project's README honest: when watched files change but the
README does not, it prompts an in-session refresh through the readmedaddy skill.
This installer only wires the hook into settings.json -- it never runs the hook
or touches your code.

Usage:
  install-hook.py --command /abs/path/to/readme-drift.sh   install (user scope)
  install-hook.py --command ... --project                  install to ./.claude
  install-hook.py --command ... --path FILE                install to FILE
  install-hook.py --uninstall [--command ...] [scope]      remove the entry
  install-hook.py --dry-run ...                             show, write nothing
  install-hook.py --selftest                               prove idempotency

Scope precedence: --path > --project > user-global (~/.claude/settings.json).
Merges are read-modify-write with indent=2; other settings and other hooks are
left untouched. Python 3 standard library only.
"""

import argparse
import json
import os
import sys
import tempfile


def settings_path(args):
    """Resolve the settings.json path from the chosen scope."""
    if args.path:
        return os.path.abspath(args.path)
    if args.project:
        return os.path.abspath(os.path.join(".claude", "settings.json"))
    return os.path.join(os.path.expanduser("~"), ".claude", "settings.json")


def load_settings(path):
    """Load settings.json, returning {} if absent. Raises on invalid JSON."""
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    if text.strip() == "":
        return {}
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError("settings root is not a JSON object: " + path)
    return data


def write_settings(path, data):
    """Write settings.json atomically (temp file + rename), indent=2, trailing newline.

    settings.json is the user's whole Claude Code config; a truncating write
    interrupted midway would corrupt it, so never write it in place.
    """
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".settings-", suffix=".json.tmp", dir=parent or ".")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def stop_groups(data):
    """Return the list of Stop hook groups, creating the structure if needed.

    Shape: data["hooks"]["Stop"] -> [ {"hooks": [ {"type","command"}, ... ]} ]
    """
    hooks = data.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("'hooks' is not an object")
    stop = hooks.setdefault("Stop", [])
    if not isinstance(stop, list):
        raise ValueError("'hooks.Stop' is not an array")
    return stop


def command_present(stop, command):
    """True if any Stop group already contains a command entry for `command`."""
    for group in stop:
        if not isinstance(group, dict):
            continue
        for entry in group.get("hooks", []) or []:
            if (
                isinstance(entry, dict)
                and entry.get("type") == "command"
                and entry.get("command") == command
            ):
                return True
    return False


def add_command(stop, command):
    """Append a Stop hook group for `command`. Caller checks presence first."""
    stop.append({"hooks": [{"type": "command", "command": command}]})


def remove_command(data, command):
    """Remove every Stop command entry matching `command`. Prune empties.

    Returns the number of command entries removed.
    """
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return 0
    stop = hooks.get("Stop")
    if not isinstance(stop, list):
        return 0

    removed = 0
    new_stop = []
    for group in stop:
        if not isinstance(group, dict):
            new_stop.append(group)
            continue
        entries = group.get("hooks")
        if not isinstance(entries, list):
            new_stop.append(group)
            continue
        kept = []
        for entry in entries:
            if (
                isinstance(entry, dict)
                and entry.get("type") == "command"
                and entry.get("command") == command
            ):
                removed += 1
            else:
                kept.append(entry)
        if kept:
            group["hooks"] = kept
            new_stop.append(group)
        # else: drop the now-empty group

    # Prune empty containers so we never leave dangling structure behind.
    if new_stop:
        hooks["Stop"] = new_stop
    else:
        hooks.pop("Stop", None)
    if not hooks:
        data.pop("hooks", None)
    return removed


def do_install(args):
    path = settings_path(args)
    command = args.command
    data = load_settings(path)
    stop = stop_groups(data)

    if command_present(stop, command):
        print("already-present: Stop hook -> " + command)
        print("  settings: " + path)
        return 0

    add_command(stop, command)
    if args.dry_run:
        print("would-add: Stop hook -> " + command)
        print("  settings: " + path)
        return 0

    write_settings(path, data)
    print("added: Stop hook -> " + command)
    print("  settings: " + path)
    return 0


def do_uninstall(args):
    path = settings_path(args)
    data = load_settings(path)

    if args.command:
        targets = [args.command]
    else:
        # No --command given: remove any Stop entry that looks like our hook.
        targets = []
        hooks = data.get("hooks", {})
        stop = hooks.get("Stop", []) if isinstance(hooks, dict) else []
        if isinstance(stop, list):
            for group in stop:
                if not isinstance(group, dict):
                    continue
                for entry in group.get("hooks", []) or []:
                    if (
                        isinstance(entry, dict)
                        and entry.get("type") == "command"
                        and isinstance(entry.get("command"), str)
                        and "readme-drift" in entry["command"]
                    ):
                        targets.append(entry["command"])

    if not targets:
        print("not-present: no matching Stop hook found")
        print("  settings: " + path)
        return 0

    total = 0
    for target in targets:
        # Re-check existence per target without mutating on a dry run.
        if args.dry_run:
            if command_present(stop_groups(load_settings(path)), target):
                print("would-remove: Stop hook -> " + target)
                total += 1
            continue
        removed = remove_command(data, target)
        total += removed
        if removed:
            print("removed: Stop hook -> " + target + " (x" + str(removed) + ")")

    if args.dry_run:
        if total == 0:
            print("not-present: no matching Stop hook found")
        print("  settings: " + path)
        return 0

    if total == 0:
        print("not-present: no matching Stop hook found")
        print("  settings: " + path)
        return 0

    write_settings(path, data)
    print("  settings: " + path)
    return 0


def selftest():
    """Merge twice (idempotency), confirm coexistence, then uninstall.

    Asserts JSON stays valid and unrelated keys + other hooks survive.
    """
    fd, path = tempfile.mkstemp(prefix="readmedaddy-selftest-", suffix=".json")
    os.close(fd)
    try:
        command = "/opt/readmedaddy/hooks/readme-drift.sh"

        # Seed with unrelated settings and an unrelated Stop hook that must
        # survive every operation below.
        seed = {
            "model": "claude-sonnet",
            "permissions": {"allow": ["Bash(ls:*)"]},
            "hooks": {
                "Stop": [
                    {"hooks": [{"type": "command", "command": "/other/keep.sh"}]}
                ],
                "PreToolUse": [
                    {"hooks": [{"type": "command", "command": "/pre/tool.sh"}]}
                ],
            },
        }
        write_settings(path, seed)

        ns = argparse.Namespace(
            command=command, path=path, project=False, dry_run=False
        )

        # First install adds our entry.
        assert do_install(ns) == 0
        data = load_settings(path)
        assert command_present(stop_groups(data), command), "install failed"
        assert command_present(stop_groups(data), "/other/keep.sh"), "clobbered other Stop hook"
        assert data["model"] == "claude-sonnet", "clobbered unrelated key"
        assert data["permissions"]["allow"] == ["Bash(ls:*)"], "clobbered permissions"
        # PreToolUse hook untouched (command_present takes a list of groups).
        assert command_present(
            data["hooks"]["PreToolUse"], "/pre/tool.sh"
        ), "clobbered PreToolUse hook"

        # Second install is a no-op: count of our command stays exactly one.
        assert do_install(ns) == 0
        data = load_settings(path)
        count = sum(
            1
            for group in data["hooks"]["Stop"]
            if isinstance(group, dict)
            for entry in group.get("hooks", [])
            if isinstance(entry, dict) and entry.get("command") == command
        )
        assert count == 1, "not idempotent: found " + str(count) + " entries"

        # Dry-run install must not write a duplicate either.
        ns_dry = argparse.Namespace(
            command=command, path=path, project=False, dry_run=True
        )
        assert do_install(ns_dry) == 0
        data = load_settings(path)
        count = sum(
            1
            for group in data["hooks"]["Stop"]
            if isinstance(group, dict)
            for entry in group.get("hooks", [])
            if isinstance(entry, dict) and entry.get("command") == command
        )
        assert count == 1, "dry-run mutated state"

        # Uninstall removes ours, keeps the other Stop hook + unrelated keys.
        ns_un = argparse.Namespace(
            command=command, path=path, project=False, dry_run=False
        )
        assert do_uninstall(ns_un) == 0
        data = load_settings(path)
        assert not command_present(stop_groups(data), command), "uninstall failed"
        assert command_present(stop_groups(data), "/other/keep.sh"), "uninstall removed other Stop hook"
        assert data["model"] == "claude-sonnet", "uninstall clobbered unrelated key"
        assert data["hooks"]["PreToolUse"][0]["hooks"][0]["command"] == "/pre/tool.sh"

        # Uninstall again is a clean no-op.
        assert do_uninstall(ns_un) == 0

        # File is still valid JSON on disk.
        with open(path, "r", encoding="utf-8") as fh:
            json.load(fh)

        print("selftest: PASS")
        return 0
    except AssertionError as exc:
        print("selftest: FAIL -- " + str(exc), file=sys.stderr)
        return 1
    finally:
        try:
            os.remove(path)
        except OSError:
            pass


def build_parser():
    parser = argparse.ArgumentParser(
        prog="install-hook.py",
        description="Register the readmedaddy readme-drift Stop hook in a "
        "Claude Code settings.json.",
    )
    parser.add_argument(
        "--command",
        help="Absolute path to readme-drift.sh (required to install).",
    )
    parser.add_argument(
        "--project",
        action="store_true",
        help="Use ./.claude/settings.json instead of the user-global file.",
    )
    parser.add_argument(
        "--path",
        help="Explicit settings.json path (overrides --project).",
    )
    parser.add_argument(
        "--uninstall",
        action="store_true",
        help="Remove the hook entry instead of adding it.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would change; write nothing.",
    )
    parser.add_argument(
        "--selftest",
        action="store_true",
        help="Run an in-memory idempotency self-test and exit.",
    )
    return parser


def main(argv):
    args = build_parser().parse_args(argv)

    if args.selftest:
        return selftest()

    try:
        if args.uninstall:
            return do_uninstall(args)
        if not args.command:
            print(
                "error: --command PATH is required to install "
                "(or pass --uninstall).",
                file=sys.stderr,
            )
            return 2
        return do_install(args)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print("error: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
