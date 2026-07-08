#!/usr/bin/env node
// Behavioral test for the opencode session.idle drift notifier.
//
// Runs the plugin under a stubbed opencode runtime (fake `$` shell tag, fake
// client) against real throwaway git repos — verifying the notify-only
// contract without opencode, Bun, or any model: drift logs a warning, fresh
// stays silent, non-repos stay silent, and a blown-up shell can never
// escape the handler. Node >= 18, zero dependencies, zero network.

import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const DRIFT = join(here, "..", "..", "hooks", "readme-drift.sh");
const PLUGIN = join(here, "..", "..", "hooks", "opencode-drift-plugin.js");

let pass = 0;
let fail = 0;
function check(cond, name) {
  if (cond) {
    pass += 1;
    console.log("PASS: " + name);
  } else {
    fail += 1;
    console.log("FAIL: " + name);
  }
}

function git(cwd, ...args) {
  execFileSync("git", args, {
    cwd,
    env: {
      ...process.env,
      GIT_CONFIG_GLOBAL: "/dev/null",
      GIT_CONFIG_SYSTEM: "/dev/null",
    },
    stdio: "pipe",
  });
}

function makeRepo(root) {
  git(root, "init", "-q", "-b", "main", ".");
  git(root, "config", "user.email", "t@t.invalid");
  git(root, "config", "user.name", "t");
  git(root, "config", "commit.gpgsign", "false");
  writeFileSync(join(root, "README.md"), "readme\n");
  writeFileSync(join(root, "package.json"), '{"name":"x"}\n');
  git(root, "add", "-A");
  git(root, "commit", "-qm", "init");
}

// Stub of Bun's $ tag: cd <dir> && sh <script> --check, executed for real
// via node's child_process against the actual detector.
function makeShellStub(behavior) {
  return function $(_strings, ...values) {
    const chain = {
      quiet() {
        return chain;
      },
      nothrow() {
        return (async () => {
          if (behavior === "explode") {
            throw new Error("shell blew up");
          }
          const dir = String(values[0]);
          const script = String(values[1]);
          try {
            const stdout = execFileSync("sh", [script, "--check"], {
              cwd: dir,
              stdio: "pipe",
            });
            return { exitCode: 0, stdout };
          } catch (e) {
            return { exitCode: e.status ?? 127, stdout: e.stdout ?? "" };
          }
        })();
      },
    };
    return chain;
  };
}

const { ReadmedaddyDrift } = await import(PLUGIN);

async function runPlugin(directory, behavior) {
  const logs = [];
  const client = {
    app: {
      log: async (entry) => {
        logs.push(entry);
      },
    },
  };
  // Point the plugin's fixed script path at the real detector via HOME.
  const fakeHome = mkdtempSync(join(tmpdir(), "rmd-oc-home."));
  const skillHooks = join(
    fakeHome,
    ".config",
    "opencode",
    "skills",
    "readmedaddy",
    "hooks",
  );
  execFileSync("mkdir", ["-p", skillHooks]);
  execFileSync("cp", [DRIFT, join(skillHooks, "readme-drift.sh")]);
  const oldHome = process.env.HOME;
  process.env.HOME = fakeHome;
  try {
    const hooks = await ReadmedaddyDrift({
      $: makeShellStub(behavior),
      client,
      directory,
    });
    await hooks["session.idle"]();
  } finally {
    process.env.HOME = oldHome;
    rmSync(fakeHome, { recursive: true, force: true });
  }
  return logs;
}

// (1) drift -> exactly one warn log naming the file.
{
  const repo = mkdtempSync(join(tmpdir(), "rmd-oc-drift."));
  makeRepo(repo);
  writeFileSync(join(repo, "package.json"), '{"name":"x","v":2}\n');
  const logs = await runPlugin(repo, "run");
  check(
    logs.length === 1 &&
      logs[0].body.level === "warn" &&
      logs[0].body.message.includes("package.json"),
    "drift logs one warning naming the file",
  );
  rmSync(repo, { recursive: true, force: true });
}

// (2) fresh -> silence.
{
  const repo = mkdtempSync(join(tmpdir(), "rmd-oc-fresh."));
  makeRepo(repo);
  const logs = await runPlugin(repo, "run");
  check(logs.length === 0, "fresh repo stays silent");
  rmSync(repo, { recursive: true, force: true });
}

// (3) not a git repo (detector exits 2) -> silence, no throw.
{
  const dir = mkdtempSync(join(tmpdir(), "rmd-oc-norepo."));
  const logs = await runPlugin(dir, "run");
  check(logs.length === 0, "non-repo stays silent");
  rmSync(dir, { recursive: true, force: true });
}

// (4) shell blowing up is swallowed: notify-only can never break a session.
{
  const dir = mkdtempSync(join(tmpdir(), "rmd-oc-boom."));
  let threw = false;
  let logs = [];
  try {
    logs = await runPlugin(dir, "explode");
  } catch {
    threw = true;
  }
  check(!threw && logs.length === 0, "shell failure is swallowed (fail-open)");
  rmSync(dir, { recursive: true, force: true });
}

console.log(`\n--- opencode plugin: ${pass} passed, ${fail} failed ---`);
process.exit(fail ? 1 : 0);
