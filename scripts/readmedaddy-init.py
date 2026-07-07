#!/usr/bin/env python3
"""readmedaddy init — the guard wizard.

Configures the whole readmedaddy system for one repo in one sitting: the
drift hook, the CI guard (PR / merge queue / push-to-main / weekly sweep),
the badge, and (optionally) the Claude Code Stop-hook registration. Saves
everything to .readmedaddy.json + .github/workflows/readmedaddy.yml.

Faces:
  interactive   run inside a repo with a TTY: detect-then-confirm, at most
                six questions, Enter accepts the detected default.
  flags         every question has a flag; non-TTY without --yes (or the
                full flag set) is a hard error naming the missing flags.
  --print       emit the resulting config JSON to stdout, write nothing —
                the agent face previews with this, then re-runs to write.

Guarantees (binding):
  * Zero network. Detection is pure local git; this script never fetches.
  * Writes only what the preview enumerated: .readmedaddy.json, the workflow
    file, one badge line, the hook registration. Config is written
    atomically, the workflow last.
  * Re-run = reconfigure: existing config seeds the defaults; hand-edited
    keys in untouched categories survive byte-for-byte.
  * Humor lives in copy only; every offered option is honored.

python3 stdlib only. --selftest proves the golden behaviors in temp repos.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

SCHEMA_URL = (
    "https://raw.githubusercontent.com/Systemartis/readmedaddy/main/"
    "schema/readmedaddy.schema.json"
)

DEFAULT_WATCH = [
    "package.json", "pyproject.toml", "Cargo.toml", "go.mod", "go.sum",
    "Gemfile", "composer.json", "build.gradle", "pom.xml",
    "bin/**", "src/**", "cmd/**", "cli/**", ".github/workflows/**",
    "install.sh", "Makefile", "Dockerfile", "docker-compose.yml",
    "**/SKILL.md",
]

# The layered preset the spec recommends — NOT the detector's absent-key
# defaults. The wizard's job is to opt you into the stack.
PRESET = {"pr": "comment", "main": "issue", "sweep": "weekly"}

MODES = ["auto", "notify", "enforce", "off"]
PR_CHOICES = ["comment", "fail", "off"]
MAIN_CHOICES = ["issue", "fail", "off"]
SWEEP_CHOICES = ["weekly", "off"]
RUNNER_CHOICES = ["off", "claude", "command"]

COST_LINES = {
    "comment": "one ~20s CI job per PR push; advisory sticky comment; $0 public / pennies private",
    "fail": "same job as comment, but red X blocks merge when drifted (pair with a required check)",
    "issue": "one job per push to the default branch; maintains a single README-health issue",
    "weekly": "one job per week; catches drift that arrives without a push",
}

RULESET_RECIPE = """\
# Make the drift check required (repo admin; rulesets API — additive, never
# clobbers other rules). Start with "evaluate" to dry-run, then "active":
gh api -X POST repos/OWNER/REPO/rulesets --input - <<'JSON'
{
  "name": "readmedaddy: README drift check",
  "target": "branch",
  "enforcement": "evaluate",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "do_not_enforce_on_create": false,
        "required_status_checks": [ { "context": "readme-drift" } ] } }
  ]
}
JSON
# Click-path: Settings -> Rules -> Rulesets -> New branch ruleset ->
# Require status checks to pass -> add context "readme-drift".
# Notes: the context string must equal the workflow job id (readme-drift).
# Free-plan PRIVATE repos cannot use rulesets (public repos: all plans).
"""


def sh(args, cwd=None):
    """Run a git command; return stdout or None on failure. Never raises."""
    try:
        r = subprocess.run(
            args, cwd=cwd, capture_output=True, text=True, timeout=30
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0:
        return None
    return r.stdout.strip()


# --- detection pass (all local, zero network) --------------------------------

def detect(cwd):
    d = {}
    d["root"] = sh(["git", "rev-parse", "--show-toplevel"], cwd=cwd)
    if not d["root"]:
        return d
    root = d["root"]

    files = (sh(["git", "-C", root, "ls-files"]) or "").splitlines()
    d["files"] = files

    readmes = [f for f in files if re.fullmatch(r"readme\.(md|rst|txt)", f, re.I)]
    d["readme"] = "README.md" if "README.md" in readmes else (
        readmes[0] if readmes else None)

    head = sh(["git", "-C", root, "symbolic-ref", "--short",
               "refs/remotes/origin/HEAD"])
    if head and "/" in head:
        d["default_branch"] = head.split("/", 1)[1]
    else:
        branches = sh(["git", "-C", root, "branch", "--list", "main", "master"]) or ""
        d["default_branch"] = "main" if "main" in branches else (
            "master" if "master" in branches else "main")

    origin = sh(["git", "-C", root, "remote", "get-url", "origin"]) or ""
    d["github"] = "github.com" in origin
    m = re.search(r"github\.com[:/]([^/]+)/([^/.]+)", origin)
    d["owner_repo"] = f"{m.group(1)}/{m.group(2)}" if m else None

    d["monorepo"] = any(
        f in files for f in ("pnpm-workspace.yaml", "lerna.json", "go.work",
                             "turbo.json")
    ) or ('"workspaces"' in _read(os.path.join(root, "package.json")))

    wf_dir = os.path.join(root, ".github", "workflows")
    d["workflows"] = sorted(os.listdir(wf_dir)) if os.path.isdir(wf_dir) else []

    d["watch"] = prune_watch(files)

    cfg_path = os.path.join(root, ".readmedaddy.json")
    d["existing"] = None
    if os.path.exists(cfg_path):
        try:
            d["existing"] = json.load(open(cfg_path, encoding="utf-8"))
        except (ValueError, OSError):
            d["existing"] = "unparseable"

    claude_settings = os.path.join(os.path.expanduser("~"), ".claude",
                                   "settings.json")
    d["claude"] = os.path.isdir(os.path.dirname(claude_settings))
    d["hook_registered"] = False
    if os.path.exists(claude_settings):
        d["hook_registered"] = "readme-drift" in _read(claude_settings)
    return d


def _read(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return ""


def prune_watch(files):
    """Default watch list filtered to patterns that match something here."""
    kept = []
    fileset = set(files)
    for pat in DEFAULT_WATCH:
        if pat in fileset:
            kept.append(pat)
        elif pat.endswith("/**"):
            prefix = pat[:-3]
            if any(f == prefix or f.startswith(prefix + "/") for f in files):
                kept.append(pat)
        elif pat.startswith("**/"):
            suffix = pat[3:]
            if any(f == suffix or f.endswith("/" + suffix) for f in files):
                kept.append(pat)
    return kept or list(DEFAULT_WATCH)


# --- config assembly ----------------------------------------------------------

def build_config(existing, answers):
    """Merge answers into the existing config; untouched keys survive."""
    cfg = {}
    if isinstance(existing, dict):
        cfg = json.loads(json.dumps(existing))  # deep copy
    cfg.pop("$schema", None)
    out: dict = {"$schema": SCHEMA_URL}
    out.update(cfg)
    hook = out.setdefault("hook", {})
    hook.setdefault("enabled", True)
    hook["mode"] = answers["mode"]
    hook["readme"] = answers["readme"]
    hook["watch"] = answers["watch"]
    guard = out.setdefault("guard", {})
    guard["pr"] = answers["pr"]
    guard["main"] = answers["main"]
    guard["sweep"] = answers["sweep"]
    autofix = guard.setdefault("autofix", {})
    autofix["runner"] = answers["autofix_runner"]
    autofix["command"] = answers["autofix_command"]
    return out


def build_workflow(answers, default_branch):
    """The complete detection workflow the wizard writes."""
    triggers = []
    if answers["pr"] != "off":
        triggers.append("  pull_request:")
        triggers.append("  merge_group:")
    if answers["main"] != "off":
        triggers.append("  push:")
        triggers.append(f"    branches: [{default_branch}]")
    if answers["sweep"] == "weekly":
        triggers.append("  schedule:")
        triggers.append('    - cron: "23 6 * * 1"  # Mondays 06:23 UTC — off the :00 stampede')
        triggers.append("  workflow_dispatch:")
    if not triggers:
        return None
    on_block = "\n".join(triggers)
    return f"""\
# Generated by readmedaddy init. Safe to edit; re-running init reconfigures.
# Everything the check does is local git on this runner — no LLM, no network
# calls of its own, nothing leaves GitHub's infrastructure.
name: readmedaddy
on:
{on_block}
permissions:
  contents: read
  pull-requests: write
  issues: write
jobs:
  readme-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0    # the range diff needs the merge-base
      - uses: Systemartis/readmedaddy@v0
"""


def badge_line(owner_repo):
    if not owner_repo:
        return None
    return (f"[![readme fresh](https://github.com/{owner_repo}/actions/"
            f"workflows/readmedaddy.yml/badge.svg)]"
            f"(https://github.com/{owner_repo}/actions/workflows/readmedaddy.yml)")


def atomic_write(path, content):
    parent = os.path.dirname(path) or "."
    os.makedirs(parent, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".rmd-init-", dir=parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(content)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


# --- interaction --------------------------------------------------------------

def ask_choice(question, choices, default, notes=None):
    print(f"\n{question}")
    for i, c in enumerate(choices, 1):
        mark = " (default)" if c == default else ""
        note = f"  — {notes[c]}" if notes and c in notes else ""
        print(f"  [{i}] {c}{mark}{note}")
    while True:
        raw = input("> ").strip()
        if raw == "":
            return default
        if raw.isdigit() and 1 <= int(raw) <= len(choices):
            return choices[int(raw) - 1]
        if raw in choices:
            return raw
        print(f"pick 1-{len(choices)} or a value; Enter = {default}")


def ask_yn(question, default=True):
    suffix = "[Y/n]" if default else "[y/N]"
    raw = input(f"\n{question} {suffix} ").strip().lower()
    if raw == "":
        return default
    return raw.startswith("y")


# --- main ---------------------------------------------------------------------

def build_parser():
    p = argparse.ArgumentParser(
        prog="readmedaddy-init",
        description="Configure readmedaddy for this repo (config + CI guard "
                    "+ badge + hook). Zero network; writes only what the "
                    "preview shows.",
    )
    p.add_argument("--mode", choices=MODES, help="Stop-hook nudge mode")
    p.add_argument("--readme", help="README path (relative to repo root)")
    p.add_argument("--watch", help="comma-separated watch patterns")
    p.add_argument("--pr", "--gate", dest="pr", choices=PR_CHOICES,
                   help="PR/merge-queue response")
    p.add_argument("--main", choices=MAIN_CHOICES,
                   help="default-branch push response")
    p.add_argument("--sweep", choices=SWEEP_CHOICES, help="scheduled sweep")
    p.add_argument("--autofix-runner", choices=RUNNER_CHOICES,
                   help="opt-in LLM fix tier (costs tokens + needs a secret)")
    p.add_argument("--autofix-command", default=None,
                   help="agent CLI when runner=command")
    badge = p.add_mutually_exclusive_group()
    badge.add_argument("--badge", dest="badge", action="store_true",
                       default=None, help="insert the workflow badge")
    badge.add_argument("--no-badge", dest="badge", action="store_false",
                       help="skip the badge")
    p.add_argument("--no-hook", action="store_true",
                   help="skip Claude Code hook registration")
    p.add_argument("--yes", action="store_true",
                   help="accept every default (the recommended preset); zero questions")
    p.add_argument("--print", dest="print_only", action="store_true",
                   help="emit the config JSON to stdout; write nothing")
    p.add_argument("--apply-required-check", action="store_true",
                   help="print the required-check recipe (apply ships in v0.3.x)")
    p.add_argument("--onboard", action="store_true",
                   help="print the onboarding-PR recipe (ships in v0.3.x)")
    p.add_argument("--selftest", action="store_true", help=argparse.SUPPRESS)
    return p


def main(argv):
    args = build_parser().parse_args(argv)
    if args.selftest:
        return selftest()

    det = detect(os.getcwd())
    if not det.get("root"):
        print("error: not inside a git repository.", file=sys.stderr)
        return 2
    root = det["root"]

    existing = det["existing"]
    if existing == "unparseable":
        print("error: .readmedaddy.json exists but is not valid JSON — fix or "
              "remove it first (readme-drift.sh --lint-config).", file=sys.stderr)
        return 2
    reconfigure = isinstance(existing, dict)
    ex_hook = (existing or {}).get("hook", {})
    ex_guard = (existing or {}).get("guard", {})
    ex_autofix = ex_guard.get("autofix", {})

    # Per-question defaults: existing config > detection > preset.
    defaults = {
        "readme": ex_hook.get("readme") or det.get("readme") or "README.md",
        "watch": ex_hook.get("watch") or det["watch"],
        "mode": ex_hook.get("mode", "auto"),
        "pr": ex_guard.get("pr", PRESET["pr"] if det["github"] else "off"),
        "main": ex_guard.get("main", PRESET["main"] if det["github"] else "off"),
        "sweep": ex_guard.get("sweep", PRESET["sweep"] if det["github"] else "off"),
        "autofix_runner": ex_autofix.get("runner", "off"),
        "autofix_command": ex_autofix.get("command", ""),
        "badge": det["github"],
        "hook_reg": det["claude"] and not det["hook_registered"] and not args.no_hook,
    }

    interactive = sys.stdin.isatty() and not args.yes
    if not interactive and not args.yes:
        missing = [f for f, v in (("--mode", args.mode), ("--pr", args.pr))
                   if v is None]
        if missing:
            print("error: not a TTY and no --yes — pass "
                  f"{' '.join(missing)} (or --yes for the recommended "
                  "preset). Every question has a flag; see --help.",
                  file=sys.stderr)
            return 2

    answers = {}
    # Flags always win; questions only fire interactively for unset flags.
    def resolve(key, flag_value, question):
        if flag_value is not None:
            answers[key] = flag_value
        elif interactive:
            answers[key] = question()
        else:
            answers[key] = defaults[key]

    if interactive:
        print("readmedaddy init — detect-then-confirm. Enter accepts the "
              "detected default; nothing is written before the preview.")
        if reconfigure:
            print("(existing .readmedaddy.json found — reconfiguring; "
                  "current values are the defaults)")
        if det["monorepo"]:
            print("(monorepo detected — v0.3.0 watches the root README; "
                  "per-package targets are on the roadmap)")

    resolve("readme", args.readme,
            lambda: input(f"\nREADME path [{defaults['readme']}]: ").strip()
            or defaults["readme"])

    def watch_q():
        print(f"\nWatch list ({len(defaults['watch'])} patterns matched this "
              "repo):")
        for w in defaults["watch"]:
            print(f"  {w}")
        raw = input("Enter = keep; or type comma-separated patterns: ").strip()
        return [w.strip() for w in raw.split(",") if w.strip()] or defaults["watch"]
    resolve("watch",
            [w.strip() for w in args.watch.split(",")] if args.watch else None,
            watch_q)

    resolve("mode", args.mode,
            lambda: ask_choice("Session-end nudge (Claude Code Stop hook):",
                               MODES, defaults["mode"]))

    if args.no_hook:
        answers["hook_reg"] = False
    elif interactive and defaults["hook_reg"]:
        answers["hook_reg"] = ask_yn("Register the Stop hook with Claude Code now?")
    else:
        answers["hook_reg"] = defaults["hook_reg"]

    if det["github"]:
        resolve("pr", args.pr,
                lambda: ask_choice("Pull-request gate:", PR_CHOICES,
                                   defaults["pr"], COST_LINES))
        resolve("main", args.main,
                lambda: ask_choice("Merge-to-main safety net:", MAIN_CHOICES,
                                   defaults["main"], COST_LINES))
        resolve("sweep", args.sweep,
                lambda: ask_choice("Weekly freshness sweep:", SWEEP_CHOICES,
                                   defaults["sweep"], COST_LINES))
        resolve("autofix_runner", args.autofix_runner,
                lambda: ask_choice(
                    "Auto-fix tier (an agent refreshes the README and opens "
                    "a PR — costs LLM tokens, needs an API-key secret):",
                    RUNNER_CHOICES, defaults["autofix_runner"]))
        answers["autofix_command"] = (args.autofix_command
                                      if args.autofix_command is not None
                                      else defaults["autofix_command"])
        if args.badge is not None:
            answers["badge"] = args.badge
        elif interactive:
            answers["badge"] = ask_yn("Add the workflow badge to the README?")
        else:
            answers["badge"] = defaults["badge"]
    else:
        for k in ("pr", "main", "sweep", "autofix_runner"):
            answers[k] = "off"
        answers["autofix_command"] = ""
        answers["badge"] = False

    cfg = build_config(existing, answers)
    cfg_text = json.dumps(cfg, indent=2) + "\n"

    if args.print_only:
        print(cfg_text, end="")
        return 0

    workflow = build_workflow(answers, det["default_branch"]) if det["github"] else None
    badge = badge_line(det["owner_repo"]) if answers.get("badge") else None
    readme_path = os.path.join(root, answers["readme"])
    badge_needed = bool(badge) and badge not in _read(readme_path)

    # Preview: everything that will be written, nothing else.
    to_write = [".readmedaddy.json"]
    if workflow:
        wf_path = ".github/workflows/readmedaddy.yml"
        if "readmedaddy.yml" in det["workflows"]:
            wf_note = f"{wf_path} (overwrites the existing readmedaddy.yml)"
        else:
            wf_note = wf_path
        to_write.append(wf_note)
    if badge_needed:
        to_write.append(f"{answers['readme']} (one badge line after the title)")
    if answers["hook_reg"]:
        to_write.append("~/.claude/settings.json (Stop hook entry via install-hook.py)")

    print("\nWill write:")
    for item in to_write:
        print(f"  - {item}")
    if interactive and not ask_yn("Write these?"):
        print("aborted — nothing written.")
        return 0

    # Writes: config atomically first, workflow last (spec §7).
    atomic_write(os.path.join(root, ".readmedaddy.json"), cfg_text)
    if badge_needed:
        content = _read(readme_path)
        lines = content.splitlines(keepends=True)
        for i, line in enumerate(lines):
            if line.startswith("#"):
                lines.insert(i + 1, "\n" + badge + "\n")
                break
        else:
            lines.insert(0, badge + "\n\n")
        atomic_write(readme_path, "".join(lines))
    if answers["hook_reg"]:
        installer = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 "install-hook.py")
        hook_path = os.path.expanduser(
            "~/.claude/skills/readmedaddy/hooks/readme-drift.sh")
        if not os.path.exists(hook_path):
            hook_path = os.path.join(
                os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                "skills", "readmedaddy", "hooks", "readme-drift.sh")
        r = subprocess.run([sys.executable, installer, "--command", hook_path],
                           capture_output=True, text=True)
        print(r.stdout.strip() or r.stderr.strip())
    if workflow:
        atomic_write(os.path.join(root, ".github", "workflows",
                                  "readmedaddy.yml"), workflow)

    # Prove it works before the user leaves: run the detector live.
    drift_sh = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "skills", "readmedaddy", "hooks", "readme-drift.sh")
    print("\nLive check (readme-drift.sh --check):")
    r = subprocess.run(["sh", drift_sh, "--check"], cwd=root,
                       capture_output=True, text=True)
    if r.returncode == 0:
        print("  fresh — no README drift right now.")
    elif r.returncode == 1:
        print("  drift detected (expected if you just changed code):")
        for line in r.stdout.strip().splitlines():
            print(f"    {line}")
    else:
        print(f"  checker exited {r.returncode}: {r.stderr.strip()}")

    if args.apply_required_check or args.onboard:
        print("\n--- required-check recipe (auto-apply ships in v0.3.x) ---")
        recipe = RULESET_RECIPE
        if det["owner_repo"]:
            recipe = recipe.replace("OWNER/REPO", det["owner_repo"])
        print(recipe)

    print("\nDone. Next steps:")
    print("  - test a range:   readme-drift.sh --check --range "
          f"origin/{det['default_branch']}...HEAD")
    print("  - silence a session:  README_DADDY_HOOK=off")
    print("  - reconfigure any time: re-run this wizard (current values "
          "become the defaults)")
    return 0


# --- selftest -----------------------------------------------------------------

def selftest():
    """Golden tests in throwaway repos. Zero network; asserts the contracts."""
    import shutil

    failures = []

    def check(cond, name):
        print(("PASS: " if cond else "FAIL: ") + name)
        if not cond:
            failures.append(name)

    tmp = tempfile.mkdtemp(prefix="rmd-init-selftest.")
    repo = os.path.join(tmp, "repo")
    os.makedirs(repo)
    env = dict(os.environ)
    env["GIT_CONFIG_GLOBAL"] = "/dev/null"
    env["GIT_CONFIG_SYSTEM"] = "/dev/null"

    def git(*a):
        subprocess.run(["git", *a], cwd=repo, env=env, check=True,
                       capture_output=True)

    git("init", "-q", "-b", "main", ".")
    git("config", "user.email", "t@t.invalid")
    git("config", "user.name", "t")
    git("config", "commit.gpgsign", "false")
    open(f"{repo}/README.md", "w").write("# x\n")
    open(f"{repo}/package.json", "w").write("{}\n")
    git("add", "-A")
    git("commit", "-qm", "init")

    me = os.path.abspath(__file__)
    drift = os.path.join(os.path.dirname(os.path.dirname(me)),
                         "skills", "readmedaddy", "hooks", "readme-drift.sh")

    def run(*flags):
        return subprocess.run([sys.executable, me, *flags], cwd=repo, env=env,
                              capture_output=True, text=True, stdin=subprocess.DEVNULL)

    # (1) --yes --print emits valid JSON that --lint-config accepts.
    r = run("--yes", "--print", "--no-hook")
    ok = r.returncode == 0
    cfg = None
    if ok:
        try:
            cfg = json.loads(r.stdout)
        except ValueError:
            ok = False
    if ok:
        p = os.path.join(tmp, "print.json")
        open(p, "w").write(r.stdout)
        lint = subprocess.run(["sh", drift, "--lint-config", "--config", p],
                              cwd=repo, env=env, capture_output=True, text=True)
        ok = lint.returncode == 0
    check(ok, "--yes --print emits lint-clean JSON")

    # (2) --yes preset: guard pr=comment main=issue sweep=weekly runner=off.
    # (no GitHub remote in the fixture -> everything off; add a remote.)
    git("remote", "add", "origin", "https://github.com/acme/demo.git")
    r = run("--yes", "--print", "--no-hook")
    cfg = json.loads(r.stdout)
    g = cfg.get("guard", {})
    check(g.get("pr") == "comment" and g.get("main") == "issue"
          and g.get("sweep") == "weekly"
          and g.get("autofix", {}).get("runner") == "off",
          "--yes uses the recommended preset (not detector defaults)")

    # (3) --print writes nothing.
    check(not os.path.exists(f"{repo}/.readmedaddy.json")
          and not os.path.exists(f"{repo}/.github"),
          "--print writes nothing to disk")

    # (4) real write is idempotent: two --yes runs, identical bytes.
    r1 = run("--yes", "--no-hook", "--no-badge")
    c1 = _read(f"{repo}/.readmedaddy.json")
    w1 = _read(f"{repo}/.github/workflows/readmedaddy.yml")
    r2 = run("--yes", "--no-hook", "--no-badge")
    c2 = _read(f"{repo}/.readmedaddy.json")
    w2 = _read(f"{repo}/.github/workflows/readmedaddy.yml")
    check(r1.returncode == 0 and r2.returncode == 0 and c1 == c2 and w1 == w2
          and c1 != "",
          "run twice -> byte-identical config and workflow")

    # (5) reconfigure preserves hand-edited keys in untouched categories.
    cfg = json.loads(_read(f"{repo}/.readmedaddy.json"))
    cfg["hook"]["watch"] = ["custom/**"]
    open(f"{repo}/.readmedaddy.json", "w").write(json.dumps(cfg, indent=2))
    r = run("--yes", "--no-hook", "--no-badge", "--mode", "notify")
    cfg2 = json.loads(_read(f"{repo}/.readmedaddy.json"))
    check(cfg2["hook"]["watch"] == ["custom/**"]
          and cfg2["hook"]["mode"] == "notify",
          "reconfigure: hand-edited watch survives a mode change")

    # (6) non-TTY without --yes exits 2 naming the flags.
    r = run("--mode", "auto")  # --pr missing
    check(r.returncode == 2 and "--pr" in r.stderr,
          "non-TTY without --yes names the missing flags")

    # (7) unknown flag exits 2 (argparse).
    r = run("--nonsense")
    check(r.returncode == 2, "unknown flag exits 2")

    # (8) generated workflow has the safety rails.
    check("permissions:" in w1 and "fetch-depth: 0" in w1
          and "readme-drift:" in w1 and "@v0" in w1,
          "workflow: permissions block, fetch-depth 0, job id, @v0 pin")

    shutil.rmtree(tmp, ignore_errors=True)
    print(f"\n--- selftest: {8 - len(failures)} passed, {len(failures)} failed ---")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
