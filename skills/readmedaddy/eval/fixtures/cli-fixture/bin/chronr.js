#!/usr/bin/env node
// chronr — stopwatch + split timer for shell pipelines.
import { Timer, formatElapsed } from "../src/timer.js";

const HELP = `chronr — stopwatch and split-timer for shell pipelines

Usage:
  chronr start [--label TEXT]   start a timer, print its id
  chronr split <id> [--label T] record a split against a running timer
  chronr stop <id>              stop a timer and print total elapsed
  chronr ls                     list running timers

Options:
  -h, --help     show this help and exit
  -v, --version  print version and exit

Examples:
  id=$(chronr start --label build)
  make && chronr split "$id" --label compiled
  chronr stop "$id"
`;

function main(argv) {
  const args = argv.slice(2);
  if (args.length === 0 || args.includes("-h") || args.includes("--help")) {
    process.stdout.write(HELP);
    return 0;
  }
  if (args.includes("-v") || args.includes("--version")) {
    process.stdout.write("chronr 0.3.1\n");
    return 0;
  }

  const [cmd, ...rest] = args;
  const timer = new Timer();
  switch (cmd) {
    case "start":
      process.stdout.write(timer.start(labelOf(rest)) + "\n");
      return 0;
    case "split":
      process.stdout.write(timer.split(rest[0], labelOf(rest)) + "\n");
      return 0;
    case "stop":
      process.stdout.write(formatElapsed(timer.stop(rest[0])) + "\n");
      return 0;
    case "ls":
      process.stdout.write(timer.list().join("\n") + "\n");
      return 0;
    default:
      process.stderr.write(`chronr: unknown command '${cmd}'\n` + HELP);
      return 2;
  }
}

function labelOf(rest) {
  const i = rest.indexOf("--label");
  return i >= 0 ? rest[i + 1] : "";
}

process.exit(main(process.argv));
