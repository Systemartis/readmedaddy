// readmedaddy drift notifier for opencode — session.idle -> local git check.
//
// Single file, zero dependencies, zero imports, zero network: it runs the
// readmedaddy drift detector (POSIX sh + local git, the same script every
// surface uses) and logs a warning when the README fell behind the code.
//
// Deliberately weaker than the Claude Code Stop hook: NOTIFY-ONLY. It never
// edits files, never injects anything into the agent's context, never blocks
// the session, and swallows every error — a notifier must be incapable of
// breaking a session. Per-repo off switch: `"hook": {"enabled": false}` in
// .readmedaddy.json (respected by the detector itself).
//
// Installed by readmedaddy's install.sh to ~/.config/opencode/plugins/.

export const ReadmedaddyDrift = async ({ $, client, directory }) => {
  const home = process.env.HOME || "";
  const script =
    home + "/.config/opencode/skills/readmedaddy/hooks/readme-drift.sh";

  return {
    "session.idle": async () => {
      try {
        const r = await $`cd ${directory} && sh ${script} --check`
          .quiet()
          .nothrow();
        // exit 1 = drift. exit 0 = fresh. exit 2 = not a repo / shallow —
        // silence for everything except a confirmed drift.
        if (r.exitCode === 1) {
          const files = (r.stdout ? r.stdout.toString() : "")
            .trim()
            .split("\n")
            .filter(Boolean)
            .slice(0, 5)
            .join(", ");
          await client.app.log({
            body: {
              level: "warn",
              message:
                "readmedaddy: " +
                files +
                " changed but the README did not — ask for 'readmedaddy' to refresh it.",
            },
          });
        }
      } catch {
        // fail-open, always.
      }
    },
  };
};
