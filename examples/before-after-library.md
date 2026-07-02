# Before / after: a library (`fetchet`)

> **Illustrative example.** `fetchet` is an invented, generic TypeScript library
> used to show the lift readmedaddy produces on a **library** README. The package,
> API, and badges are fictional (the shields would resolve once such a package were
> published). The point is the *shape* of the upgrade and how it scores. Both
> READMEs are shown as raw Markdown so you can see exactly what readmedaddy emits.

readmedaddy detected the **library** archetype (an importable package, an API you
call, published to a registry). Library weighting is different from CLI: it puts the
most weight on **G4 Quickstart as API usage** (the smallest real call, copy-paste
correct), **G2 Identity / trust** (version, CI, size, types, license badges), and
**G6 Completeness** (options, errors, examples). It deliberately *under*-weights
ASCII art — a library sells itself with code, not a banner — so the upgrade leads
with a typed code hero instead of a wordmark.

## The repo readmedaddy looked at

A ~1 KB, zero-dependency wrapper around the platform `fetch` that adds retries,
timeouts, and a typed error. It is fully typed, tested with Vitest, and runs in
Node, Deno, Bun, and the browser. The thin README mentioned none of that and never
showed the API doing the one thing the library exists for.

## Before — the thin README

````markdown
# fetchet

A small wrapper around fetch that adds retries and timeouts.

## Install

```
npm install fetchet
```

## Usage

```
import { fetchet } from "fetchet";

const data = await fetchet("/api/user");
```

It will retry failed requests and time out after a while. You can pass options
as a second argument.

## License

MIT
````

The fatal gap for a library: the one usage snippet is untyped and shows none of the
features that are the whole reason to install it. No badges, no options, no error
shape — a reader cannot evaluate it without reading the source.

## After — the readmedaddy upgrade

````markdown
# fetchet

[![ci](https://github.com/acme/fetchet/actions/workflows/ci.yml/badge.svg)](https://github.com/acme/fetchet/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/fetchet.svg)](https://www.npmjs.com/package/fetchet)
[![minzipped](https://img.shields.io/bundlephobia/minzip/fetchet)](https://bundlephobia.com/package/fetchet)
[![types](https://img.shields.io/npm/types/fetchet.svg)](https://www.npmjs.com/package/fetchet)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**`fetch`, but it retries, times out, and throws typed errors — in about 1 KB.**

`fetchet` is a tiny, dependency-free wrapper around the platform `fetch`. It keeps
the API you already know and adds the three things you always re-implement: retries
with backoff, a real timeout, and a typed error you can branch on. Works in Node
18+, Deno, Bun, and the browser.

```ts
import { fetchet } from "fetchet";

// Typed JSON, 3 retries, 5s timeout — one call.
const user = await fetchet<User>("/api/user/42", { retries: 3, timeout: 5000 });
```

## Install

```sh
npm install fetchet      # or: pnpm add fetchet · yarn add fetchet · bun add fetchet
```

## Why

- **Drop-in.** Same signature as `fetch`; pass a URL, get parsed JSON back, typed.
- **Resilient by default.** Retries idempotent failures with exponential backoff
  and jitter.
- **Honest errors.** Non-2xx responses and timeouts throw a `FetchetError` with
  `status`, `attempts`, and the original `cause`.
- **Tiny.** Zero dependencies; ships ESM, CJS, and types.

## API

```ts
fetchet<T>(input: string | URL, options?: FetchetOptions): Promise<T>
```

Returns the parsed JSON body typed as `T`. Throws `FetchetError` on a non-2xx
response, a timeout, or an exhausted retry budget.

### Options

`FetchetOptions` extends the standard `RequestInit`, so every `fetch` option still
works (`method`, `headers`, `body`, `signal`, …). Added fields:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `retries` | `number` | `0` | Max retry attempts after the first try. |
| `retryDelay` | `(attempt: number) => number` | exp backoff + jitter | Milliseconds to wait before attempt `n`. |
| `retryOn` | `number[]` | `[408, 429, 500, 502, 503, 504]` | Status codes that trigger a retry. |
| `timeout` | `number` | none | Abort the request after N milliseconds. |
| `parse` | `"json" \| "text" \| false` | `"json"` | How to read the body; `false` returns the raw `Response`. |

### Errors

```ts
import { fetchet, FetchetError } from "fetchet";

try {
  await fetchet<User>("/api/user/42", { retries: 2, timeout: 3000 });
} catch (err) {
  if (err instanceof FetchetError) {
    err.status;    // e.g. 503, or 0 on a timeout
    err.attempts;  // how many tries were made
    err.cause;     // the underlying error or Response
  }
}
```

## Examples

```ts
// POST with a typed response and a custom retry policy.
const order = await fetchet<Order>("/api/orders", {
  method: "POST",
  body: JSON.stringify(cart),
  headers: { "content-type": "application/json" },
  retries: 4,
  retryOn: [502, 503, 504],
});

// Cancel early with your own AbortSignal.
const controller = new AbortController();
const feed = await fetchet<Feed>("/api/feed", { signal: controller.signal });

// Get the raw Response instead of parsed JSON.
const res = await fetchet("/exports/report.csv", { parse: false });
```

## When not to use it

`fetchet` is deliberately small. If you need request/response interceptors,
caching, or schema validation, reach for a fuller client (`ky`, `axios`, or
`fetch` + a validator). `fetchet` does four things well and stops there.

## Contributing

PRs welcome — run `npm test` (Vitest) and `npm run lint` first. See
[CONTRIBUTING.md](CONTRIBUTING.md) and the [CHANGELOG.md](CHANGELOG.md).

## License

MIT © acme. See [LICENSE](LICENSE).
````

## What changed, and why it scores higher

- **G4 Quickstart / API usage (2 → 5).** The hero snippet now shows the *typed*
  call with retries and a timeout — the exact thing the library exists for — and it
  is copy-paste correct. For a library this is the highest-weighted gate.
- **G2 Identity / trust (1 → 5).** A badge row (CI, npm version, minzipped size,
  types, license) lets a reader judge freshness, footprint, and type support before
  reading a line of prose.
- **G6 Completeness (1 → 5).** A signature, an **options table**, an **error shape**,
  and runnable **examples** cover what an integrator needs — without padding.
- **G7 Credibility (1 → 4).** Tests and CI are visible, and a **When not to use it**
  section names real alternatives instead of overclaiming.
- **G3 stays low on purpose.** No ASCII banner — the library archetype rewards a
  code hero over a wordmark, so readmedaddy spends the first screen on the API.
- **G1 / G5 / G10.** A sharp one-line hook, heading hierarchy with tables, and a
  confident, slop-free voice.

## Gate scores (library weighting)

Each gate is scored 0–5, then multiplied by its library-archetype weight from the
rubric's resolved vectors (weights sum to 29, max raw total 145, normalized to
/100 as `round(raw / 145 × 100, 1)`). Note how the weights differ from the CLI
example: G4, G2, and G6 carry the load here, and G3 stays at base weight.

| Gate | Wt | Before | After | Wt·Before | Wt·After |
|------|----|--------|-------|-----------|----------|
| G1 Hook | 2 | 1 | 5 | 2 | 10 |
| G2 Identity / trust (badges) | 5 | 1 | 5 | 5 | 25 |
| G3 Visual | 2 | 1 | 3 | 2 | 6 |
| G4 Quickstart (API usage) | 6 | 2 | 5 | 12 | 30 |
| G5 Scannability | 2 | 2 | 5 | 4 | 10 |
| G6 Completeness | 4 | 1 | 5 | 4 | 20 |
| G7 Credibility | 2 | 1 | 4 | 2 | 8 |
| G8 Contextual fit | 2 | 2 | 5 | 4 | 10 |
| G9 Community / maint | 2 | 1 | 4 | 2 | 8 |
| G10 Voice | 2 | 2 | 5 | 4 | 10 |
| Raw total (/145) | 29 | — | — | 41 | 137 |
| **Normalized (/100)** | — | — | — | **28.3** | **94.5** |

**Lift: 28.3 → 94.5 (+66.2).** The points concentrate where the library weighting
puts them: G4 (the typed API hero) and G2 (the badge row) together account for the
largest share of the gain. Same rubric as the CLI example, different weights — that is
the contextual ranking system doing its job.
