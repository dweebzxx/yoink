# Versioning Policy

Policy version: 1.0.0
Based on: Semantic Versioning 2.0.0 (https://semver.org/spec/v2.0.0.html)

This file defines how every versioned component in this project is numbered, tagged, and recorded. Copy it into the repo root unchanged, then fill in the Component Registry.

## 1. Version Format

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

| Part | Rule |
|---|---|
| MAJOR, MINOR, PATCH | Non-negative integers. No leading zeroes. Compared numerically (1.9.0 < 1.10.0). |
| PRERELEASE | Optional. Hyphen, then dot separated identifiers from `[0-9A-Za-z-]`. Numeric identifiers have no leading zeroes. Ranks lower than the plain release. |
| BUILD | Optional. Plus sign, then dot separated identifiers from `[0-9A-Za-z-]`. Ignored when comparing versions. |

Standard pre-release sequence for this project:

```
1.0.0-alpha.1 < 1.0.0-beta.1 < 1.0.0-rc.1 < 1.0.0
```

Standard build metadata: `+YYYYMMDD` or `+sha.<7 char commit>`. Example: `1.4.0+sha.a1b2c3d`.

## 2. Core Rules (all components)

1. Every component declares its contract (what users or other components depend on). The bump rules apply to changes in that contract.
2. A released version is never modified. Any change, including a typo fix, ships as a new version.
3. Bumping MINOR resets PATCH to 0. Bumping MAJOR resets MINOR and PATCH to 0.
4. `0.y.z` means initial development. Anything may change. Start at `0.1.0` and bump MINOR per release.
5. Release `1.0.0` when the component is used for real work or others depend on it.
6. Deprecations ship in a MINOR release before removal in the next MAJOR release.
7. If a breaking change was shipped by mistake as MINOR or PATCH, release a new version that restores compatibility and note the bad version in the changelog.

## 3. Bump Rules by Component Type

### 3.1 Code and App Builds

Contract: public API, CLI flags and output, file formats the app reads or writes, settings, user-facing behavior.

| Bump | When |
|---|---|
| MAJOR | Removed or renamed API, CLI flag, or setting. Changed file or data format that older data cannot load. Dropped OS or platform support. |
| MINOR | New feature, new API, new flag, new setting. Anything marked deprecated. Large internal rewrite with no contract change. |
| PATCH | Bug fix, performance fix, security fix, dependency update that fixes a bug, with no contract change. |

### 3.2 Core Docs (specs, guides, agent instruction files, policies, templates)

Contract: the rules, requirements, structure, and section anchors that people, tools, or AI agents follow.

| Bump | When |
|---|---|
| MAJOR | A rule is removed, reversed, or made stricter so that previously valid work no longer complies. Sections other files link to are renamed or removed. |
| MINOR | New rule, section, or requirement that existing work still complies with. A rule marked deprecated. |
| PATCH | Typos, wording, formatting, examples, or clarifications that do not change meaning. |

Every versioned doc starts with this header:

```
---
title: <Document Title>
version: 1.0.0
updated: YYYY-MM-DD
status: draft | active | deprecated
---
```

### 3.3 Other Components (configs, schemas, datasets, prompts, scripts, userscripts, templates)

Contract: required fields, keys, column names, input and output shape, expected behavior.

| Bump | When |
|---|---|
| MAJOR | Field, key, or column removed or renamed. Type changed. Output shape changed. Required input added. |
| MINOR | Optional field, key, column, or capability added. |
| PATCH | Value corrections, fixes, or edits with no shape or behavior change. |

## 4. Source of Truth

Each component stores its version in exactly one place. Everything else reads from it.

| Component | Version lives in |
|---|---|
| Node or JS | `package.json` `version` |
| Python | `pyproject.toml` `[project] version` |
| Rust | `Cargo.toml` `[package] version` |
| macOS or iOS app | `MARKETING_VERSION` (MAJOR.MINOR.PATCH only) and `CURRENT_PROJECT_VERSION` (integer build number, increases every build uploaded or distributed) |
| Userscript | `// @version` in the metadata block |
| Doc | `version:` in the front matter header |
| Anything else | `VERSION` file at the component root containing only the version string |

Apple bundle version fields accept only numeric dotted values. Keep pre-release labels and build metadata in git tags and the changelog, not in `MARKETING_VERSION`.

## 5. Git Tags

Tags are annotated and point at the release commit. The `v` prefix marks a tag; the version itself has no `v`.

Single component repo:

```
v1.4.0
```

Multi component repo: prefix with the component name from the Component Registry.

```
app/v1.4.0
docs/v2.0.0
schema/v1.1.0
```

Create and push a release tag:

```
git tag -a v1.4.0 -m "Release 1.4.0"
git push origin v1.4.0
```

Tags are never moved or deleted after pushing. A wrong release gets a new version.

## 6. Changelog

Each component keeps a `CHANGELOG.md` (or a section in the repo root changelog for small repos). Newest release first. Dates in `YYYY-MM-DD`.

```
# Changelog

## [Unreleased]

## [1.4.0] - 2026-09-26
### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security
```

Omit empty headings in released entries. Anything under Removed or a breaking entry under Changed requires a MAJOR bump.

## 7. Release Checklist

1. Move entries from `[Unreleased]` into a new version heading with today's date.
2. Choose the bump using Section 3. If any entry is breaking, it is MAJOR.
3. Update the version in its source of truth (Section 4) and the doc header `updated:` date if applicable.
4. Validate the version string (Section 8).
5. Commit with message `release: <component> <version>`.
6. Create and push the annotated tag (Section 5).

## 8. Validation

POSIX extended regex (works with `grep -E`):

```
^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$
```

Check a version string:

```
echo "1.4.0-rc.1" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$' && echo valid || echo invalid
```

## 9. Component Registry

List every independently versioned component in this project.

| Component | Type | Tag prefix | Source of truth | Current version |
|---|---|---|---|---|
| <name> | code / doc / other | <prefix>/ or none | <path> | 0.1.0 |
