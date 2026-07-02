# chronr

> Stopwatch and split-timer for shell pipelines.

![version](https://img.shields.io/badge/version-0.3.1-blue) ![node](https://img.shields.io/badge/node-%3E%3D18-brightgreen) ![license](https://img.shields.io/badge/license-MIT-yellow)

Time the stages of any shell workflow without leaving the terminal: start a timer, capture its id, record labeled splits as each step finishes, and read the total when you stop it. One command, four subcommands, no daemon.

```console
$ id=$(chronr start --label build)
$ make && chronr split "$id" --label compiled
a1b2c3 +42s compiled
$ chronr stop "$id"
1m03s
```

## Install

Requires Node.js >= 18. Not yet published to npm — install from a checkout:

```sh
npm install -g .    # run from the repo root
chronr --help
```

Or run it straight from the tree without installing:

```sh
node bin/chronr.js --help
```

## Usage

```
chronr start [--label TEXT]   start a timer, print its id
chronr split <id> [--label T] record a split against a running timer
chronr stop <id>              stop a timer and print total elapsed
chronr ls                     list running timers
```

| Option | Effect |
|--------|--------|
| `-h`, `--help` | show help and exit |
| `-v`, `--version` | print version (`chronr 0.3.1`) and exit |

`start` prints a short id to stdout, so it composes with command substitution: `id=$(chronr start --label deploy)`. Splits print as `<id> +<elapsed> <label>`; `stop` prints total elapsed (`3s`, `1m03s`) and removes the timer. `chronr ls` lists running timers as `<id> <label>` (or `(unlabeled)`). Unknown commands exit with status `2` and print usage.

### Example: timing a build

```sh
id=$(chronr start --label build)
make && chronr split "$id" --label compiled
chronr stop "$id"
```

## Use as a module

The timer core is also importable (`main` points at `src/timer.js`):

```js
import { Timer, formatElapsed } from "chronr";

const t = new Timer();
const id = t.start("deploy");
t.split(id, "uploaded");        // "<id> +3s uploaded"
formatElapsed(t.stop(id));      // "3s"
```

## Limitations

- Timer state lives in a small in-memory registry keyed by a short id; persistence is out of scope.
- Elapsed time is reported at whole-second resolution (`3s`, `1m03s`) — this is a stopwatch for pipeline stages, not a profiler.
- `split` and `stop` throw `no such timer: <id>` for unknown ids.

## License

MIT
