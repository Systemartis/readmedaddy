<!-- Keep this short. Lead with the outcome. Delete sections that don't apply. -->

## Summary

<!-- One or two sentences: what this PR changes and why. -->

## Addresses

<!-- Link the issue(s) or describe the finding this fixes, e.g. "Closes #12" or "Fixes weak quickstart ranking on CLI archetype". -->

## Iron Law

Any change to ranking behavior (gates, archetype weights, detection signals, generation/assembly) ships with a matching eval fixture in the same PR. No behavior change without a check that pins it.

- [ ] This change touches ranking, archetype detection, or generation, and I added/updated an `eval/` fixture that covers it.
- [ ] OR: this change touches none of those (docs, tooling, CI), so no fixture is needed.

## Local checks

Paste the relevant output or confirm each ran clean:

- [ ] `python3 scripts/validate-skill.py` (Agent Skills spec + internal links + clean-for-publish)
- [ ] `shellcheck install.sh` and `sh -n install.sh`
- [ ] `npx markdownlint-cli2 "**/*.md" "#node_modules"` on changed `*.md`

## Rubric check

readmedaddy's quality claims have to be backed by a gate score, not asserted — and changes to one archetype mustn't quietly degrade another.

- [ ] No new quality claim is asserted in prose without a rubric score behind it (no "best", "production-ready", invented benchmarks).
- [ ] Archetype weighting changes were checked against the other archetypes — a heavier gate for one didn't flip a winner it shouldn't have for another.
- [ ] Clean-for-publish holds: no absolute home-directory paths, personal names, or private project codenames in shipped file content.
