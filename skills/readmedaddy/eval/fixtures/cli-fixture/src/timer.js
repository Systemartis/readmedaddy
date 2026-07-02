// Core timer logic for chronr. State is held in a small in-memory registry
// keyed by a short id; persistence is out of scope for this fixture.
const registry = new Map();

export class Timer {
  start(label = "") {
    const id = Math.random().toString(36).slice(2, 8);
    registry.set(id, { startedAt: Date.now(), label, splits: [] });
    return id;
  }

  split(id, label = "") {
    const t = registry.get(id);
    if (!t) throw new Error(`no such timer: ${id}`);
    const at = Date.now() - t.startedAt;
    t.splits.push({ at, label });
    return `${id} +${formatElapsed(at)}${label ? " " + label : ""}`;
  }

  stop(id) {
    const t = registry.get(id);
    if (!t) throw new Error(`no such timer: ${id}`);
    const elapsed = Date.now() - t.startedAt;
    registry.delete(id);
    return elapsed;
  }

  list() {
    return [...registry.entries()].map(
      ([id, t]) => `${id} ${t.label || "(unlabeled)"}`
    );
  }
}

export function formatElapsed(ms) {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  return m > 0 ? `${m}m${String(s % 60).padStart(2, "0")}s` : `${s}s`;
}
