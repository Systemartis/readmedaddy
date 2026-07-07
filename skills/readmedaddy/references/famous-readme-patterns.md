# Famous README patterns

The studied swipe file. Use it in three moves:

1. Read **the canon** for the durable principles every good README obeys.
2. Build the first screen from **the great-first-screen anatomy** and the
   **Standard-Readme section order**.
3. Jump to **the exemplar group for the detected archetype** and steal its
   *first-screen move* — the one thing the best project of that kind does in the
   opening scroll-height to win the reader.

Two rules for using this file:

- **Imitate the move, not the words.** "Lead with a runnable example" transfers;
  the exact six lines FastAPI ships do not. Quoted taglines below are evidence of
  the move, not copy to paste.
- **Never fetch the live README.** This skill operates offline; every pattern
  here is baked in so nothing needs fetching. The `owner/repo` citations are
  provenance, not links to follow. Quoted taglines may have drifted since they
  were recorded — one more reason to imitate the *move*, never paste the words.

The through-line: **a README is a sales page that happens to be Markdown.** The
first screen does the selling. Everything below is for the reader you already
convinced. (Lineage worth knowing: `READ.ME` notes shipped with source since the
1970s DEC/PDP era; Gruber's Markdown (2004) made it formattable; GitHub
rendering `README.md` as the repo home page (2008) turned it into a landing page;
social-preview cards (2018) made the banner a shareable thumbnail. It is now
landing page, social card, and onboarding funnel at once.)

---

## The canon — one principle each

Six reference works define the field. Take exactly one load-bearing idea from
each; the rest is elaboration.

| Source | Where | The one principle to keep |
|--------|-------|---------------------------|
| Art of README | `hackergrrl/art-of-readme` | The README is **the face of your project**, written for a stranger who has never heard of it. Optimize the opening for the reader deciding, in ~10 seconds, "is this for me?" — the **gist test**. State what it is and why it exists *before* how to use it. |
| Standard-Readme | `RichardLitt/standard-readme` | **Predictable, ordered sections** so readers locate content by position, not by reading. Title → short description → (banner/badges) → TOC when long → Install → Usage → API → Contributing → **License last**. Ships a linter + generator; its own README obeys its spec. |
| Make a README | `makeareadme.com` (`dguo/make-a-readme`) | **Right-size to the audience.** The section list is a checklist, not a mandate. Write Installation as if the reader is a novice (exact versions/deps), "use examples liberally, and show the expected output if you can," and minimize contribution friction (exact setup/lint/test commands). |
| Best-README-Template | `othneildrew/Best-README-Template` | **Visual scaffolding pays off out of the box**: centered logo → title → one-liner → action-link row (Docs · Demo · Report Bug · Request Feature) → About screenshot → "Built With" badges → back-to-top anchors → **all links/images defined reference-style at the bottom** so prose stays clean. |
| awesome-readme | `matiassingers/awesome-readme` | **Steal from the best.** Keep a gallery of admired READMEs per archetype and pattern-match new work against them. The fastest route to a great README is copying what already works for your kind of project. |
| README-Driven Development | Tom Preston-Werner (2010 essay) | **Write the README first**, before the code, as the project's external contract. Explaining the tool to a stranger forces clean API decisions and surfaces scope problems while they're cheap. "A beautifully crafted library with no documentation is also damn near worthless." |

---

## The great-first-screen anatomy

The above-the-fold formula nearly every winning README follows. Each line answers
one reader question; ship them top to bottom:

| Slot | Answers | The move |
|------|---------|----------|
| Logo / wordmark | *what brand is this?* | Centered image (~300–400px) via `<p align="center">`. Ship dark/light variants with `<picture>` + `prefers-color-scheme`. For terminal-native tools, an ASCII wordmark instead (see below). |
| Value prop, one line | *what is it / is it for me?* | 6–10 words naming **category + differentiator**. Place it ABOVE badges and install. |
| Badge row, one line | *is it maintained / adopted / safe?* | 4–6 curated badges, one line, one flat style. Credential strip, not trophy wall. |
| Hero visual | *show me, don't tell me* | Screenshot/GIF for visual products; a runnable code block for libraries; a captioned demo for CLIs. Make it a clickable CTA to the live product when one exists. |
| One primary CTA | *what do I do next?* | A single obvious next action (Starship: "Explore the Starship docs ▶"). Defer the full TOC and link wall to below the hero. |

The discipline: **what → proof → see-it → act-on-it**, all before the reader scrolls.

---

## Standard section order (the skeleton)

Verified from `RichardLitt/standard-readme`. Readers find content by position, so
keep the order and match the section titles exactly:

```
Title
  Banner          (optional, right after title, local image only)
  Badges          (optional, newline-delimited, NO heading)
Short Description  (< 120 chars, own line, identical to the npm/PyPI description)
Long Description   (optional)
Table of Contents  (required unless the README is under ~100 lines)
  Security         (optional, surfaced early when relevant)
  Background        (optional)
Install
Usage
  API              (optional)
  Maintainers / Thanks (optional)
Contributing
License            (must be the LAST section)
```

A consistent vertical rhythm makes hundreds of repos individually skimmable:
**branding → one-line value prop → credibility badges → docs routing → features
→ quickstart**. Tailwind's entire README is essentially this skeleton.

---

## Exemplars by archetype — steal the first-screen move

The column that matters is **the move**: what the exemplar puts in the opening
scroll-height, and why it earns its place for that archetype.

### CLI tools — demo-forward, "X but better" pitch

CLI READMEs sell on *speed and feel*. The winning first screen is a demo
(GIF/screenshot) plus a one-line "X but faster/friendlier than Y" pitch.

| Exemplar | Where | The move |
|----------|-------|----------|
| starship | `starship/starship` | Textbook centered hero: logo → 8-word prop ("The minimal, blazing-fast, and infinitely customizable prompt for any shell!") → one badge line → right-aligned animated GIF **captioned with the exact environment** ("with iTerm2 and the Snazzy theme") → one centered "Explore the docs ▶" button. The caption makes the demo reproducible, not aspirational. |
| ripgrep | `BurntSushi/ripgrep` | No logo, no ceremony. One declarative sentence that doubles as a definition, exactly three badges, then a **benchmarks section with a results table and linked, reproducible methodology**. For a tool whose pitch is "fast + correct," numbers beat decoration. |
| bat | `sharkdp/bat` | "A cat(1) clone with syntax highlighting and Git integration," three badges, then immediately a screenshot of bat's **own colorized output**. The product *is* visual output, so the screenshot is the value prop. Anchor to a known tool ("X clone"), lead with the rendered result. |
| fd | `sharkdp/fd` | "X but better" framing vs `find`, a colored-output screenshot up top, and a standout side-by-side **`fd` vs `find` command-equivalence table** — the highest-leverage section a replacement tool can write: it teaches usage and sells the ergonomics in one block. |
| lazygit | `jesseduffield/lazygit` | Centered TUI screenshot (establishes layout) + 6-word tagline ("A simple terminal UI for git commands") + dense health badges + an **action-scoped demo GIF named for the task it shows** (`commit_and_push`). A still proves layout; a short named GIF proves the workflow. |
| fzf | `junegunn/fzf` | Category-defining tagline — "a general-purpose command-line fuzzy finder and an interactive terminal toolkit." "Toolkit" claims the broad territory; the demo narrows it to concrete uses (file select, history, preview) without over-promising in prose. |
| zoxide | `ajeetdsouza/zoxide` | Analogy-anchored: "a smarter cd command, inspired by z and autojump," then the payoff in user terms ("jump … in just a few keystrokes"), then objection removal ("works on all major shells") — all before install steps. |
| gitui | `extrawurst/gitui` | Logo → demo GIF (motion before prose) → comparative tagline ("the comfort of a git GUI but right in your terminal"). Carries an **`unsafe-forbidden` badge** — an audience-targeted signal that says "engineering discipline" to a Rust reader in one icon. |
| neofetch | `dylanaraps/neofetch` | The art IS the product: tagline brags the implementation ("written in bash 3.2+"), then a screenshot of the distro ASCII logo beside the info table — exactly the artifact users want to generate and share. |

### Libraries & frameworks — smallest real usage + trust

Library READMEs sell on *the smallest real usage* and *credibility*. Big
frameworks deliberately keep the README thin and route depth to a docs site.

| Exemplar | Where | The move |
|----------|-------|----------|
| FastAPI | `fastapi/fastapi` | Launchpad, not destination: logo → claim-packed prop ("high performance, easy to learn, fast to code, ready for production") → badge line → labeled **Documentation:** / **Source Code:** links so a reader can leave in 5s. Bold-lead features with quantified ("200–300% faster", "~40% fewer bugs"), a progressive quickstart ("now change it to…"), payoff = a screenshot of the auto-generated Swagger docs. Sells what you get for free. |
| Zod | `colinhacks/zod` | Precise 7-word prop — "TypeScript-first schema validation with static type inference." The 'aha' is tiny: define a schema, then `z.infer<typeof Schema>` derives the static type from runtime code (one source of truth). README **is** the documentation — deep anchored single-page TOC, zero hand-off friction. |
| Tailwind CSS | `tailwindlabs/tailwindcss` | Restraint as a feature: dark/light banner → one sentence ("A utility-first CSS framework for rapidly building custom user interfaces.") where "utility-first" is the whole positioning → four badges → "For full documentation, visit tailwindcss.com." Refuses to duplicate the docs. |
| Drizzle ORM | `drizzle-team/drizzle-orm` | Voice as differentiator in a crowded category. Hard numbers ("~7.4kb minified+gzipped, tree-shakeable, exactly 0 dependencies") and **differentiate-by-negation** ("No bells and whistles, no Rust binaries, no serverless adapters — everything just works"). Positions against competitors with no comparison table. |
| React | `facebook/react` | Authority through brevity. One-line definition, slim badge row, then THREE bold-lead bullets that are the **mental model**, not a feature dump ("Declarative", "Component-Based", "Learn Once, Write Anywhere"). Install is a pointer; teaching lives on react.dev. |
| Vue | `vuejs/core` | One load-bearing adjective carries the strategy: "Vue is a progressive, incrementally adoptable JavaScript framework…" Prominent Sponsors tiers + friendly routing sections (Documentation / Questions / Issues / Contribution / Stay In Touch) turn the lower README into a directory. |
| Poetry | `python-poetry/poetry` | Tagline sells the **outcome**, not the mechanism: "Python packaging and dependency management made easy." Deliberately does NOT inline the install script — points to the canonical installer so the README never goes stale. |
| Vite | `vitejs/vite` | Two-word aspirational tagline ("Next Generation Frontend Tooling"), early bold Documentation link, and a **monorepo packages table** mapping each package to its npm version/changelog so contributors navigate without reading the tree. |

### Apps & SaaS — screenshot, pitch, social proof

App READMEs sell on *what it looks like* and *let me try it now*. The hero image
is the value prop.

| Exemplar | Where | The move |
|----------|-------|----------|
| Supabase | `supabase/supabase` | Positioning-by-analogy ("the open source Firebase alternative" / "the features of Firebase using enterprise-grade open source tools") borrows an incumbent's mental model. Feature checklist with each item deep-linking to docs, a real dashboard screenshot, and a labeled **architecture diagram naming every wrapped OSS component** (Kong, GoTrue, PostgREST…) — "not magic, just good open tools." |
| n8n | `n8n-io/n8n` | Node-canvas screenshot immediately (visual product → screenshot is the prop). Benefit-titled features with embedded proof ("400+ integrations", "900+ templates"), two copy-paste quickstarts (`npx n8n` + a Docker one-liner), and **licensing faced head-on** (fair-code) rather than buried. |
| Excalidraw | `excalidraw/excalidraw` | Tagline does triple duty in one breath — category + license + differentiator ("An open source virtual hand-drawn style whiteboard. Collaborative and end-to-end encrypted."). Hero image is both demo and **clickable CTA to excalidraw.com**; persistent top nav treats the README like a landing page. |

### Infra & runtimes — authoritative definition + one-line install

Infra/runtime READMEs sell on *a precise definition* and *a one-line install*,
often per platform.

| Exemplar | Where | The move |
|----------|-------|----------|
| Bun | `oven-sh/bun` | Consolidation promise ("all-in-one toolkit … you only need bun") plus the adoption killer: "**a drop-in replacement for Node.js**" — collapses switching cost to near zero. One curl install; heavy benchmarks offloaded to bun.sh to keep the README scannable. |
| Deno | `denoland/deno` | One dense definition with the wedge baked in ("secure defaults"), then a **six-row install matrix** (shell, PowerShell, Homebrew, Chocolatey, WinGet, Scoop) so nobody hunts for their channel. First command shows off the security model (`deno run --allow-net …`). |
| Kubernetes | `kubernetes/kubernetes` | Credibility through **provenance** (origin in Google's Borg, CNCF-hosted) — more persuasive to an infra buyer than any badge. Three badges = security/quality/freshness only. Splits "To start **using** Kubernetes" vs "To start **developing** Kubernetes" so users and contributors self-route. |
| Ollama | `ollama/ollama` | Command-forward: tagline → platform install one-liners → one quickstart that delivers the wow (`ollama run <model>`). Signature element: a **copy-paste model table** (Model / Parameters / Size / Command) whose last column is the exact pull command — a reference table that doubles as a launcher. |

### Data, ML & AI — results, citation, instant payoff

Data/ML READMEs sell on *results and credibility*. Pair a `pip install` (or a
tiny snippet returning a real result) with academic-grade trust signals.

| Exemplar | Where | The move |
|----------|-------|----------|
| TensorFlow | `tensorflow/tensorflow` | "an end-to-end open source platform for machine learning," `pip install tensorflow`, a 4-line REPL hello-world, and the signature **per-platform CI build matrix** (8 rows: Linux CPU/GPU/XLA, macOS, Windows, Android, Raspberry Pi × status/artifacts). Transparently showing what's tested green is the strongest trust signal for software people deploy to weird targets. DOI + OpenSSF badges for the research audience. |
| Hugging Face Transformers | `huggingface/transformers` | 3-line `pipeline()` snippet that returns a real result immediately, a **README-translations row in ~16 languages** (living global community), and the rare honesty move: paired "Why should I use Transformers?" **and** "When shouldn't I use Transformers?" — naming real limits makes every positive claim more believable. |

### Dev tooling & agent skills — positioning + the exact command

Tooling READMEs sell on *a sharp positioning line* (what it replaces, how fast)
and *the exact command to run*. Closest neighbor to an agent-skill README.

| Exemplar | Where | The move |
|----------|-------|----------|
| shadcn/ui | `shadcn-ui/ui` | The **"NOT an X, it's a Y" reframe** installs the right mental model before install: "This is NOT a component library. It is a collection of re-usable components that you can copy and paste into your apps." `npx shadcn@latest add button` drops source INTO your repo — it sells an ownership model, not a dependency. |
| Biome | `biomejs/biome` | Six-word identity ("Toolchain of the web"), one badge line, and quantified trust ("97% Prettier compatibility", "500+ lint rules"). A **command ladder adoptable in 30s**: install → `format --write` → `lint --write` → `check --write` → `ci`, escalating from simplest verb to CI form. |

---

## Agent-skill & plugin READMEs — the special requirements

Skill/plugin READMEs (`SKILL.md` + README) must do three things a library README
skips. This is the archetype readmedaddy itself belongs to, so get it right.

1. **State the trigger.** For agent skills the `description` frontmatter line is
   the single most important string AND the firing condition — the model reads
   only that line to decide whether to fire. Write it as *"Use when… Triggers
   include: '<phrase>', '<phrase>'."* with concrete utterances a user would
   actually type. `anthropics/skills` defines the genre: frontmatter is `name` +
   `description` only, where the description states what it does AND when to use
   it. In the README body, surface triggers as **literal blockquoted user
   utterances** (e.g. ai-stack-cost-audit: "Audit my AI coding stack for cost
   optimization." / "Why am I hitting Claude limits?").

2. **Install into the conventional tools dir, with a path table.** The install
   command drops the skill into a directory the agent scans
   (`/plugin marketplace add owner/repo`, `~/.claude/skills/…`), not an npm dep.
   For multi-agent skills, ship a small **install-path table** (tool → path) to
   kill ambiguity:

   | Agent | Install path |
   |-------|--------------|
   | Claude Code | `~/.claude/skills/<name>/` |
   | opencode | `~/.config/opencode/skill/<name>/` |
   | Copilot CLI | `~/.copilot/skills/<name>/` |

   Offer both the one-liner (`npx …`) and a manual clone + `install.sh`. Name both
   invocation paths — the explicit handle (`/skill-name`, "invoke by name") and
   the implicit auto-trigger (fires on description match) — plus a confirm-loaded
   tip (`/skills list`).

3. **Show it FIRING.** The signature move library READMEs skip: a literal
   user-utterance → observed-output transcript, or a crisp **before/after**
   ("without it: a wishy-washy three-way survey; with it: a decisive pick +
   reason"). obra/superpowers sells the *outcome behavior* ("Claude gains
   engineering discipline — brainstorming, planning, TDD, systematic debugging"),
   not a file inventory.

Supporting moves: an annotated **Layout file tree** showing `SKILL.md` as the
lean entry and `references/` as pull-on-demand (communicates the
progressive-disclosure architecture); a **"Why this one"** section positioning
against the niche in 3–5 evidence-first bullets; explicit **scope / non-goals**
to reduce mis-firing.

---

## ASCII art — wordmark or nothing

ASCII art is a *brand accelerator for terminal-native projects*. It works when it
conveys the name or the idea in five seconds; it is noise otherwise.

**Use it** for CLI tools, dev tooling, runtimes, and agent skills — places where
the audience lives in a monospaced terminal and a clean wordmark reads as
identity. **Skip it** for SaaS, apps, and enterprise/data products, where a
screenshot or product banner carries far more than letters made of blocks.

Rules when you do use it:

- Generate a **wordmark**, not decoration. `figlet`/`toilet` in the **ANSI
  Shadow** font (also "Standard" / "Big") produces clean block letters that read
  as the project name.
- Keep it **≤ 72 columns** so it renders on GitHub and on narrow screens without
  wrapping. Wrapped ASCII is worse than none.
- Put it in a **fenced code block** so spacing survives proportional fonts.
- **Monochrome only.** GitHub strips ANSI color from code blocks — if you need
  color, use a real image logo instead.
- Prefer a **small apt diagram** (a dial, a pipeline, a before/after axis) over a
  wordmark when the *idea* is more memorable than the *name* — but only if it
  encodes the idea precisely.

**Good — a clean wordmark** (legible letters, narrow, says the name):

```
██████╗  ███╗   ███╗ ██████╗
██╔══██╗ ████╗ ████║ ██╔══██╗
██████╔╝ ██╔████╔██║ ██║  ██║
██╔══██╗ ██║╚██╔╝██║ ██║  ██║
██║  ██║ ██║ ╚═╝ ██║ ██████╔╝
╚═╝  ╚═╝ ╚═╝     ╚═╝ ╚═════╝
```

**Good — a tiny apt diagram** (encodes the idea, not the name):

```
  repo ──▶ detect archetype ──▶ rank gates ──▶ assemble ──▶ README
```

**Bad — noise** (spells nothing, encodes nothing):

```
░▒▓█ ╳╳ ▞▚▞ █▓▒░ ✦ ⌁ ▙▟▛▜ ╳ ▒░▒░
```

It spends the most valuable real estate on the page to say zero.

---

## Badges — honest signal vs slop

Badges are trust compression: one row should answer *is this maintained, does it
build, can I install it, what's it licensed under, where's the community.* Treat
it as a **credential strip, not a trophy wall** — one line, one flat style, each
badge answering a distinct question. Generate with **shields.io** (`badges/shields`)
or **badgen** (`badgen.net`). The test for any badge: *does it state a fact a
reader can verify, that helps a decision?* If not, cut it.

**Honest badges** (keep, roughly this order):

| Badge | States | Source |
|-------|--------|--------|
| CI / build | the test suite passes on the default branch | GitHub Actions status badge (live) |
| Release / version | the current published version | shields.io / badgen, dynamic from registry or releases |
| Package / registry | it's installable (npm, PyPI, crates.io…) | shields.io registry badge (live) |
| License | the license, at a glance | shields.io static or repo-derived |
| Downloads / stars | adoption, **only live** (npm weekly, PyPI) | shields.io dynamic |
| Coverage | test coverage, **only if a real service reports it** | Codecov / Coveralls |
| Security / quality | OpenSSF Scorecard, CII Best Practices | the respective service |
| Citation / DOI | a citable artifact (data/ML/research) | Zenodo DOI badge |
| Community | where to ask (Discord/chat) | shields.io static link badge |

**Slop badges** (cut on sight):

- **Fabricated counts** — invented star/download/user numbers. Live badges that
  pull the real number are fine; hard-coded vanity numbers are a lie.
- **Badge walls** — fifteen badges so no reader parses any. Keep one row of ~4–6.
- **Decoration badges** — "made with ❤️", "awesome", bare "PRs welcome" stickers
  that encode no checkable fact.
- **Badges for things that don't exist** — a CI badge with no pipeline, a
  coverage badge with no coverage job. A badge that can't be wrong is worthless;
  one that's quietly wrong is worse.

Placement: a single row directly under the title/wordmark and one-line
description, before the body, with **no heading**. Link each badge to the thing
it reports (CI badge → the Actions run, version badge → the release page) so the
claim is one click from proof. One well-chosen audience badge (gitui's
`unsafe-forbidden`, a coverage grade) says more than a sentence would.

---

## Tooling

| Need | Tools |
|------|-------|
| Badges | shields.io, badgen — pick ONE style (`flat-square` or `for-the-badge`), don't mix |
| ASCII wordmarks | `figlet` / `toilet` (font: ANSI Shadow) |
| Terminal recordings | asciinema, vhs, ttygif, terminalizer; `svg-term` to embed crisp SVG |
| TOC | doctoc, markdown-toc (add only past ~100 lines / 3 screens) |
| Dark/light logos | `<picture>` + `prefers-color-scheme`, transparent PNG |

---

## Common mistakes — what a generator must prevent

- **Value prop buried under badges.** The one-line prop goes ABOVE the badge row.
- **No usage example**, or an example that isn't copy-paste runnable (hidden
  prerequisites, no expected output).
- **Adjectives instead of evidence.** "Blazingly fast / robust / seamless" with
  no table. If you claim speed, show numbers and link the method (ripgrep).
- **Assuming reader context.** Write Installation for a novice: exact runtime/OS
  versions and deps, no assumed environment.
- **Wall of text, no headings.** GitHub renders single-column; long unscannable
  prose is where READMEs go to die unread. Keep it skimmable in 1–2 minutes and
  route depth to a docs site.
- **Half-duplicated docs.** Commit to ONE strategy — README-as-full-docs (Zod) OR
  thin-README-hands-off (Tailwind/React). Half-copies rot.
- **Stale inlined installers.** Don't paste long platform-specific curl scripts;
  point to the canonical install page (Poetry).
- **Screenshots that vanish on dark mode.** Use transparent PNG or theme-aware
  `<picture>`.
- **Over-badging** and **License missing or not last.**
- **For agent skills specifically:** a `description` that says what it does but
  not WHEN to use it (no triggers); no firing demo; no install-path clarity. These
  three omissions are the difference between a skill that fires and one that
  doesn't.
