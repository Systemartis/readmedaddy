# Project Archetypes

The catalog readmedaddy uses to (1) classify a repo, (2) pull the README patterns that work for that class, and (3) decide which sections earn space. Each archetype lists: how to **detect** it from repo signals, the **must-have sections**, the **section emphasis**, the right **visual**, and 2–3 **exemplars** to emulate. Scoring weights (the G1–G10 gates) live in `multi-gate-rubric.md`.

Classify first. The archetype decides everything downstream — a benchmark table that sells a CLI is dead weight on a library, and the firing transcript that defines an agent skill is meaningless on a CSS framework.

---

## Detection precedence

Run top to bottom; first strong match wins. Disambiguators resolve the overlaps.

1. **`SKILL.md` / `plugin.json` / `/plugin marketplace` install** → **agent-skill** (loaded by a model, not run by a human).
2. **Workspace config** (`pnpm-workspace.yaml`, `lerna.json`, `turbo.json`, `nx.json`, Cargo `[workspace]`, `go.work`) + `packages/`/`apps/` → **monorepo** (root README; classify each package separately).
3. **ML stack** (`torch`/`tensorflow`/`jax`/`transformers`/`sklearn`, `.ipynb`, weights/checkpoints, `CITATION.cff`) → **data-ML** or **research** (see split).
4. **Runtime / daemon / orchestrator**, system binaries, `GOVERNANCE.md`, no GUI → **infra**.
5. **Dockerfile + `docker-compose.yml` + `.env.example` + web UI**, hosted+self-host → **app-SaaS**.
6. **Scaffolding CLI** (`create-*`, `init`), plugin system, convention dirs, inversion of control → **framework**.
7. **`bin` entry** (package.json `bin`, Cargo `[[bin]]`, `console_scripts`, Go `main`) + arg parser (clap/click/cobra/yargs) → **CLI**.
8. **Library entry, no `bin`**, public API exported, semver-published → **library**.
9. **Private, internal hostnames/secrets, no license, runbook language** → **internal-tool**.

### Disambiguators (the overlaps that bite)

| Confusion | Rule |
|---|---|
| CLI vs library | Both ship? If the CLI **is the product** → CLI. If the importable API is the product and the CLI is a helper → library. |
| Library vs framework | You **call it** (you own control flow) → library. **It calls you** (you fill in conventions/hooks) → framework. |
| Framework vs app-SaaS | Installed to **build other apps** → framework. Is itself the **deployed end product** → app-SaaS. |
| app-SaaS vs infra | Has an **end-user GUI** → app-SaaS. **System-level**, consumed by other software or operated by ops → infra. |
| data-ML vs research | Ships a **usable model/lib** (`pip install` + run) → data-ML. Ships an **experiment/result to reproduce** → research. |
| agent-skill vs CLI dev-tool | Loaded by an **agent** (SKILL.md, triggers, `~/.claude/skills`) → agent-skill. Run by a **human in a shell** (`bin`, `npx`) → CLI/dev-tool (Biome, shadcn read like agent tools but install into a *project*). |
| Anything vs monorepo | A monorepo is a **container of N archetypes**. Classify each package, but the **root** README obeys monorepo rules (routing + packages table). |

---

## Section-emphasis vocabulary (planning heuristic)

Eight *aspects* that guide **which sections to draft and how much space each
earns** (matrix at the bottom). Emphasis scale: **3 = decisive**, **2 =
important**, **1 = nice-to-have**, **0 = skip**. This is a drafting heuristic
only — **scoring** always uses the ten G1–G10 gates and per-archetype weights
in `multi-gate-rubric.md`.

- **Gist** — line-one value prop passes the 10-second "is this for me?" test.
- **Proof** — a hero artifact that shows it *working*: demo, screenshot, benchmark, results table.
- **Onboarding** — install + first runnable success, minimal friction.
- **Credibility** — curated badges, CI/build matrix, provenance, citations.
- **Routing** — links to docs, progressive disclosure, package navigation.
- **Trigger** — when it fires and how it's invoked (agent tools only).
- **Honesty** — scope, non-goals, limitations, project status.
- **Contribution** — dev setup, ownership, maintenance & community signals.

---

## CLI

Command-line tools: single binary, run in a shell.

**Detect**

- `bin` entry: package.json `"bin"`, Cargo `[[bin]]`, `[project.scripts]`/`console_scripts`, Go `main` + cobra/urfave.
- Arg parser dep: clap, click/typer/argparse, cobra, yargs/commander.
- `completions/`, man page, Homebrew formula, Crates.io/npm publish, installs to `PATH`.
- README leads with flags/usage and runnable invocations.

**Must-have sections** — tagline (≤10 words) → one badge line → demo (GIF/screenshot) → install (multi-channel) → usage examples with expected output → flags/options → comparison table *if replacing an entrenched tool* → license.

**Dominant aspects** — Onboarding (3), Proof (3), Gist (3). Speed claims need a benchmark table, not adjectives (ripgrep).

**Visual** — animated GIF (vhs / asciinema) for a workflow **plus** a static screenshot for layout/output. If the tool's output *is* the product (bat, neofetch, fd), lead with a real terminal capture of that output. ASCII banner only if you accept monochrome (GitHub strips ANSI color from code blocks).

**Exemplars**

- **ripgrep** — prose-first; earns "fast" with a benchmark table + linked methodology, not adjectives.
- **bat** — show-the-output hero; anchors to a known tool ("a `cat(1)` clone with…").
- **starship** — centered hero stack; demo captioned with exact terminal+theme so it's reproducible, not aspirational.

---

## Library

You import it and call it. Published as a dependency.

**Detect**

- Manifest exports a module, **no `bin`**; `src/lib.rs`, `index.ts` exports, public `__init__.py`.
- Semver-published to npm/PyPI/crates; ships types/`.d.ts`.
- README shows `import`/`require`/`use` then a call.

**Must-have sections** — value prop with the differentiator as one load-bearing word → one badge line → install one-liner → the single "aha" snippet → scannable feature bullets (bold lead-ins) → API reference *or* link to it → license. Pick **one** doc strategy: README-as-full-docs (deep anchored TOC) **or** thin launchpad to a docs site — never half-copy.

**Dominant aspects** — Onboarding (3), Routing (3), Gist (3). The snippet is the proof.

**Visual** — the code block *is* the visual. Optional dark/light logo. Screenshots rarely needed.

**Exemplars**

- **Zod** — README-as-docs; the `z.infer<typeof Schema>` payoff captures why the library exists in one line.
- **Drizzle** — differentiates by contrast ("no Rust binaries, no serverless adapters") + hard numbers (~7.4kb, 0 deps).
- **React** — authority through brevity; three bold mental-model bullets instead of a feature dump, everything else routes to react.dev.

---

## Framework

You build apps *inside* its conventions. Inversion of control.

**Detect**

- Scaffolding CLI (`create-*`, `init`), plugin system, lifecycle hooks, convention dirs (`app/`, `pages/`, `routes/`).
- Large external docs site, a "getting started" tutorial, an ecosystem/plugins page.

**Must-have sections** — positioning sentence built on one strategic adjective → badges → **labeled docs + source links in the first screen** → progressive quickstart (install → ~10-line app → "now change it to…") → benefit-titled feature bullets → sponsors/backers → license.

**Dominant aspects** — Routing (3), Onboarding (3), Gist (3). Treat the README as a launchpad: let a reader leave for the canonical docs in under 5 seconds.

**Visual** — dark/light logo banner. If the framework produces a visible artifact for free, screenshot it (FastAPI's auto-generated Swagger UI is the whole pitch). Otherwise none.

**Exemplars**

- **FastAPI** — progressive quickstart whose payoff is a screenshot of the free interactive docs; quantified claims ("200–300% faster to develop").
- **Vue** — one load-bearing adjective ("progressive, incrementally adoptable") + sponsor tiers for sustainability signal.
- **Tailwind** — the reusable skeleton: branding → one-sentence value prop → 4 badges → "For full documentation, visit…". Refuses to duplicate the docs.

---

## app-SaaS

A deployable application / platform. Has an end-user surface.

**Detect**

- `Dockerfile` + `docker-compose.yml`, `.env.example`, frontend dir + server, `migrations/`, deploy buttons, hosted + self-host.
- Not published as an importable dependency.

**Must-have sections** — analogy/positioning tagline → one badge line → **hero screenshot or demo GIF (clickable CTA to the live product)** → feature checklist with each item deep-linking to its doc → self-host quickstart → architecture diagram → licensing stated plainly → notable users / sponsors → license.

**Dominant aspects** — Proof (3), Gist (3), Credibility (2). Honesty (2) covers source-available licensing — address it up front (n8n's Sustainable Use License), don't bury it.

**Visual** — a real screenshot or short demo GIF of the UI **is** the value prop; make it a clickable CTA to the live product. An architecture diagram naming the wrapped OSS components earns trust ("not magic, just good open tools").

**Exemplars**

- **Supabase** — analogy headline ("the open-source Firebase alternative") + checklist-with-doc-links + a labeled architecture diagram.
- **n8n** — screenshot-first; benefit-titled features with embedded proof numbers (400+ integrations); honest about licensing.
- **Excalidraw** — tagline states category + license + differentiator in one breath; hero image is both demo and CTA.

---

## infra

Runtimes, orchestrators, daemons. Consumed by other software or operated by ops.

**Detect**

- Runtime/daemon/orchestrator; config files (yaml/toml); no GUI; multi-platform builds.
- `GOVERNANCE.md`, `SECURITY.md`, foundation/CNCF backing, governed release process.

**Must-have sections** — value prop (drop-in-replacement or all-in-one promise) → security/quality/freshness badges → **install matrix** (every channel as a labeled one-liner) → first command that *shows the differentiator* → architecture diagram → **per-platform CI/build status matrix** → **"using X" vs "developing X" split** → governance/community → license.

**Dominant aspects** — Credibility (3), Onboarding (3), Gist (3). Provenance ("originated from Google's Borg", "CNCF-hosted") persuades infra buyers more than any badge.

**Visual** — architecture diagram + a per-platform build matrix table (Build Type / Status / Artifacts). Minimal decoration, no marketing GIF. Offload heavy benchmarks to the site (Bun → bun.sh).

**Exemplars**

- **Kubernetes** — provenance + foundation credibility; explicit using-vs-developing split; badges = security/quality/freshness only.
- **Bun** — "a drop-in replacement for Node.js" collapses switching cost to zero; one-line install.
- **Deno** — six-channel install matrix (shell/PowerShell/Homebrew/Choco/WinGet/Scoop) so nobody hunts for theirs.

---

## data-ML

Ships a usable model or ML framework: `pip install`, then inference/training.

**Detect**

- `torch`/`tensorflow`/`jax`/`transformers`/`sklearn`, `.ipynb`, weights/checkpoints, `datasets/`, `train.py`/`infer.py`, CUDA/GPU.
- `CITATION.cff` / DOI, model cards, OpenSSF/CII badges.

**Must-have sections** — tagline → audience-tuned badges (downloads, DOI, OpenSSF) → `pip install` → smallest working snippet (3-line `pipeline()` / 4-line REPL) → **model/spec table whose last column is the exact command** → per-platform CI matrix → **"why use this" + "when NOT to use this"** → citation/BibTeX → license.

**Dominant aspects** — Honesty (3), Credibility (3), Onboarding (3). Optimize for time-to-first-token: every section ends in a runnable command.

**Visual** — model/spec table + CI build matrix; optional architecture diagram. No marketing GIF. A DOI and a translations row signal a living, citable, global project.

**Exemplars**

- **Ollama** — copy-paste model table (Model / Params / Size / Command); the README is one runnable command after another.
- **Hugging Face Transformers** — 3-line `pipeline()` in the first screen + a paired "when shouldn't I use this" section + DOI.
- **TensorFlow** — 8-row per-platform CI status matrix is the strongest maintenance/trust signal available.

---

## agent-skill / plugin

Loaded by an agent (Claude Code skill, plugin, MCP tool). The defining difference vs a library README: it must (1) state **triggers**, (2) install into a **conventional tools dir the agent scans**, and (3) show the tool **firing**.

**Detect**

- `SKILL.md` with `name` + `description` frontmatter, `references/` dir, `scripts/`, install via `~/.claude/skills/...` or `/plugin marketplace add owner/repo`.
- "Use when…" language; Markdown-driven; no traditional package manifest.

**Must-have sections** — 6–10 word identity line → **triggers as literal user utterances** (blockquoted: "Audit my AI stack for cost.") → **install-path table** (tool → dir) + one copy-paste install → **firing demo** (before/after or utterance→output transcript) → annotated **layout tree** (SKILL.md = lean entry + triggers; `references/` = pulled on demand) → "Why this one" (3–5 evidence-first bullets) → scope / "what it is not" → both invocation paths (explicit handle + auto-trigger) → license.

> Frontmatter rule (the skill's own discipline, and what readmedaddy should reward): `description` IS the trigger. Write it as "Use when… Triggers include: '<phrase>', '<phrase>'." — the model decides whether to fire on that line *alone*. Never make `description` a workflow summary.

**Dominant aspects** — Trigger (3), Honesty (3), Onboarding (3), Gist (3). This is the only archetype where Trigger is decisive.

**Visual** — a before/after **firing transcript** (text) is the signature visual; plus an annotated layout tree. ASCII banner is cheap identity for terminal-native tools. No screenshot needed.

**Exemplars**

- **Anthropic Agent Skills** — the genre definition: two-field frontmatter, description-as-trigger, marketplace install, a firing example by mention.
- **ai-stack-cost-audit** — literal-utterance triggers, an install-path table (Claude Code / opencode / Copilot → exact dirs), a "Why this one" section, an annotated `Layout` tree.
- **obra/superpowers** — sells the *new behavior* ("Claude gains engineering discipline"), one-line install, names both invocation paths.
- *Dev-tooling CLI variant* — **Biome** (command ladder + quantified replacement: "97% Prettier compatible, 500+ rules") and **shadcn** ("NOT a component library… copy and paste" reframe; CLI drops code into your repo).

---

## research

Produces knowledge/results, not a shipped product. Experiments, papers, skeletons.

**Detect**

- `papers/`, LaTeX, `.ipynb`, experiment skeleton, `pyproject` with research deps, `results/`/`figures/`.
- `CITATION.cff` / BibTeX, methodology/hypothesis framing, no deployment.
- Status reads experiment / skeleton / WIP.

**Must-have sections** — abstract-style tagline → motivation/background → method → **results (tables/figures)** → reproducibility (exact steps to rerun) → **citation/BibTeX** → **status + non-goals stated plainly** → license.

**Dominant aspects** — Honesty (3), Credibility (3), Proof (3). Emulate the *credibility + honesty* half of data-ML READMEs, not the marketing half. State status honestly ("skeleton", "experiment") — overselling an unfinished result is the failure mode here.

**Visual** — figures/plots, results tables, a method diagram. No marketing GIF, no hero screenshot.

**Exemplars**

- **Hugging Face Transformers** — DOI/citation + an honest "when NOT to use this"; the trust pattern research READMEs should copy.
- **TensorFlow** — reproducibility surfaced as a per-platform CI matrix + DOI.
- *(Corpus is thin here — research READMEs are scarce among the celebrated examples. Borrow the evidence-and-honesty conventions above; resist importing app-SaaS marketing moves.)*

---

## monorepo

A container of multiple publishable units. The **root** README routes; each package's own README teaches.

**Detect**

- Workspace config: `pnpm-workspace.yaml`, `lerna.json`, `turbo.json`, `nx.json`, Cargo `[workspace]`, `go.work`.
- `packages/`/`apps/` with multiple manifests, `changesets/`, multiple publishable units.

**Must-have sections** — umbrella value prop → **packages table** (package → npm/crate version → changelog → one-line purpose) → per-package docs routing → architecture of how packages relate → contributing/dev-setup (build/test the whole tree) → license.

**Dominant aspects** — Routing (3), Contribution (3), Credibility (2). The root README's job is navigation, not teaching.

**Visual** — the packages table is the primary visual; add a dependency/architecture diagram if the package relationships aren't obvious.

**Exemplars**

- **Vite** — packages table mapping each monorepo package to its npm version/changelog; thin root README + strong doc site.
- **Supabase** — official + community client-libraries table doubles as an ecosystem-breadth signal.

---

## internal-tool

Audience is teammates, not the public. Success = a new teammate can run and operate it from the README alone.

**Detect**

- Private repo, no license / proprietary, internal hostnames/secrets, `.env` to internal services.
- Deploy scripts, on-call/runbook language, no marketing copy, no published package.

**Must-have sections** — what it is + **why it exists** → **ownership** (who maintains, on-call/contact) → **runbook** (run / deploy / rollback) → config, secrets, access requirements → dependencies on internal systems → **gotchas/troubleshooting** → status → architecture/integration diagram.

**Dominant aspects** — Honesty (3), Onboarding (3), Contribution/ownership (3). **Credibility badges = 0** — there's no public audience to signal to; spend that space on the runbook and ownership.

**Visual** — an integration diagram showing where the tool sits among internal systems. No marketing visuals.

**Exemplars**

- *No public corpus exemplar — internal tools are private by nature.* Borrow: Kubernetes' "developing X" build-path rigor, makeareadme's contributing doctrine (exact setup/lint/test commands as if the reader is new), and a provenance/architecture diagram. Optimize for "can a teammate operate this at 3am" over any persuasion gate.

---

## Section-emphasis matrix (planning heuristic)

Rows = archetypes, columns = aspects. 3 = decisive, 2 = important, 1 = nice,
0 = skip. Drafting guidance only — scoring weights live in
`multi-gate-rubric.md`.

| Archetype | Gist | Proof | Onboard | Credib | Routing | Trigger | Honesty | Contrib |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| CLI | 3 | 3 | 3 | 2 | 1 | 0 | 1 | 1 |
| Library | 3 | 2 | 3 | 2 | 3 | 0 | 1 | 2 |
| Framework | 3 | 2 | 3 | 2 | 3 | 0 | 1 | 2 |
| app-SaaS | 3 | 3 | 2 | 2 | 2 | 0 | 2 | 1 |
| infra | 3 | 2 | 3 | 3 | 2 | 0 | 2 | 2 |
| data-ML | 2 | 2 | 3 | 3 | 2 | 0 | 3 | 1 |
| agent-skill | 3 | 2 | 3 | 2 | 2 | 3 | 3 | 1 |
| research | 2 | 3 | 2 | 3 | 1 | 0 | 3 | 1 |
| monorepo | 2 | 1 | 2 | 2 | 3 | 0 | 1 | 3 |
| internal-tool | 3 | 1 | 3 | 0 | 2 | 0 | 3 | 3 |

---

## Cross-archetype rules

True for every archetype unless a section above overrides:

- **Line one is the value prop**, above badges and install. Pass the gist test: a stranger decides "is this for me?" in ~10 seconds. 6–12 words, category + differentiator.
- **Badges on ONE line, 4–6, one flat style.** Each answers a distinct question: maintained? (CI/last-commit), adopted? (downloads/stars), safe/licensed? (license, OpenSSF/CII), community? (Discord). Never let a badge wall sit above the value prop.
- **First command runs on copy-paste** — one install line + one minimal example that actually works with no hidden prerequisites. Show expected output where you can.
- **Quantify, don't adjective.** "500+ rules", "~7.4kb, 0 deps", "187 tests passing" beat "blazing fast / robust / lightweight".
- **Theme-proof the visuals.** Use `<picture>` + `prefers-color-scheme` or transparent PNGs so logos/screenshots survive dark mode.
- **Pick one doc strategy and commit** — README-as-full-docs (deep anchored TOC) *or* thin launchpad to a docs site. Half-copies rot.
- **Honesty is a trust lever** — scope, non-goals, project status, and "when NOT to use this" buy more credibility than any superlative.
- **License last** (Standard-Readme), present, and matching the package-registry description so repo and registry tell one story.

### Anti-patterns readmedaddy should actively prevent

Value prop buried under badges · no working example · stale/untested install commands · assumes reader context · wall-of-text, no headings · screenshots that vanish in dark mode · over-badging · License missing or not last · README that duplicates the docs · (agent-skill) `description` written as a workflow summary instead of a trigger.
