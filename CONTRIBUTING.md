# Contributing to readmedaddy

readmedaddy's value is a ranking system that earns its scores instead of
asserting them. Two rules protect it: every change to skill behavior is earned
by an eval fixture that failed first, and every factual claim a generated README
makes is grounded in the repo it describes. This file is how to keep both true.

## How the skill is structured

The shipped skill lives under `skills/readmedaddy/`. Dev tooling and the eval
harness live at the repo root.

```text
skills/readmedaddy/
  SKILL.md                       # lean: the five-step method, archetype routing, pointers
  references/
    multi-gate-rubric.md         # the ten gates, scoring, and contextual weighting
    archetypes.md                # detection signals + must-have sections + exemplars per archetype
    famous-readme-patterns.md    # the README canon and per-archetype exemplars
    generation-and-ranking.md    # candidate generation, ranking, tournament mode, fact-check
  assets/
    ascii-banner.txt             # the ASCII wordmark
    badges.md                    # reusable badge snippets
    auto-update-hook.md          # the readme-drift hook: modes, config, --check
  hooks/
    readme-drift.sh              # drift detector: Stop hook + standalone --check
  eval/                          # fixtures + RED→GREEN harness + hook tests + results
scripts/
  validate-skill.py              # structure + clean-for-publish + no-network validator (CI)
  install-hook.py                # idempotent Stop-hook installer (atomic settings writes)
action.yml                       # composite GitHub Action: PR drift gate
.github/workflows/ci.yml         # validate + shell + python + markdownlint + drift (PRs)
CHANGELOG.md  README.md  LICENSE  CONTRIBUTING.md  SECURITY.md  CODE_OF_CONDUCT.md
install.sh  .markdownlint-cli2.jsonc
```

SKILL.md is the only always-resident file. Everything under `references/` is
pull-on-demand. Keep SKILL.md lean: the method, archetype routing, and pointers.
Depth — the full gate definitions, the archetype catalog, the exemplars — belongs
in the reference files.

## The Iron Law

**No change to skill behavior ships without an eval fixture that fails first.
RED before GREEN.**

readmedaddy tells its users to ground every claim and to let the rubric decide
quality, so it holds itself to the same standard. "This wording would obviously
produce a better README" is not admissible — over-prescription and unearned
quality claims are the exact failures this skill exists to prevent. A behavioral
PR must show:

1. **RED** — a new or existing fixture under `skills/readmedaddy/eval/` that the
   current skill fails: it misdetects an archetype, applies the wrong gate
   weighting, scores a candidate wrongly, drops a must-have section for the
   archetype, or emits a claim the fixture repo does not support.
2. **The minimal fix** — the smallest change that addresses it, in one home.
   Grep first: a gate is defined once in `references/multi-gate-rubric.md`, an
   archetype once in `references/archetypes.md`. Move a rule or point to it,
   never restate it.
3. **GREEN** — harness output showing the fix passes the new fixture and the
   existing fixtures still pass.

Welcome without a RED fixture: harness, runner, and validator engineering; new
fixtures for already-covered archetypes; docs; the famous-README canon refresh;
and rewordings that lower token count at equal behavior (show eval parity).

## Adding an archetype

An archetype is not "done" until it can be detected, scored, and proven. Add all
four pieces in the same PR:

1. **Detection signals** in `references/archetypes.md` — the manifests, file
   tells, and entrypoints that resolve a repo to this archetype, and how to
   break ties against neighboring archetypes.
2. **The pattern set** in the same file — must-have sections, the right visual
   (ASCII, diagram, screenshot, or none), and the gate weighting for this
   archetype (which of the ten gates carry the most weight).
3. **Exemplars** in `references/famous-readme-patterns.md` — two or three real,
   well-known READMEs of this archetype to imitate (adapt, never copy verbatim).
4. **A fixture** under `skills/readmedaddy/eval/` — a minimal sample repo of the
   archetype plus its expected detection result and gate outcomes, wired into
   the harness so CI proves the detection and weighting.

A new archetype changes how repos are routed and scored, so it is a behavioral
change and gets the full Iron Law treatment.

## Local checks

CI runs these on every PR. Run them before pushing.

```bash
# 1. structure, frontmatter, link integrity, version match, clean-for-publish
python3 scripts/validate-skill.py

# 2. installer: shellcheck + POSIX syntax
shellcheck install.sh
sh -n install.sh

# 3. markdown lint (uses .markdownlint-cli2.jsonc)
npx --yes markdownlint-cli2 "**/*.md" "#node_modules"

# 4. scorer self-test (weights must match the rubric)
python3 skills/readmedaddy/eval/score.py --selftest
```

The eval itself (detection + blind-judged lift on the four fixtures) is
model-driven, not a shell script — the step-by-step procedure is in
[`skills/readmedaddy/eval/README.md`](skills/readmedaddy/eval/README.md).

The validator enforces the contract CI relies on: SKILL.md frontmatter and
budgets, every relative link resolving on disk, the version in SKILL.md
`metadata.version` matching the top `CHANGELOG.md` entry, and the
clean-for-publish guard (see below). When you bump behavior, bump the version in
both SKILL.md and the CHANGELOG in the same commit, or the validator fails.

## Clean-for-publish

This repo is built to be open-sourced, and CI enforces it. No shipped file may
contain a personal name, a private filesystem path, or a company-internal
project codename. `Systemartis` is allowed only in the LICENSE and copyright
lines. Reference other skills generically (for example, "an engineering-discipline
skill" or "a project-finalization skill"), never by a private sibling repo name.
`scripts/validate-skill.py` greps for forbidden references and fails the build,
so run it locally before pushing.

## Code and prose style

Write the way the best READMEs read — the skill is judged by the same rubric it
applies.

- Lead with the outcome. Plain, complete, confident sentences.
- No AI-slop: no "in today's fast-paced world", no negative-parallelism stacking
  ("it's not X, it's Y"), no rule-of-three padding, em-dashes used sparingly.
- Honest framing only. Any quality claim about a generated README must be backed
  by a rubric score, not asserted. No invented benchmarks, no fake stars or
  download counts, no badges for things that do not exist.
- One home per rule. Grep before adding a sentence: move it or point to it,
  never restate across files.
- Shell is POSIX `sh` and passes shellcheck. Python is standard-library only.
  Markdown passes markdownlint.

## PR checklist

- [ ] Behavioral change has a RED fixture that failed first, with GREEN output (Iron Law).
- [ ] A new archetype adds detection signals, pattern set, exemplars, and a fixture.
- [ ] `python3 scripts/validate-skill.py` passes.
- [ ] `shellcheck install.sh` and `sh -n install.sh` pass.
- [ ] `markdownlint-cli2` passes.
- [ ] The eval harness passes (existing fixtures green, new fixture green).
- [ ] Each rule has one home; no restatement across files (grep-checked).
- [ ] Prose follows the style rules; no AI-slop, no unbacked quality claims.
- [ ] `CHANGELOG.md` updated; version bumped in SKILL.md and CHANGELOG together when behavior changes.
- [ ] No personal names, company-internal project names, or private paths.

## Licensing

Contributions are MIT, attributed to Systemartis. Do not submit text copied from
non-MIT sources.
