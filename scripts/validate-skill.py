#!/usr/bin/env python3
"""Structural validator for the readmedaddy skill. Standard library only.

Run from the repo root:  python3 scripts/validate-skill.py
Exits non-zero on any real violation. This is the contract CI enforces; keep it
in sync with .github/workflows/ci.yml. It also owns the clean-for-publish
(forbidden-reference) guard as the single source of truth.

Checks:
  1. SKILL.md frontmatter: name charset, description present and within budget
     (warn >600, fail >1024). Handles folded-scalar (>-) descriptions.
  2. Every relative markdown link in SKILL.md + references/ resolves on disk.
  3. No forbidden personal / company-internal references (clean-for-publish).
  4. Version consistency: SKILL.md metadata.version == top CHANGELOG entry.
  5. All four reference files are present.
  6. The rubric defines every gate G1..G10.
  7. Every archetype named in the rubric also appears in archetypes.md.
  8. Auto-update hook shipped: hooks/readme-drift.sh and scripts/install-hook.py
     exist, and SKILL.md reaches references/auto-update-hook.md.

Files that other build agents have not written yet degrade to a clear WARN
rather than crashing or hard-failing, so the validator can run green mid-build.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILL_DIR = os.path.join(ROOT, "skills", "readmedaddy")
SKILL_MD = os.path.join(SKILL_DIR, "SKILL.md")
REF_DIR = os.path.join(SKILL_DIR, "references")
errors = []
warnings = []
notes = []


def err(m):
    errors.append(m)


def warn(m):
    warnings.append(m)


def note(m):
    notes.append(m)


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    return m.group(1) if m else None


# 1. Frontmatter -------------------------------------------------------------
version = None
if not os.path.exists(SKILL_MD):
    warn("skills/readmedaddy/SKILL.md not present yet — skipping frontmatter checks")
else:
    fm = frontmatter(read(SKILL_MD))
    if fm is None:
        err("SKILL.md: missing YAML frontmatter")
    else:
        nm = re.search(r"^name:\s*(.+)$", fm, re.M)
        if not nm:
            err("SKILL.md: frontmatter missing 'name'")
        elif not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", nm.group(1).strip()):
            err(f"SKILL.md: name '{nm.group(1).strip()}' must be lowercase letters/digits/hyphens")
        # description may be a folded scalar (>- ) spanning indented lines
        dm = re.search(
            r"^description:\s*(>-?|\|-?)?[ \t]*\n((?:[ \t]+.*\n?)+)", fm, re.M
        )
        desc = None
        if dm:
            desc = " ".join(l.strip() for l in dm.group(2).splitlines() if l.strip())
        else:
            one = re.search(r"^description:\s*(.+)$", fm, re.M)
            desc = one.group(1).strip() if one else None
        if not desc:
            err("SKILL.md: frontmatter missing 'description'")
        else:
            if len(desc) > 1024:
                err(f"SKILL.md: description is {len(desc)} chars (>1024 hard cap)")
            elif len(desc) > 600:
                warn(f"SKILL.md: description is {len(desc)} chars (target <600)")
        vm = re.search(r"version:\s*\"?([0-9]+\.[0-9]+\.[0-9]+)\"?", fm)
        version = vm.group(1) if vm else None

# 2. Relative links resolve --------------------------------------------------
# A broken link whose target is one of the not-yet-written required reference
# files is a concurrent-build artifact (degrade to WARN); any other broken link
# is a real violation.
REQUIRED_REFS = [
    "multi-gate-rubric.md",
    "archetypes.md",
    "famous-readme-patterns.md",
    "generation-and-ranking.md",
]
pending_ref_paths = {
    os.path.normpath(os.path.join(REF_DIR, r)) for r in REQUIRED_REFS
}
md_files = [SKILL_MD]
if os.path.isdir(REF_DIR):
    md_files += [os.path.join(REF_DIR, f) for f in os.listdir(REF_DIR) if f.endswith(".md")]
link_re = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
checked_links = 0
pending_link_warns = set()
for mf in md_files:
    if not os.path.exists(mf):
        continue
    base = os.path.dirname(mf)
    for target in link_re.findall(read(mf)):
        t = target.split("#")[0].strip()
        if not t or t.startswith(("http://", "https://", "mailto:")):
            continue
        checked_links += 1
        resolved = os.path.normpath(os.path.join(base, t))
        if not os.path.exists(resolved):
            if resolved in pending_ref_paths:
                pending_link_warns.add(os.path.basename(resolved))
            else:
                err(f"{os.path.relpath(mf, ROOT)}: broken link -> {target}")
for ref in sorted(pending_link_warns):
    warn(f"link target references/{ref} not written yet — will resolve once present")

# 2b. Backtick / plain-text reference pointers in SKILL.md resolve ------------
# SKILL.md points at its reference files as `references/<name>.md` code spans,
# not markdown links, so the link check above cannot see them. Every such token
# must resolve on disk or the running skill dead-ends.
ref_token_re = re.compile(r"references/([A-Za-z0-9._-]+\.md)")
checked_ref_tokens = 0
if os.path.exists(SKILL_MD):
    for ref_name in sorted(set(ref_token_re.findall(read(SKILL_MD)))):
        checked_ref_tokens += 1
        target = os.path.join(REF_DIR, ref_name)
        if not os.path.exists(target):
            if os.path.normpath(target) in pending_ref_paths:
                warn(f"reference pointer references/{ref_name} not written yet — will resolve once present")
            else:
                err(f"SKILL.md: dead reference pointer -> references/{ref_name}")
    note(f"SKILL.md reference pointers checked: {checked_ref_tokens}")

# 3. Forbidden references (clean-for-publish) --------------------------------
# Maintainer-private terms (names, sibling-project codenames, local paths) must
# never leak into shipped files. The patterns are stored base64-encoded so this
# guard does not itself publish the terms it screens for; decode locally to
# review or extend the list. Word-boundaried, unambiguous terms only.
# This file is excluded from its own scan; "Systemartis" (the org) is allowed.
import base64

_FORBIDDEN_B64 = [
    "XGJtYWljb3ZzY2hpXGI=", "XGJtYXhpbSB0dWRvclxi", "XGJjb21wZW5kaXVtXGI=",
    "XGJwb2x5bWFrZXJcYg==", "XGJhZXRoZXJcYg==", "XGJwb2x5cm94XGI=",
    "XGJzaHVyaWtlblxi", "XGJhdXJhLW11c2ljXGI=", "XGJzZW8tZ2VvXGI=",
    "XGJ2b2ljZXZhXGI=", "XGJwc2V1ZG9mYWJsZVxi", "L3VzZXJzLw==",
]
FORBIDDEN = [base64.b64decode(t).decode() for t in _FORBIDDEN_B64]
self_path = os.path.abspath(__file__)
scan = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    if ".git" in dirpath:
        continue
    for fn in filenames:
        if fn.endswith((".md", ".sh", ".py", ".yml", ".yaml")):
            scan.append(os.path.join(dirpath, fn))
for p in scan:
    if os.path.abspath(p) == self_path:
        continue
    try:
        low = read(p).lower()
    except (UnicodeDecodeError, OSError):
        warn(f"{os.path.relpath(p, ROOT)}: unreadable, skipped forbidden-reference scan")
        continue
    for term in FORBIDDEN:
        if re.search(term, low):
            err(f"{os.path.relpath(p, ROOT)}: forbidden reference '{term}' (clean-for-publish)")

# 4. Version consistency -----------------------------------------------------
changelog = os.path.join(ROOT, "CHANGELOG.md")
if not os.path.exists(changelog):
    warn("CHANGELOG.md not present yet — skipping version-consistency check")
elif version:
    cm = re.search(r"^##\s*\[?([0-9]+\.[0-9]+\.[0-9]+)\]?", read(changelog), re.M)
    if cm and cm.group(1) != version:
        err(f"version mismatch: SKILL.md {version} vs CHANGELOG {cm.group(1)}")
    elif cm:
        note(f"version {version} matches top CHANGELOG entry")

# 5. Reference files present -------------------------------------------------
present_refs = 0
for rf in REQUIRED_REFS:
    if os.path.exists(os.path.join(REF_DIR, rf)):
        present_refs += 1
    else:
        warn(f"references/{rf} not present yet — dependent checks will be skipped")
note(f"references present: {present_refs}/{len(REQUIRED_REFS)}")

# 6. Rubric defines every gate G1..G10 ---------------------------------------
rubric_path = os.path.join(REF_DIR, "multi-gate-rubric.md")
if os.path.exists(rubric_path):
    rtext = read(rubric_path)
    missing_gates = [f"G{n}" for n in range(1, 11) if not re.search(rf"\bG{n}\b", rtext)]
    if missing_gates:
        err(f"multi-gate-rubric.md: missing gate id(s): {', '.join(missing_gates)}")
    else:
        note("rubric: gates G1-G10 all defined")
else:
    warn("references/multi-gate-rubric.md not present yet — skipping gate-id check")

# 7. Rubric archetypes are documented in archetypes.md -----------------------
# Tolerant cross-consistency: an archetype is "named in the rubric" if any of
# its canonical aliases appears (case-insensitive substring); it must then be
# "documented" by some alias appearing in archetypes.md.
ARCH_ALIASES = [
    ("CLI",              ["cli"]),
    ("library",          ["library"]),
    ("framework",        ["framework"]),
    ("app/SaaS",         ["saas", "app/", "web app"]),
    ("infra/devops",     ["infra", "devops"]),
    ("data/ML",          ["data/ml", "data-ml", " ml ", "machine learning"]),
    ("agent-skill",      ["agent skill", "agent-skill", "plugin"]),
    ("research",         ["research"]),
    ("monorepo",         ["monorepo"]),
    ("internal-tool",    ["internal"]),
]
archetypes_path = os.path.join(REF_DIR, "archetypes.md")
if os.path.exists(rubric_path) and os.path.exists(archetypes_path):
    rlow = read(rubric_path).lower()
    alow = read(archetypes_path).lower()
    named = 0
    consistent = 0
    for label, aliases in ARCH_ALIASES:
        if any(a in rlow for a in aliases):
            named += 1
            if any(a in alow for a in aliases):
                consistent += 1
            else:
                err(f"archetype '{label}' named in rubric but absent from archetypes.md")
    note(f"archetypes cross-check: {consistent}/{named} consistent")
else:
    warn("rubric and/or archetypes.md not present yet — skipping archetype cross-check")

# 8. Auto-update hook shipped ------------------------------------------------
HOOK_SCRIPT = os.path.join(SKILL_DIR, "hooks", "readme-drift.sh")
if os.path.exists(HOOK_SCRIPT):
    note("hook: skills/readmedaddy/hooks/readme-drift.sh present")
else:
    err("skills/readmedaddy/hooks/readme-drift.sh missing (auto-update hook script)")

INSTALL_HOOK = os.path.join(ROOT, "scripts", "install-hook.py")
if os.path.exists(INSTALL_HOOK):
    note("hook: scripts/install-hook.py present")
else:
    err("scripts/install-hook.py missing (Stop-hook installer)")

# The new reference must be reachable from SKILL.md (its references list links it).
hook_ref = os.path.join(REF_DIR, "auto-update-hook.md")
if not os.path.exists(SKILL_MD):
    warn("SKILL.md not present yet — skipping auto-update-hook reference reachability check")
elif not os.path.exists(hook_ref):
    err("references/auto-update-hook.md missing (auto-update hook reference)")
elif "auto-update-hook.md" not in read(SKILL_MD):
    err("SKILL.md does not reference references/auto-update-hook.md (new ref unreachable)")
else:
    note("hook: SKILL.md reaches references/auto-update-hook.md")

# Report ---------------------------------------------------------------------
for n in notes:
    print(f"  ok    {n}")
print(f"  ok    relative links checked: {checked_links}")
for w in warnings:
    print(f"  WARN  {w}")
if errors:
    for e in errors:
        print(f"  FAIL  {e}")
    print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
    sys.exit(1)
print(f"\nOK — validate-skill passed ({len(warnings)} warning(s))")
