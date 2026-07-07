# The readme-drift auto-update hook

Your README goes stale the moment the code moves and nobody notices. This hook
notices. It is a Claude Code **Stop hook** that watches the signal files a README
is built from — manifests, entrypoints, CI, install scripts — and, when they
change while the README does not, prompts you to refresh the README **through the
readmedaddy skill, in the same session**. It re-detects the archetype and re-ranks
the front page; it does not patch a line and call it done.

It is deliberately quiet. No git repo, no README, or a config that turns it off,
and it does nothing. It never rewrites files on its own and it can never break a
session — every path exits clean.

The Stop hook is the Claude Code face of the detector; the **same script runs
standalone** with `--check` for CI, git hooks, and every other agent — one
drift logic, one config, every surface. See
[Standalone `--check` mode](#standalone---check-mode-any-agent-ci-git-hooks).
Everything in this file is local git + POSIX sh: no network, no telemetry.

- Hook script: [`../hooks/readme-drift.sh`](../hooks/readme-drift.sh)
- Installer: `scripts/install-hook.py` in the
  [readmedaddy repo](https://github.com/Systemartis/readmedaddy) (not shipped
  inside the skill; `install.sh` runs it for you)
- Config example: [`../.readmedaddy.json.example`](../.readmedaddy.json.example)
- The skill it hands off to: [`../SKILL.md`](../SKILL.md)

## What it does, in order

1. Reads the JSON Claude Code passes on stdin when a turn stops.
2. If it is a hook-triggered continuation (`stop_hook_active: true`), exits — this
   is the loop guard.
3. If `README_DADDY_HOOK=off`, exits.
4. Resolves the repo root with `git rev-parse --show-toplevel`. Not a git repo,
   exits.
5. Loads optional [`.readmedaddy.json`](#config-readmedaddyjson). Disabled there,
   exits.
6. If the README does not exist, exits — it never nags a repo that has no README.
7. Computes **drift** (below). No drift, exits silently.
8. Checks the cooldown state. Same drift as last time, exits.
9. Otherwise **emits** according to the mode and records state.

Every branch exits `0`. The hook is incapable of failing your session.

## How it decides "drift"

Drift means **the project changed in a README-relevant way while the README did
not.** Concretely:

- **Working-tree drift** (the in-session case): a watched path shows up as
  modified, added, or staged in `git status --porcelain`, and the README path does
  **not**. You edited `package.json` and `src/`, your README still describes the
  old shape — that is drift.
- **Committed drift** (best-effort fallback): if the working tree is clean, it
  compares the most recent commit touching any watched file against the most recent
  commit touching the README. If the code commit is newer, the README has fallen
  behind.

If you touched the README in the same batch of changes, there is no drift — the
hook assumes you already kept it current.

### Watched signal files

These are the files whose changes imply the README's *content* should move. The
baked-in default list:

```text
package.json   pyproject.toml   Cargo.toml   go.mod   go.sum   Gemfile
composer.json  build.gradle     pom.xml
bin/**   src/**   cmd/**   cli/**   .github/workflows/**
install.sh   Makefile   Dockerfile   docker-compose.yml   **/SKILL.md
```

Manifests change your install line and dependencies. Entrypoints change your
quickstart and API surface. CI and install scripts change your badges and setup.
`SKILL.md` changes what an agent skill *does*. Override the list per project in
[`.readmedaddy.json`](#config-readmedaddyjson).

## The three modes

Pick by how insistent you want the nudge to be. `auto` is the default and the right
choice for almost everyone.

| Mode | Channel | Fires | Use it when |
|------|---------|-------|-------------|
| **auto** *(default)* | `decision: block` JSON on stdout | once per distinct drift | You want one clear nudge, then silence until something new drifts. |
| **notify** | human-readable line on stderr | once per distinct drift | You want awareness without the agent being asked to continue — non-blocking, no handoff. |
| **enforce** | `decision: block` JSON on stdout | every Stop until the README changes | The project has a hard "README tracks code" rule and you want to be held to it. |

- **auto** blocks the Stop once and asks the agent to refresh the README, then
  records the drift signature so the identical state does not nag again. This is the
  balanced default: one prompt per real change.
- **notify** prints the same message to stderr and gets out of the way. Nothing is
  blocked, nothing is handed off — you just see that the README drifted. Good for
  people who want the signal but not the interruption.
- **enforce** blocks on **every** Stop and keeps blocking until the README actually
  changes, because it does not mark the drift as handled. Use it where a stale
  README is not acceptable. The same-turn loop is still prevented by the
  `stop_hook_active` guard.

Set the mode in config, or force it for one session with the env var:

```sh
README_DADDY_HOOK=notify   # force notify for this session
README_DADDY_HOOK=enforce  # force enforce for this session
README_DADDY_HOOK=off      # disable entirely for this session
```

The env var wins over config when set to a real mode.

## Config: `.readmedaddy.json`

Drop a `.readmedaddy.json` in your repo root to override defaults. Every field is
optional — omit a key to keep its default. See
[`../.readmedaddy.json.example`](../.readmedaddy.json.example) for a
copy-paste starting point.

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `hook.enabled` | boolean | `true` | `false` turns the hook off for this repo. |
| `hook.mode` | string | `"auto"` | `"auto"`, `"notify"`, or `"enforce"`. |
| `hook.readme` | string | `"README.md"` | Path to the README the hook watches. |
| `hook.watch` | string[] | the default list above | Patterns of files whose changes imply README drift: exact paths, `dir/**` (prefix), `**/name` (suffix), or plain globs like `docs/*.md` (fnmatch semantics — `*` also crosses `/`). |

Example:

```json
{
  "hook": {
    "enabled": true,
    "mode": "auto",
    "readme": "README.md",
    "watch": [
      "package.json",
      "pyproject.toml",
      "src/**",
      "bin/**",
      ".github/workflows/**",
      "install.sh",
      "Makefile"
    ]
  }
}
```

One parsing caveat (deliberately simple, no JSON parser in POSIX sh): the hook
reads the **last** occurrence of each key anywhere in the file — including
inside string values. Keep the real `hook` object *after* any documentation
strings (as the shipped example does), and don't put text like `"enabled":
false` inside a doc string below it.

## Standalone `--check` mode: any agent, CI, git hooks

The same drift logic runs without any agent — pure local git and POSIX sh:

```sh
readme-drift.sh --check                             # working tree (+ last-commit fallback)
readme-drift.sh --check --range origin/main...HEAD  # commit range, for CI
```

| Exit | Meaning |
|------|---------|
| `0` | fresh — or nothing to check (no README, `enabled: false`) |
| `1` | drift — the drifted watched files print to stdout, one per line |
| `2` | usage or git error (bad `--range`, not a git repo, shallow clone in committed-drift mode) — loud on purpose, so a misconfigured CI gate fails visibly |

Semantics that differ from Stop-hook mode, deliberately:

- **Idempotent and stateless.** `--check` reads no stdin and writes no cooldown
  state — run it twice, get the same answer twice.
- **Ignores `README_DADDY_HOOK`.** That env var is a session-scoped switch for
  the Stop hook; an explicit `--check` invocation should always answer.
- **Respects `.readmedaddy.json`.** `enabled: false`, a custom `readme`, and a
  custom `watch` list apply to every surface, so a project configures drift
  once.

**Git pre-commit warning** (universal — no agent, warns without blocking):

```sh
# .git/hooks/pre-commit
~/.claude/skills/readmedaddy/hooks/readme-drift.sh --check || echo "readmedaddy: consider refreshing the README"
```

**Pull-request gate.** The repo ships a composite GitHub Action (`action.yml`
at the repo root) that runs `--check --range` against the PR's base and either
posts one sticky comment (`mode: comment`) or fails the job (`mode: fail`).
Requires `actions/checkout` with `fetch-depth: 0` so the merge-base exists.

## Install

**One step (recommended).** The repo's installer registers both the skill and the
hook, user-global, so your READMEs stay fresh across every project:

```sh
./install.sh
```

The hook's own guards keep it inert wherever there is no git repo, no README, or
it has been disabled — so global registration is safe. Skip the hook with
`./install.sh --no-hook`.

**Hook only, this project.** Register the Stop hook into the project's
`.claude/settings.json` yourself:

```sh
python3 scripts/install-hook.py \
  --command "$HOME/.claude/skills/readmedaddy/hooks/readme-drift.sh" \
  --project
```

The installer is idempotent — running it twice never writes a duplicate, and it
merges into existing settings without clobbering other keys or hooks. Use
`--dry-run` to preview the change.

## Disable

- **This session:** `README_DADDY_HOOK=off`.
- **This repo:** set `"hook": { "enabled": false }` in `.readmedaddy.json`.
- **Quiet on one repo:** delete or rename its `README.md` is not the move — instead
  set `enabled: false`. The hook only nags repos that have a README *and* leave the
  hook enabled.

## Uninstall

Remove the registered Stop hook entry:

```sh
python3 scripts/install-hook.py --uninstall            # user-global scope
python3 scripts/install-hook.py --uninstall --project  # project scope
```

Deleted the cloned repo already? The manual equivalent: open
`~/.claude/settings.json` and remove the `hooks.Stop` entry whose command ends
in `readme-drift.sh`, then delete the installed skill folder(s).

It removes only the matching readme-drift entry and leaves the rest of your
settings untouched.

## Loop safety

A Stop hook that blocks can, naively, prompt the agent to continue, which stops
again, which prompts again. Two guards prevent that:

- **`stop_hook_active`:** when Claude Code re-runs the Stop hook as part of a
  hook-driven continuation, it sets `stop_hook_active: true` on stdin. The hook sees
  that and exits immediately, so it never fires twice within the same turn.
- **Cooldown state:** the hook writes a signature of the drift it just handled —
  the short HEAD sha plus the drift class (working-tree or committed) — to
  `.git/readmedaddy-state`. Dirtying more watched files at the same HEAD is the
  same drift event: one nudge per HEAD, not one per file. A new commit is what
  re-arms it. On the **first** run in a repo where the only drift predates the
  hook (clean tree, stale README from before install), the hook seeds this state
  silently instead of nagging — a fresh install never opens with a complaint
  about history it didn't witness. (`enforce` mode skips both the seeding and
  the recording, so it re-prompts until the README moves.)

The state file lives *inside* `.git/`, so it is per-clone bookkeeping by
construction — it can never appear as an untracked file in your working tree
and never needs a gitignore entry. `--check` mode writes no state at all.

## Honesty note

Known ceiling: paths containing control characters are still compared in git's
quoted form and may be mis-detected. Non-ASCII paths (accents, CJK) are handled
exactly — the detector reads git output with `core.quotePath=false`.

This hook **detects drift and prompts an in-session refresh through the readmedaddy
skill.** That is the whole contract. It does **not** edit your README, does not run
in the background, and does not rewrite anything behind your back. When it fires,
you (or the agent, with your turn) decide what to change — the hook just makes sure
a stale front page does not slip by unnoticed.
