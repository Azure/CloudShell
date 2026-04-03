---
name: Update Pinned Library Versions
description: Check and update pinned library versions (Istio and RootlessKit) in the Dockerfile
---

# Update Pinned Library Versions

This skill checks for newer releases of pinned library versions in
`linux/base.Dockerfile` and updates them when a newer version is available.

## Libraries tracked

### Istio

| Field | Value |
|---|---|
| File | `linux/base.Dockerfile` |
| Line pattern | `ENV ISTIO_VERSION=<version>` |
| Latest release API | `https://api.github.com/repos/istio/istio/releases/latest` — use the `.tag_name` field |
| Release notes | `https://github.com/istio/istio/releases/tag/<version>` |

### RootlessKit

| Field | Value |
|---|---|
| File | `linux/base.Dockerfile` |
| Line pattern | `ROOTLESSKIT_VERSION=v<semver>` (inside a `RUN` block, not an `ENV` line) |
| Latest release API | `https://api.github.com/repos/rootless-containers/rootlesskit/releases/latest` — use the `.tag_name` field (includes the `v` prefix) |
| Release notes | `https://github.com/rootless-containers/rootlesskit/releases/tag/<version>` |

## Procedure

1. **Read** `linux/base.Dockerfile` and extract the current pinned versions:
   - Istio — the value after `ENV ISTIO_VERSION=`
   - RootlessKit — the `v`-prefixed version after `ROOTLESSKIT_VERSION=`

2. **Fetch** the latest release version for each library from the GitHub Releases
   API URLs listed above (the `.tag_name` field of the JSON response).

3. **Compare** current vs. latest for each library. Only proceed with updates
   where the versions differ.

4. **Edit** `linux/base.Dockerfile`:
   - Istio: replace the entire `ENV ISTIO_VERSION=<old>` line with
     `ENV ISTIO_VERSION=<new>`.
   - RootlessKit: replace `ROOTLESSKIT_VERSION=<old>` with
     `ROOTLESSKIT_VERSION=<new>` (preserve the surrounding `RUN` block).

5. **Verify** the edit by re-reading the file and confirming the new version
   strings appear exactly where expected.

## Commit message

```
chore: update pinned library versions
```

## Pull request

- **Title**: `chore: update pinned library versions`
- **Base branch**: `master`
- **Labels**: `version_upgrade`, `automated_pr`
- **Body** — include:
  - A bullet list of updated libraries with old → new versions.
  - Links to the relevant GitHub release notes.
  - A note that the PR was automatically created.
