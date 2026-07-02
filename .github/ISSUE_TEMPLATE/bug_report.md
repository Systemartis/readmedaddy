---
name: Bug report
about: readmedaddy crashed, didn't trigger, made a false factual claim, or the tooling (install.sh / validator / CI) misfired
title: "[bug] "
labels: ["bug"]
---

Thanks for reporting. If the problem is "the README it produced was weak / wrong for my project type", file a **README quality report** instead — that template captures archetype, gates, and the expected output. Use this one for crashes, non-triggering, hallucinated facts, or broken tooling.

> Producing a README that's merely *thin* or *off-archetype* is a quality issue, not a bug. A **false claim about the repo** (an install command that doesn't exist, a wrong license, an invented benchmark) is a bug — report it here.

## What went wrong

One sentence on the failure.

>

## Which surface

- [ ] The skill didn't trigger when it should have (or triggered when it shouldn't)
- [ ] The skill ran but errored / got stuck mid-generation
- [ ] The output asserted something **false about the repo** (claim that fails verification)
- [ ] `install.sh` failed or didn't land the skill
- [ ] `scripts/validate-skill.py` reported a wrong result
- [ ] CI (`.github/workflows/ci.yml`) — markdownlint / shellcheck / validate
- [ ] Other:

## False claim (if applicable)

If the output stated something untrue about the repo, paste the claim and the repo fact that contradicts it:

- Claim readmedaddy made:
- Actual repo fact:

## Reproduction

1.
2.
3.

## Expected

What should have happened instead.

>

## Environment

- readmedaddy version (see `CHANGELOG.md` / git tag):
- Host (Claude Code, other harness, version):
- Install method (`install.sh`, manual copy, custom `DEST`):
- OS:

## Tooling output

If a script or CI step failed, paste the command and its output:

```
<paste here>
```

## Anything else

Relevant project `CLAUDE.md` / `AGENTS.md` rules, other active skills, or context that shaped the run. Strip anything private before pasting.
