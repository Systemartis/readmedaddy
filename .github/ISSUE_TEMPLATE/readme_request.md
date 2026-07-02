---
name: README quality report
about: readmedaddy produced a weak or wrong README for your project type — tell us the archetype, what was off, and what good looks like
title: "[readme] weak output for <archetype> — <one-line symptom>"
labels: ["readme-quality"]
assignees: []
---

A quality report is the raw material for an eval fixture. readmedaddy's whole bet is
that ranking the right candidate through **archetype-weighted gates** beats a generic
template. When it picks a weak winner — or weights the wrong gate for your project
type — this is how we catch it and turn it into a regression fixture.

Fill in what you can. The before/after READMEs matter most. One weak output per issue.

## Archetype

What kind of project was this? Pick the closest — if readmedaddy detected a *different*
archetype than the right one, say both.

- [ ] CLI tool
- [ ] Library
- [ ] Framework
- [ ] App / SaaS
- [ ] Infra / devops
- [ ] Data / ML
- [ ] Agent skill / plugin
- [ ] Research
- [ ] Monorepo
- [ ] Internal tool
- [ ] Detected wrong — readmedaddy thought it was `<X>`, it's actually `<Y>`

## The repo

One or two sentences on what the project is, plus a link if it's public. Enough for us
to judge what the README *should* lead with.

>

## Which gate(s) failed

readmedaddy scores ten gates and weights them by archetype. Which ones came out weak?

- [ ] G1 Hook — first screen doesn't convey what it is / why you'd care
- [ ] G2 Identity / trust — name, one-liner, badges, social proof
- [ ] G3 Visual — missing/inapt ASCII, diagram, screenshot, or demo
- [ ] G4 Quickstart — install + smallest real usage not copy-pasteable / wrong
- [ ] G5 Scannability — heading hierarchy, tables, TOC
- [ ] G6 Completeness — usage/config/examples/links missing, or padded
- [ ] G7 Credibility — no real examples, tests/CI signals, honest limits
- [ ] G8 Contextual fit — ignored the conventions of this archetype
- [ ] G9 Community / maint — contributing, code of conduct, changelog, roadmap
- [ ] G10 Voice — AI-slop, overclaiming, padding
- [ ] Wrong weighting — it optimized for the wrong gate for this archetype

## What was wrong

Describe the actual weakness. If a factual claim was *false* (not just weak), file a
**Bug report** instead — that's a verification failure, not a quality miss.

>

## The README it produced

Paste the weak output, or the load-bearing part of it.

```markdown
<paste here>
```

## What good looks like

What should the winning README have led with / included / cut? Link an exemplar in this
archetype if you have one (e.g. a README readmedaddy should have matched).

>

## Anything else

Repo/branch, how the skill is installed, whether tournament mode was on, or anything
that helps reproduce it. Strip anything private — paths, names, secrets, client details.
