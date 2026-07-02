# Generation and ranking — the generate-then-rank workflow

How readmedaddy turns a repo into a README: analyze, generate competing
candidates, score them against the gates, assemble the winner. There are two
paths.

- **Standard generate→rank** (default) — draft a few variants of each key
  section, rank the variants through the gates, keep the per-section winner,
  graft the best of the losers. Handles almost every request.
- **High-stakes tournament** — draft several *whole* READMEs in distinct
  styles, run a three-judge panel, graft a winner. Reserved for front pages
  that materially affect adoption.

Both converge on the same verification pass: every factual claim checked
against the repo before output.

Gate IDs (`G1`–`G10`), the 0–5 anchors, the per-archetype weights, and the
merge procedure all live in
[`./multi-gate-rubric.md`](./multi-gate-rubric.md). Archetype detection
signals, must-have sections, and the right visual per type live in
[`./archetypes.md`](./archetypes.md). Structural moves to borrow from live in
[`./famous-readme-patterns.md`](./famous-readme-patterns.md).

## Shared setup (both paths)

Do this once, before generating anything.

1. **Analyze the repo.** Read the manifest (`package.json`, `pyproject.toml`,
   `Cargo.toml`, `go.mod`, `SKILL.md`, …), the entry points, existing docs,
   tests/CI, and the license. Write down the *verifiable facts*: name, version,
   license, the real install command, the smallest command that proves it
   works, real example output. These are what you score claims against later.
2. **Detect the archetype.** Match the repo to exactly one of the ten
   archetypes via `archetypes.md`. The archetype sets the gate weights and the
   visual the README should lead with. When the signals are genuinely
   ambiguous, ask one pointed question or state the assumption and proceed.
3. **Pull the pattern set.** Load that archetype's must-have sections, right
   visual, and exemplars from `archetypes.md` and `famous-readme-patterns.md`.
   These are moves to adapt, never to copy verbatim.

## Standard generate→rank workflow

Use this unless the work is high-stakes (see the escalation rule). It is fast
and produces a strong README without the tournament's cost.

### Step 1 — Generate N variants per key section

For each key section, draft **2–3 genuinely different candidates**, not one
draft reworded. Variants differ by *angle*, so the ranking has something to
separate. Each section maps to the gate it primarily governs (per the rubric's
surface table), and that gate is what you score the variants on.

| Section | Governs | Draft 2–3 variants across these angles |
|---|---|---|
| Hook (first line) | `G1` | what-it-does one-liner · problem→outcome · who-it's-for + benefit |
| Identity / badges | `G2` | minimal name+tagline · tagline + real badge row · badges + one honest proof line |
| Visual | `G3` | ASCII wordmark · apt diagram (pipeline/dial/arch) · screenshot or demo gif · deliberately none |
| Quickstart | `G4` | one copy-paste install+run block · smallest-real-usage block · per-method (only if methods truly differ) |
| Usage / examples | `G6` `G7` | before/after · progressive examples · common-task recipes |
| Closing (contributing, changelog, license) | `G9` | links-only · short prose + links |

Draft variants as real, shippable content — a vague quickstart cannot be
scored. Skip a section's variants only when the archetype does not need it (a
library is not docked for omitting a screenshot; `archetypes.md` says which
sections are required).

### Step 2 — Rank the variants and pick per-section winners

Score each variant on the gate(s) its section governs, plus `G10` voice (and
`G5` scannability for the visual and usage sections), using the 0–5 anchors in
`multi-gate-rubric.md`. Keep the highest-scoring variant for each section. Note
one keepable idea from each losing variant — a sharper verb in a hook, a
cleaner command order in a quickstart — to graft in Step 4.

### Step 3 — Assemble and self-rank the whole README

Stitch the winning sections in the archetype's canonical order, then score the
*assembled* README on all ten gates at the archetype's weights, normalized to
`/100` (weights sum to 29; max weighted score 145; `total = Σ(wᵢ·sᵢ) / 145 ×
100`). Compute each gate's deficit (`wᵢ·(5−sᵢ)`) and rank the fix list by
deficit, highest first — the rubric surfaces the highest-leverage fixes for you.

### Step 4 — Revise weak gates and graft, in one loop

- Rewrite any section scoring below `4` on a **high-weight** gate. The deficit
  ranking tells you which to touch first.
- Graft the keepable ideas noted in Step 2 — the idea and structure, not the
  raw sentences; rewrite in the README's own voice.
- Re-score. One tight loop, not endless polishing. Stop when no high-weight
  gate sits below `4`.

### Step 5 — Verify and output

Run the verification pass below, then output the README and offer the strong
runner-up section variants as labelled alternatives.

### Standard-path checklist

- [ ] Archetype chosen and named; its gate weights loaded.
- [ ] 2–3 real variants drafted for each key section the archetype needs.
- [ ] Each section's winner picked by its governing gate's score.
- [ ] Hook (`G1`) is one concrete sentence a reader remembers, not history.
- [ ] Quickstart (`G4`) is a single copy-paste block that actually runs.
- [ ] Visual (`G3`) is apt for the archetype, or deliberately omitted.
- [ ] Whole README scored once; no high-weight gate left below `4`.
- [ ] Every factual claim checked against the repo.

## When to escalate to the tournament

Run the tournament only when the front page is high-stakes: a repo about to be
open-sourced, a flagship or marquee project, a README whose quality measurably
affects adoption, or an explicit request for "the best possible README". For
everything else the standard path wins on speed without losing much quality.
Escalating by default is the same over-engineering that the rubric's `G10`
penalizes in prose.

## High-stakes tournament workflow

The tournament trades compute for quality by refusing to commit to one shape
too early. Instead of varying one section at a time, it produces several
complete READMEs in deliberately different styles, judges them, and assembles a
winner that grafts the best of the rest.

### Step 1 — Generate N draft READMEs in distinct styles

Produce **5–6 whole-README drafts**, each a complete front page in a different
idiom. The styles must be genuinely distinct, not the same draft with the
banner moved. Use this named set:

| Style | What it leads with | Best when |
|---|---|---|
| **banner/CLI** | ASCII wordmark up top, demo block right under it, terse copy | CLI and dev tools where the brand and the demo sell it |
| **diagram-led** | a small apt diagram (pipeline, dial, architecture) before prose | systems whose value is the shape of the flow |
| **story-hook** | a one-paragraph problem→outcome hook that earns the install | tools whose value needs one sentence of context to land |
| **reference-grade** | tight identity block, badges, TOC, dense and complete | libraries and frameworks judged on API completeness |
| **show-don't-tell** | a real before/after or input/output example as the first content | anything whose output beats its description |
| **minimal-elegant** | one hook line, one quickstart, ruthless whitespace, nothing else | mature tools confident enough to say little |

Each draft is real and shippable — same repo facts, different emphasis and
order. Drafting in distinct voices is what gives the judges something to
separate; near-duplicates waste the whole tournament.

### Step 2 — Run the three-judge panel

Three judges score **every draft** through the contextual rubric (all of
`G1`–`G10`, archetype-weighted). Each judge has a specialty that decides whose
verdict is authoritative on which gates during synthesis, but every judge still
returns a full numeric score for every draft, a ranking, and per-gate notes.

| Judge | Role | Weights heaviest | Authoritative on |
|---|---|---|---|
| **Craft judge** | the editor/engineer | `G4` quickstart correctness, `G6` completeness, `G7` credibility, `G8` fit, `G9` community, `G10` voice | substance: does it run, is it complete, is it honest, does it read clean |
| **First-impression judge** | the cold visitor, reading only the first screen for five seconds | `G1` hook, `G2` identity/trust | would a stranger keep reading, trust it, and try it |
| **ASCII/design judge** | the visual critic | `G3` visual, with `G5` scannability in support | does the banner/diagram/screenshot earn its space, render at width, fit the brand |

Each judge returns, per draft: a score for every gate, the weighted total, a
rank, and one line of per-gate notes naming what to keep and what to cut. A
judge scores all ten gates, but their signal is trusted only for the gates
they own. Keep the three score sheets separate — synthesis needs them
disaggregated.

### Step 3 — Synthesize: pick a winner, graft the rest

1. **Pick the base.** Average (or median) the three judges' weighted totals per
   draft for the overall ranking. The top draft is the **skeleton** — its
   order, voice, and shape become the spine of the final README.
2. **Find the per-gate winners.** For each gate, identify the draft that scored
   highest, trusting the specialist judge for their gates (design judge decides
   `G3`, first-impression judge decides `G1`/`G2`, craft judge decides
   `G4`/`G6`/`G7`). These are the graft candidates: the single best hook, the
   single best quickstart, the single best banner across all drafts.
3. **Graft selectively.** Where a non-base draft beats the skeleton on a gate by
   **≥ 2 points** (the rubric's graft threshold), lift that gate's surface into
   the skeleton. If the skeleton already owns a gate, leave it. Do not graft for
   the sake of touching every gate.

## Grafting without Frankensteining the voice

A README assembled from six voices reads like six people arguing. To avoid it:

- **Graft the idea and the structure, not the raw sentences.** Take the winning
  quickstart's command sequence, the winning diagram, the winning table layout —
  then rewrite the prose in the skeleton's voice. The grafted element keeps its
  shape; the words become native.
- **One voice owns the final pass.** After all grafts are in, read the whole
  README once as the winning draft's author and rewrite every seam so tense,
  person, rhythm, and vocabulary match. The reader must not be able to tell
  which section came from which draft.
- **Unify the visuals.** A grafted banner and a native diagram must share the
  same wordmark, the same width (≤ ~72 cols), and the same tone. Two ASCII
  styles in one README is worse than one.
- **Watch the seams.** The risk is at the joins between a native section and a
  grafted one; check every transition still flows.
- **Re-score the assembled README.** Run it back through the rubric. The
  assembly must beat every individual draft on the weighted total. If it does
  not, a graft hurt the voice more than it helped a gate — revert that one
  graft and keep the rest.

## Assembly and verification (both paths)

A README is only as good as its claims are true.

1. **Verify every factual claim against the repo.** For each claim, point to
   repo evidence: the install command runs, every file path exists, the version
   matches the manifest, the license matches `LICENSE`, badges point to things
   that will exist once pushed, and every code block copy-pastes and works.
   Strike or fix anything you cannot verify. A quickstart grafted from another
   draft may reference a command or flag the skeleton never introduced — catch
   it here.
2. **Invent nothing.** No fabricated benchmarks, star counts, download numbers,
   or testimonials. No badge for a thing that does not exist. CI, license,
   version, and "Agent Skill" badges are fine because they become valid on push.
   Any quality claim about the README itself must trace to a rubric score, never
   an assertion.
3. **Output the README**, then offer the strong runner-up elements as named
   alternatives — "alternate banner from the diagram-led draft", "shorter hook
   from minimal-elegant", "the per-method install variant" — so the user can
   swap a section without re-running anything.

This pass composes with engineering-discipline and project-finalization skills
rather than replacing them, and it yields to an existing project style guide
where one exists.

## readmedaddy dogfoods this

readmedaddy's own README was produced by exactly this tournament: six styled
drafts, the three-judge panel, a grafted winner. It tops readmedaddy's own
contextual rubric — stated here only because it is true for this repo, which is
the standard every claim in a generated README is held to.
