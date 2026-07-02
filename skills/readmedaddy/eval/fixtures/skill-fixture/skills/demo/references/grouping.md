# Commit grouping rules

Map each kept commit to exactly one changelog section. When a commit fits more
than one, the higher row in this table wins.

| Section | Commit signals |
|---|---|
| Security | `security:`, CVE references, auth/permission fixes |
| Removed | `remove:`, deleted public API, dropped support |
| Deprecated | `deprecate:`, "will be removed" notes |
| Added | `feat:`, new flags, new endpoints, new exports |
| Changed | `change:`, `refactor:` with user-visible effect, behavior changes |
| Fixed | `fix:`, regression repairs, crash fixes |

## Noise filter (dropped, never emitted)

- Merge commits and revert-of-revert chains.
- Formatting-only, lint, and whitespace commits.
- CI / build-config changes with no user-facing effect.
- Docs-only commits, unless they document a behavior change.
