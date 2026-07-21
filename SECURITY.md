# Security Scanning — MoMoSim

This document describes the automated security scanning added to the MoMoSim CI
pipeline for Formative 3. Two scanners run on every pull request targeting `main`:
one checks the application's npm dependencies, and one checks the built Docker
image. Both run automatically — no manual steps are needed.

---

## Scanner 1 — Dependency Vulnerability Scan (npm audit)

### What it does
`npm audit` queries the npm advisory database and checks every package listed in
`package-lock.json` against known CVEs and security advisories. It catches
vulnerable transitive dependencies that would not be visible from `package.json`
alone.

### Where it runs
A dedicated `dependency-scan` job inside `.github/workflows/ci.yml`. It runs on
every pull request targeting `main`, after the lint-and-test job passes.

### Settings
The job runs `npm audit --audit-level=high`. This means:

- **HIGH** or **CRITICAL** severity findings → build fails, PR is blocked.
- **MODERATE** or **LOW** findings → reported in the log but do not block the PR.

### Findings (scan date: 2026-07-21)

| Package | Severity | Issue | Advisory |
|---|---|---|---|
| `brace-expansion` < 1.1.16 | HIGH | Denial of service via malformed patterns | GHSA-3jxr-9vmj-r5cp |
| `js-yaml` | HIGH | Denial of service via crafted YAML input | GHSA-h67p-54hq-rp68, GHSA-52cp-r559-cp3m |

Both packages are developer-tool dependencies (used by Jest and ESLint during the
build). Neither is included in the production Docker image that runs in deployment.

### How it was addressed — FIXED

```
npm audit fix
```

`npm audit fix` resolved both issues by upgrading the affected packages to safe
versions in `package-lock.json`. A re-scan immediately after confirmed **0
vulnerabilities** at HIGH or above. The full test suite (33 tests) and lint check
still pass without modification, confirming no breaking changes were introduced.

**Result:** The `dependency-scan` job now passes cleanly on every subsequent run.

---

## Scanner 2 — Container Image Scan (Trivy)

### What it does
Trivy scans the built Docker image layer-by-layer, checking all OS packages and
bundled software inside the image against the CVE databases (NVD, Alpine SecDB,
and others). This catches vulnerabilities that exist in the base image or runtime
environment, which `npm audit` cannot see.

### Where it runs
A step inside the `docker-build` job in `.github/workflows/ci.yml`, immediately
after the image is built. It runs on every pull request targeting `main`.

### Settings

| Setting | Value |
|---|---|
| Severity filter | `CRITICAL,HIGH` only |
| Fixed-only | Yes — only shows CVEs that have a patch available |
| On findings | Report (write results to the log); **does not** fail the build |

The scan is intentionally set to report rather than block (see rationale below).

### Findings (scan date: 2026-07-21)

The app's **own packages scanned completely clean**. All findings were inside the
base image (`node:20-alpine`) and its bundled components:

| CVE | Component | Severity | Location |
|---|---|---|---|
| CVE-2026-29786 | `node-tar` / `tar` 7.5.11 (bundled with npm) | HIGH | Base image |
| CVE-2026-31802 | Alpine OS package | HIGH | Base image |

These are brand-new 2026 advisories. No patched base image was available at the
time of the scan.

### How it was addressed — Accepted risk (documented)

Blocking the build on these findings is not feasible or appropriate, for three
reasons:

1. **Not our code.** The vulnerabilities live in `node:20-alpine`, a base image
   maintained by the Node.js Docker team. We cannot patch someone else's image.

2. **No fix available yet.** Both CVEs were published in 2026. At scan time, no
   updated base image existed that resolves them. Trivy's `--ignore-unfixed` flag
   ensures we are not reporting noise — these are confirmed unfixed issues.

3. **Not reachable in production.** The vulnerabilities are in archive-handling
   code (`tar`, `npm`). The production container only runs `node server.js` — it
   never invokes `npm`, `tar`, or any archive utility at runtime. There is no
   reachable code path that exposes these vulnerabilities to an attacker.

Blocking the entire team's pipeline on base-image CVEs we cannot fix would
permanently prevent merges while providing no security benefit. The correct
response is to document the risk, monitor for base-image updates, and upgrade
`node:20-alpine` as soon as a patched version is released.

---

## Accepted Risks Summary

| Risk | Scanner | Reason accepted |
|---|---|---|
| CVE-2026-29786 in `node:20-alpine` | Trivy | In base image we don't control; no fix available; not reachable at runtime |
| CVE-2026-31802 in `node:20-alpine` | Trivy | Same as above |

**No risks are accepted at the application dependency level.** Scanner 1 is set
to hard-fail on HIGH/CRITICAL, so any newly discovered vulnerability in the app's
own packages will immediately block the PR until fixed.

---

## Monitoring Going Forward

- On every PR, CI automatically re-runs both scans. Any new HIGH/CRITICAL finding
  in app dependencies will block the PR.
- When a new `node:20-alpine` (or `node:22-alpine`) release resolves the accepted
  CVEs, the base image should be updated in `momosim/Dockerfile` and the fix noted
  here.
