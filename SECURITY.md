# Security

readmedaddy is an Agent Skill: Markdown instructions plus reference files, a
structural validator, and a one-shot installer. It changes what a model *writes*
(a README), not what the host is *allowed to do*. That makes its security posture
small and easy to state — the skill's runtime behavior, the threat surface of the
two scripts it ships, a supply-chain note for the installer, how to report a
vulnerability, and which versions get fixes.

## What the skill does at runtime

When invoked, readmedaddy **reads files in the target repository** (languages,
manifests, entrypoints, existing docs) to detect the archetype and verify claims,
and it **writes a single Markdown file** (the README) or proposes its content.
That is the whole footprint.

What the skill does **not** do:

- no network calls — it does not fetch from the internet, phone home, or pull
  remote templates; the famous-README patterns it draws on are baked into the
  reference files. This is **enforced, not just stated**: a no-network guard in
  `scripts/validate-skill.py` fails CI if a network primitive (`curl`, `wget`,
  `urllib`, `socket`, `requests.`, `/dev/tcp`, …) appears in any shipped `.sh`
  or `.py` file, and SKILL.md explicitly instructs the model to operate offline
  — an instruction that travels with the skill into every agent that loads it
  (Claude Code, opencode, Copilot, or anything reading `AGENTS.md`)
- no execution of repository code, build steps, install steps, or test suites
- no writes outside the README it is asked to produce (it does not modify source,
  delete files, or rewrite history)
- no new tool, filesystem, or permission grants — it composes with the host
  harness and yields to it

One boundary readmedaddy cannot police: the host agent's own model traffic.
Repo context goes wherever your agent sends it, for readmedaddy exactly as for
any other task in that agent. With a locally-hosted model the entire loop stays
on-device.

If a future change would have the skill fetch over the network, execute repo
code, or write anywhere other than the README, that is a security-relevant change
and must be called out in review.

## Script threat surface

The executables that ship with the repo, ordered by how much trust they run with:

- **`skills/readmedaddy/hooks/readme-drift.sh`** is the highest-value surface:
  once registered it runs automatically on every Claude Code Stop, in whatever
  repo you are working in, parsing repo-controlled input (`.readmedaddy.json`,
  git filenames). It is POSIX shell over local git only, passes pathspecs after
  `--`, exits 0 on every hook-mode error path, and writes exactly one file —
  its cooldown state inside `.git/`. Its behavior (drift, modes, `--check`,
  loop guards, malformed config) is covered by an executable test suite that
  runs in CI.
- **`scripts/install-hook.py`** rewrites your user-global (or project)
  `settings.json` to register the Stop hook. It writes atomically (temp file +
  rename), merges without touching unrelated keys or hooks, and ships a
  self-test that CI runs.
- **`install.sh`** copies the skill into the agents' skills directories. Plain
  POSIX shell with no remote fetch step, shellcheck-clean and syntax-checked in
  CI.
- **`scripts/validate-skill.py`** is a developer and CI tool: reads, validates,
  prints. Standard library only; writes nothing.
- **`skills/readmedaddy/eval/score.py`** and the eval's test scripts run only
  in CI or when you run the eval by hand; stdlib only, no writes outside their
  own output.

Neither script is part of the README-generation path; the skill body that
produces READMEs is Markdown instructions interpreted by the model.

The optional CI action (`action.yml`) runs in your own GitHub Actions: it
diffs your branch locally, fetches only your own base ref, and — in `comment`
mode — posts one comment on your own pull request with your `GITHUB_TOKEN`.
In `fail` mode it makes no API calls. No third-party endpoint is contacted.

## Supply-chain note: review install.sh before running

`install.sh` is local file copying with no download step, but the standard
precaution applies: **read it before you run it**, and prefer cloning the repo
and inspecting the script over piping it from a URL into a shell. Pin to a tagged
release or a known-good commit rather than tracking a moving branch, and verify
you are on the official repository (`github.com/Systemartis/readmedaddy`) before
installing. There are no runtime dependencies, no build step, and no postinstall
hooks.

## Reporting a vulnerability

Please report privately and give us time to fix before public disclosure.

Open a private advisory via GitHub — *Security → Report a vulnerability* on
`github.com/Systemartis/readmedaddy`. This is the reporting channel; it reaches
the maintainers privately and keeps the report out of public issues.

In scope and treated as security issues: any way to make the skill perform a
network call, execute repository code, or write outside the README it was asked
to produce; shell injection or out-of-bounds write through
`hooks/readme-drift.sh` driven by hostile repo content (a crafted
`.readmedaddy.json`, filenames, or git state); corruption of `settings.json`
through `scripts/install-hook.py`; and shell injection or arbitrary file write
through `install.sh`, `action.yml`, or `scripts/validate-skill.py`. Out of
scope: the model producing a low-quality or factually wrong README (that is a
content/calibration bug — open a normal issue), and the behavior of the
underlying model or host harness, which readmedaddy does not control.

When you report, include the input or repo shape that triggers it and the
observed effect. For a boundary-crossing claim (network, code execution, or an
out-of-bounds write), show the specific action that occurred.

## Supported versions

This is pre-1.0 software. Only the latest released minor receives security fixes.

| Version | Supported |
|---------|-----------|
| 0.2.x   | Yes       |
| 0.1.x   | No — upgrade to the latest 0.2.x |

Security fixes ship in a new patch release of the supported minor. If you are
pinned to an older commit, upgrade to the latest tag before reporting, in case
the issue is already fixed.
