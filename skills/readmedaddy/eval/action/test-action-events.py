#!/usr/bin/env python3
"""Event-matrix test for action.yml's check step.

Extracts the composite action's `check` run block, substitutes the GitHub
expressions with test-controlled values, and executes it under bash against
throwaway git repos — the same drift logic CI runs, verified locally.

Requires pyyaml to parse action.yml; exits 0 with a SKIP note when absent
(the sh harness still covers the detector itself). Python 3 stdlib + pyyaml,
no network.
"""

import os
import subprocess
import sys
import tempfile

try:
    import yaml
except ImportError:
    print("SKIP: pyyaml not installed — action event-matrix test not run")
    sys.exit(0)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))))))
ACTION = os.path.join(ROOT, "action.yml")

FAILURES = []


def check(cond, name, detail=""):
    if cond:
        print(f"PASS: {name}")
    else:
        FAILURES.append(name)
        print(f"FAIL: {name} {detail}")


def main():
    doc = yaml.safe_load(open(ACTION))
    body = [s for s in doc["runs"]["steps"] if s.get("id") == "check"][0]["run"]
    body = body.replace("${{ github.action_path }}", ROOT)

    tmp = tempfile.mkdtemp(prefix="rmd-action-test.")
    repo = os.path.join(tmp, "repo")
    os.makedirs(repo)

    def sh(*cmd, cwd=repo):
        return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                              check=True).stdout.strip()

    def run_check(env_over):
        outfile = os.path.join(tmp, "out.txt")
        open(outfile, "w").close()
        env = dict(os.environ)
        env.update({
            "BASE_REF": "", "EVENT": "", "MG_BASE_SHA": "", "MG_HEAD_SHA": "",
            "PUSH_BEFORE": "", "PUSH_SHA": "", "INPUT_MODE": "comment",
            "GITHUB_OUTPUT": outfile, "RUNNER_TEMP": tmp,
            "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null",
        })
        env.update(env_over)
        r = subprocess.run(["bash", "-c", body], cwd=repo, env=env,
                           capture_output=True, text=True)
        return r, open(outfile).read()

    # Fixture: base has guard.pr=fail; PR head tries enabled:false + drift.
    sh("git", "init", "-q", "-b", "main", ".")
    sh("git", "config", "user.email", "t@t.invalid")
    sh("git", "config", "user.name", "t")
    sh("git", "config", "commit.gpgsign", "false")
    open(f"{repo}/README.md", "w").write("readme\n")
    open(f"{repo}/package.json", "w").write('{"name":"x"}\n')
    open(f"{repo}/.readmedaddy.json", "w").write('{"guard":{"pr":"fail"}}\n')
    sh("git", "add", "-A")
    sh("git", "commit", "-qm", "init")
    sh("git", "update-ref", "refs/remotes/origin/main", "HEAD")
    sh("git", "checkout", "-qb", "pr")
    open(f"{repo}/.readmedaddy.json", "w").write('{"hook":{"enabled":false}}\n')
    open(f"{repo}/package.json", "w").write('{"name":"x","v":2}\n')
    sh("git", "commit", "-qam", "waive attempt + drift")

    # (1) PR: base config wins, waive attempt fails, drift reported.
    r, out = run_check({"EVENT": "pull_request", "BASE_REF": "main"})
    check(r.returncode == 0 and "drift=true" in out and "respond=fail" in out
          and "package.json" in out,
          "PR: base guard.pr wins; head cannot waive its own gate",
          f"(rc={r.returncode} out={out!r} err={r.stderr!r})")

    # (2) merge_group: payload SHAs drive the range; base config applies.
    base_sha = sh("git", "rev-parse", "refs/remotes/origin/main")
    head_sha = sh("git", "rev-parse", "HEAD")
    r, out = run_check({"EVENT": "merge_group", "MG_BASE_SHA": base_sha,
                        "MG_HEAD_SHA": head_sha})
    check(r.returncode == 0 and "drift=true" in out and "respond=fail" in out,
          "merge_group: payload range + base config",
          f"(rc={r.returncode} out={out!r} err={r.stderr!r})")

    # (3) push: working-tree config applies (enabled:false on branch = fresh).
    before = head_sha
    open(f"{repo}/package.json", "w").write('{"name":"x","v":3}\n')
    sh("git", "commit", "-qam", "bump")
    after = sh("git", "rev-parse", "HEAD")
    r, out = run_check({"EVENT": "push", "PUSH_BEFORE": before,
                        "PUSH_SHA": after})
    check(r.returncode == 0 and "drift=false" in out,
          "push: working-tree config honored (enabled:false -> fresh)",
          f"(rc={r.returncode} out={out!r} err={r.stderr!r})")

    # (4) push with all-zeros before-SHA: rangeless fallback, no crash.
    r, out = run_check({"EVENT": "push", "PUSH_BEFORE": "0" * 40,
                        "PUSH_SHA": after})
    check(r.returncode == 0 and "drift=" in out,
          "push: all-zeros before-SHA falls back to rangeless check",
          f"(rc={r.returncode} err={r.stderr!r})")

    # (5) unknown event: clean no-op.
    r, out = run_check({"EVENT": "release"})
    check(r.returncode == 0 and "drift=false" in out,
          "unknown event no-ops cleanly",
          f"(rc={r.returncode})")

    # (6) schedule with guard.sweep weekly on the working tree -> respond=issue.
    open(f"{repo}/.readmedaddy.json", "w").write(
        '{"guard":{"pr":"comment","sweep":"weekly"}}\n')
    sh("git", "commit", "-qam", "sweep on")
    r, out = run_check({"EVENT": "schedule"})
    check(r.returncode == 0 and "respond=issue" in out,
          "schedule: guard.sweep=weekly routes to the dashboard issue",
          f"(rc={r.returncode} out={out!r} err={r.stderr!r})")

    print(f"\n--- summary: {6 - len(FAILURES)} passed, {len(FAILURES)} failed ---")
    sys.exit(1 if FAILURES else 0)


if __name__ == "__main__":
    main()
