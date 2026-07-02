#!/usr/bin/env python3
"""Weighted gate scorer for readmedaddy. Standard library only.

Given per-gate judge scores (0-5 on G1..G10) and an archetype, compute the
contextual weighted total on a /100 scale, applying the SAME per-archetype
weights as references/multi-gate-rubric.md.

The weight tables below are the executable mirror of the rubric's resolved
weight vectors. The rubric is the source of truth: if the two ever disagree,
the rubric wins and this table must be corrected to match (in the same
commit). Per the rubric: every gate has base weight 2 and each archetype bumps
its three heaviest gates by +4/+3/+2, so every row sums to 29, the maximum
weighted score is 29 x 5 = 145, and the normalized total is
round(sum(w_i * s_i) / 145 * 100, 1).

Input (either form, auto-detected by extension or content):
  TSV  — header `readme<TAB>archetype<TAB>G1..G10`, one README per row.
  JSON — an object or a list of objects, each:
           {"readme": "id", "archetype": "cli", "scores": {"G1": 4, ...}}
         (a flat {"G1": 4, ...} alongside "archetype" is also accepted).

Usage:
  python3 score.py FILE.tsv          # score every row, print a table
  python3 score.py FILE.json         # same, JSON input
  python3 score.py                   # no args -> run inline self-tests
  python3 score.py --selftest        # run inline self-tests explicitly

Exit status is non-zero on a self-test failure or a malformed input row, so CI
can gate on it.
"""
import json
import os
import sys

GATES = [f"G{n}" for n in range(1, 11)]

# Per-archetype resolved weight vectors (G1..G10), read directly off the
# rubric's "Resolved weight vectors" table. Base 2 everywhere; the three
# heaviest gates get +4/+3/+2. Each row sums to 29. Heaviest-first per row:
#   cli          -> G3 (visual/demo), G4 (quickstart), G1 (hook)
#   library      -> G4 (API usage), G2 (badges), G6 (completeness)
#   framework    -> inherits library's vector
#   app-saas     -> G1 (hook), G3 (screenshot), G9 (community)
#   infra-devops -> G4 (quickstart), G7 (credibility), G6 (completeness)
#   data-ml      -> G1 (hook), G7 (results), G6 (completeness/citations)
#   agent-skill  -> G1 (hook/triggers), G4 (examples), G8 (contextual fit)
#   research     -> G1 (finding/abstract), G7 (reproducibility), G6 (citations)
#   monorepo     -> G5 (scannability), G6 (completeness), G1 (hook)
#   internal-tool-> inherits monorepo's vector
#                  G1  G2  G3  G4  G5  G6  G7  G8  G9 G10
WEIGHTS = {
    "cli":           [4,  2,  6,  5,  2,  2,  2,  2,  2,  2],
    "library":       [2,  5,  2,  6,  2,  4,  2,  2,  2,  2],
    "framework":     [2,  5,  2,  6,  2,  4,  2,  2,  2,  2],
    "app-saas":      [6,  2,  5,  2,  2,  2,  2,  2,  4,  2],
    "infra-devops":  [2,  2,  2,  6,  2,  4,  5,  2,  2,  2],
    "data-ml":       [6,  2,  2,  2,  2,  4,  5,  2,  2,  2],
    "agent-skill":   [6,  2,  2,  5,  2,  2,  2,  4,  2,  2],
    "research":      [6,  2,  2,  2,  2,  4,  5,  2,  2,  2],
    "monorepo":      [4,  2,  2,  2,  6,  5,  2,  2,  2,  2],
    "internal-tool": [4,  2,  2,  2,  6,  5,  2,  2,  2,  2],
}

# Max weighted score: 29 (row sum) x 5 (max gate score). The /100 divisor.
MAX_WEIGHTED = 29 * 5

# Natural-language labels a judge might emit -> canonical key.
ALIASES = {
    "cli": "cli", "command-line": "cli", "command line": "cli",
    "library": "library", "lib": "library", "package": "library",
    "framework": "framework",
    "app-saas": "app-saas", "app": "app-saas", "saas": "app-saas",
    "app/saas": "app-saas", "web app": "app-saas", "webapp": "app-saas",
    "infra-devops": "infra-devops", "infra": "infra-devops",
    "devops": "infra-devops", "infra/devops": "infra-devops",
    "data-ml": "data-ml", "data/ml": "data-ml", "ml": "data-ml",
    "data": "data-ml", "machine-learning": "data-ml",
    "agent-skill": "agent-skill", "skill": "agent-skill",
    "plugin": "agent-skill", "agent skill": "agent-skill",
    "agent-skill/plugin": "agent-skill",
    "research": "research", "paper": "research",
    "monorepo": "monorepo", "mono-repo": "monorepo",
    "internal-tool": "internal-tool", "internal": "internal-tool",
    "internal tool": "internal-tool",
}


def canon(archetype):
    """Map a free-form archetype label to a canonical weight key."""
    key = (archetype or "").strip().lower()
    if key in WEIGHTS:
        return key
    if key in ALIASES:
        return ALIASES[key]
    raise ValueError(f"unknown archetype: {archetype!r}")


def weighted_score(archetype, scores):
    """Weighted /100 total for one README.

    scores: dict mapping G1..G10 -> 0..5 (ints or floats). Missing gate -> 0;
    every gate must be in [0, 5]. Result is in [0, 100]: the raw weighted sum
    is at most 29 x 5 = 145 and is normalized by /145 x 100.
    """
    key = canon(archetype)
    w = WEIGHTS[key]
    total = 0.0
    for i, gate in enumerate(GATES):
        s = scores.get(gate, 0)
        try:
            s = float(s)
        except (TypeError, ValueError):
            raise ValueError(f"{gate}: non-numeric score {s!r}")
        if not 0 <= s <= 5:
            raise ValueError(f"{gate}: score {s} out of range 0..5")
        total += w[i] * s
    return round(total / MAX_WEIGHTED * 100, 1)


# --- input parsing ----------------------------------------------------------

def rows_from_tsv(text):
    lines = [ln for ln in text.splitlines() if ln.strip() and not ln.lstrip().startswith("#")]
    if not lines:
        return []
    header = [h.strip().lower() for h in lines[0].split("\t")]
    out = []
    for ln in lines[1:]:
        cells = ln.split("\t")
        rec = {header[i]: cells[i].strip() for i in range(min(len(header), len(cells)))}
        scores = {g: rec.get(g.lower(), 0) for g in GATES}
        out.append({
            "readme": rec.get("readme", rec.get("id", "?")),
            "archetype": rec.get("archetype", ""),
            "scores": scores,
        })
    return out


def rows_from_json(text):
    data = json.loads(text)
    if isinstance(data, dict):
        data = [data]
    out = []
    for obj in data:
        scores = obj.get("scores")
        if scores is None:  # accept flat {"G1": .., ...}
            scores = {g: obj.get(g, 0) for g in GATES}
        out.append({
            "readme": obj.get("readme", obj.get("id", "?")),
            "archetype": obj.get("archetype", ""),
            "scores": scores,
        })
    return out


def load(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if not text.strip():
        return []
    if path.endswith(".json"):
        return rows_from_json(text)
    if path.endswith(".tsv"):
        return rows_from_tsv(text)
    stripped = text.lstrip()
    return rows_from_json(text) if stripped[:1] in "[{" else rows_from_tsv(text)


def report(rows):
    print(f"{'readme':<28}{'archetype':<16}{'weighted/100':>13}")
    print("-" * 57)
    bad = 0
    for r in rows:
        try:
            total = weighted_score(r["archetype"], r["scores"])
            print(f"{str(r['readme']):<28}{str(r['archetype']):<16}{total:>13.1f}")
        except ValueError as e:
            bad += 1
            print(f"{str(r['readme']):<28}{str(r['archetype']):<16}{'ERROR: ' + str(e):>13}")
    return bad


# --- inline self-tests ------------------------------------------------------

def selftest():
    failures = []

    def check(name, got, want):
        if abs(got - want) > 1e-6:
            failures.append(f"{name}: got {got}, want {want}")

    # 1. Every weight row matches the rubric's contract: base 2 on every gate,
    #    bumps of +4/+3/+2 on exactly three gates, so each row sums to 29.
    for key, w in WEIGHTS.items():
        if sum(w) != 29:
            failures.append(f"weights[{key}] sum to {sum(w)}, not 29")
        if sorted(w) != [2, 2, 2, 2, 2, 2, 2, 4, 5, 6]:
            failures.append(f"weights[{key}] are not base-2 with +4/+3/+2 bumps: {w}")

    # 2. Heaviest-gate ordering per archetype matches the rubric's bump table.
    RUBRIC_TOP3 = {  # archetype -> (G with +4, G with +3, G with +2), heaviest first
        "cli": ("G3", "G4", "G1"),
        "library": ("G4", "G2", "G6"),
        "framework": ("G4", "G2", "G6"),
        "app-saas": ("G1", "G3", "G9"),
        "infra-devops": ("G4", "G7", "G6"),
        "data-ml": ("G1", "G7", "G6"),
        "agent-skill": ("G1", "G4", "G8"),
        "research": ("G1", "G7", "G6"),
        "monorepo": ("G5", "G6", "G1"),
        "internal-tool": ("G5", "G6", "G1"),
    }
    for key, top3 in RUBRIC_TOP3.items():
        w = WEIGHTS[key]
        got = tuple(g for _, g in sorted(zip(w, GATES), key=lambda p: -p[0])[:3])
        if got != top3:
            failures.append(f"weights[{key}] heaviest gates {got}, rubric says {top3}")

    allfive = {g: 5 for g in GATES}
    allzero = {g: 0 for g in GATES}
    allhalf = {g: 2.5 for g in GATES}
    for key in WEIGHTS:
        check(f"{key} all-5", weighted_score(key, allfive), 100.0)
        check(f"{key} all-0", weighted_score(key, allzero), 0.0)
        check(f"{key} all-2.5", weighted_score(key, allhalf), 50.0)

    # 3. Same scores, different archetype -> different total (proves the
    #    contextual weighting actually bites). G1,G3,G4 = 5, rest 0.
    hot = {g: (5 if g in ("G1", "G3", "G4") else 0) for g in GATES}
    check("cli G1/G3/G4", weighted_score("cli", hot), 51.7)      # (4+6+5)/29
    check("library G1/G3/G4", weighted_score("library", hot), 34.5)  # (2+2+6)/29

    # 4. Agent-skill leans on G1+G4+G8 (readmedaddy's own archetype).
    skillhot = {g: (5 if g in ("G1", "G4", "G8") else 0) for g in GATES}
    check("agent-skill G1/G4/G8", weighted_score("agent-skill", skillhot), 51.7)  # (6+5+4)/29

    # 5. Alias resolution and JSON/TSV parsing round-trip.
    check("alias app/saas==app-saas",
          weighted_score("App/SaaS", allfive), weighted_score("app-saas", allfive))
    tsv = "readme\tarchetype\t" + "\t".join(GATES) + "\nx\tcli\t" + "\t".join(["5"] * 10)
    check("tsv parse", weighted_score(rows_from_tsv(tsv)[0]["archetype"],
                                      rows_from_tsv(tsv)[0]["scores"]), 100.0)
    js = json.dumps([{"readme": "y", "archetype": "research",
                      "scores": {g: 3 for g in GATES}}])
    check("json parse", weighted_score(rows_from_json(js)[0]["archetype"],
                                       rows_from_json(js)[0]["scores"]), 60.0)

    # 6. Out-of-range and unknown archetype are rejected.
    for bad_arch in ("nope", ""):
        try:
            weighted_score(bad_arch, allfive)
            failures.append(f"unknown archetype {bad_arch!r} not rejected")
        except ValueError:
            pass
    try:
        weighted_score("cli", {g: 9 for g in GATES})
        failures.append("out-of-range score not rejected")
    except ValueError:
        pass

    if failures:
        print("SELFTEST FAILED:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"selftest OK — {len(WEIGHTS)} archetypes, weights sum to 29 (/145 "
          "normalization), rubric ordering verified")
    return 0


def main(argv):
    args = argv[1:]
    if not args or args[0] in ("--selftest", "-t", "selftest"):
        return selftest()
    path = args[0]
    if not os.path.exists(path):
        sys.stderr.write(f"no such file: {path}\n")
        return 2
    rows = load(path)
    if not rows:
        sys.stderr.write("no scorable rows found\n")
        return 2
    return 1 if report(rows) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
