# Security Scanning — MoMoSim

This document describes the automated security scanning in the MoMoSim CI
pipeline, added for Formative 3 and hardened into a hard gate for the
Summative. Three scanners run on every pull request targeting `main`, and
again as the first job of the CD pipeline (`cd.yml`) before anything is
built or deployed: one checks the application's npm dependencies, one checks
the built Docker image, and one checks the Terraform infrastructure code.
All run automatically — no manual steps are needed. All three now **fail the
build** on unaccepted critical findings; anything accepted is named
explicitly below, not silently ignored.

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
The job has two steps: a non-blocking report (`npm audit`, prints every advisory
for visibility) and a gate that runs `npm audit --audit-level=high --omit=dev`.
This means:

- **HIGH/CRITICAL in a production dependency** → build fails, PR is blocked.
- **Dev-only advisories, and MODERATE/LOW** → printed in the log for visibility
  but do **not** block the PR.

The gate is scoped to production dependencies (`--omit=dev`) on purpose: the
production Docker image is built with `npm ci --omit=dev`, so build-time tooling
(Jest, ESLint and their transitive dependencies) never reaches deployment. The
report step still surfaces those dev advisories so nothing is hidden.

### Findings (scan date: 2026-07-21)

**Production dependencies (what ships): 0 vulnerabilities.** The app's only runtime
dependency is `express` and its tree, which scans clean at HIGH/CRITICAL.

Earlier in the project, two advisories were found and **fixed** with `npm audit fix`
(no breaking changes; 33 tests + lint still passed):

| Package | Severity | Issue | Advisory |
|---|---|---|---|
| `brace-expansion` < 1.1.16 | HIGH | Denial of service via malformed patterns | GHSA-3jxr-9vmj-r5cp |
| `js-yaml` | HIGH | Denial of service via crafted YAML input | GHSA-h67p-54hq-rp68, GHSA-52cp-r559-cp3m |

Subsequently, a new advisory (`GHSA-mh99-v99m-4gvg`) re-rated `brace-expansion`
HIGH across a much wider version range, cascading through the Jest/ESLint toolchain
(`brace-expansion` → `minimatch` → `glob` → `jest`). All of these are **developer
tooling**, not production code.

### How it was addressed — Fixed where possible, otherwise scoped out of the gate

- **Fixed:** the earlier advisories above were resolved by upgrading with
  `npm audit fix`.
- **Scoped (accepted for dev tooling):** the remaining Jest/ESLint advisories have
  no non-breaking fix — the only automated remediation, `npm audit fix --force`,
  downgrades Jest to `25.0.0`, a breaking change that would break the test suite.
  Because these packages are build-time only and are excluded from the production
  image, the gate audits production dependencies (`--omit=dev`). Production is clean,
  the dev advisories remain visible in the report step, and they will be picked up
  automatically once an upstream non-breaking fix lands.

**Result:** The `dependency-scan` gate passes on production dependencies, while any
new HIGH/CRITICAL in a package that actually ships will still hard-fail the build.

---

## Scanner 2 — Container Image Scan (Trivy)

### What it does
Trivy scans the built Docker image layer-by-layer, checking all OS packages and
bundled software inside the image against the CVE databases (NVD, Alpine SecDB,
and others). This catches vulnerabilities that exist in the base image or runtime
environment, which `npm audit` cannot see.

### Where it runs
Two steps inside the `docker-build` job in `.github/workflows/ci.yml`,
immediately after the image is built. `ci.yml` runs on every pull request
targeting `main`, and is also invoked as the first job of the CD pipeline
(`cd.yml`) before anything is built/deployed — so a merge to `main` never
skips this gate.

### Settings

| Step | Severity filter | Fixed-only | On findings |
|---|---|---|---|
| Report (visibility) | `CRITICAL,HIGH` | Yes | Report only, **does not** fail the build |
| Gate (Summative requirement) | `CRITICAL` only | Yes | **Fails the build** |

The report step is unchanged from F3 and stays non-blocking for the reasons
below. The gate step is new for the Summative CD requirement ("fail the build
if critical vulnerabilities are detected") and hard-fails on any CRITICAL
finding. It's scoped to CRITICAL rather than CRITICAL+HIGH because the two
currently-known findings (below) are both HIGH, live in a base image we don't
control, and have no fix available — blocking on those specifically would
give no security benefit while permanently freezing the team's merges.

### Findings (scan date: 2026-07-21)

The app's **own packages scanned completely clean**. All findings were inside the
base image (`node:20-alpine`) and its bundled components:

| CVE | Component | Severity | Location |
|---|---|---|---|
| CVE-2026-29786 | `node-tar` / `tar` 7.5.11 (bundled with npm) — hardlink path traversal | HIGH | Base image |
| CVE-2026-31802 | `tar` 7.5.11 (bundled with npm) — file overwrite via symlink traversal | HIGH | Base image |

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

## Scanner 3 — Infrastructure-as-Code Scan (Checkov)

### What it does
Checkov statically analyses the Terraform configuration in `terraform/` for
insecure infrastructure settings — for example overly-open security-group rules,
unencrypted volumes, instances with public IPs, or missing logging. It catches
misconfigurations in the infrastructure definition *before* anything is deployed,
which neither `npm audit` nor Trivy can see.

### Where it runs
A dedicated `iac-scan` job inside `.github/workflows/ci.yml`, scoped to the
`terraform/` directory. It runs on every pull request targeting `main`, and
(via `workflow_call`) as the first job of `cd.yml` before any deploy.

### Settings

| Setting | Value |
|---|---|
| Scope | `terraform/` directory, Terraform framework only |
| Output | Failed checks only (quiet) |
| `skip_check` | The 19 check IDs below — already triaged and reasoned |
| On findings | **Fails the build** (`soft_fail: false`) for anything *not* in `skip_check` |

Changed for the Summative: F3 ran this scan as report-only (`soft_fail: true`)
while the infrastructure was still being designed. Now that Terraform is
final, the gate is hard — any check *not* explicitly triaged below blocks the
build, satisfying "fail on critical" without relitigating decisions already
made.

### Findings (scan date: 2026-07-26, re-verified after the Summative Terraform expansion)

The Terraform grew substantially for the Summative (bastion, RDS, ECR, IAM
modules added on top of the F3 app server + network) and those additions
hadn't been triaged before. Re-running Checkov against the current code:
**92 passed, 0 failed** once the 19 IDs below are skipped. None are
exploitable defects — each is a structural requirement of this architecture,
a cost trade-off consistent with the project's stated "minimize credit burn"
design (see `terraform/README.md`), a choice already reasoned in the
Terraform code's own comments, or a verified static-analysis false positive.

| Checkov ID | Finding | Why it's accepted |
|---|---|---|
| CKV_AWS_88 | Bastion EC2 has a public IP | Its entire purpose is to be the one public-facing host — that's what makes it a bastion |
| CKV_AWS_130 | Public subnets auto-assign public IPs | Required for the bastion to get its public IP; the dedicated SG still controls which ports are open |
| CKV_AWS_260 | SG allows `0.0.0.0/0` on port 80 | The public URL requirement — the bastion forwards this to the app via iptables |
| CKV_AWS_24 | SG allows `0.0.0.0/0` on port 22 (flagged on `app_ssh_from_bastion`) | False positive — that rule uses `referenced_security_group_id` (bastion SG only), never a CIDR; verified manually, same class of gap as CKV2_AWS_5 below |
| CKV2_AWS_5 (×3: bastion/app/db SGs) | "Security group not attached to a resource" | Attached via a cross-module reference Checkov can't trace (`compute` module consumes `security` module's output) — verified manually |
| CKV2_AWS_12 | Default VPC SG not restricted | Project uses its own dedicated, default-deny SGs; the VPC's built-in default group is simply unused |
| CKV_AWS_126 | Detailed monitoring off (app + bastion) | AWS cost, out of scope for a short-lived coursework environment |
| CKV_AWS_135 | Instances not EBS-optimized | Performance flag, not a security control; not needed at this instance size |
| CKV2_AWS_11 | VPC flow logging off | AWS cost, out of scope |
| CKV_AWS_161 | RDS IAM authentication not enabled | Would require app-level changes to generate IAM auth tokens; the app doesn't even use the DB yet (in-memory store) — out of scope |
| CKV_AWS_293 | RDS deletion protection off | **Conflicts on purpose** with `skip_final_snapshot`/ECR `force_delete` — this environment is destroyed and rebuilt repeatedly to save credits; deletion protection would block that |
| CKV_AWS_353 | RDS performance insights off | AWS cost, out of scope |
| CKV_AWS_157 | RDS not Multi-AZ | ~2x RDS cost; already named as an "obvious production upgrade" out of scope in `terraform/README.md` |
| CKV_AWS_129 | RDS log exports not enabled | AWS cost/complexity, out of scope (cheap future improvement, noted for the infra owner) |
| CKV_AWS_118 | RDS enhanced monitoring off | AWS cost, out of scope |
| CKV2_AWS_30 | RDS query logging off | AWS cost/complexity, out of scope |
| CKV2_AWS_60 | RDS "copy tags to snapshot" off | Low-value on a DB that never takes a final snapshot (`skip_final_snapshot: true`) |
| CKV_AWS_136 | ECR not encrypted with KMS | Already reasoned in `modules/registry/main.tf`: AES256 (AWS-managed key) avoids KMS cost/rotation ceremony with no requirement driving it |
| CKV_AWS_51 | ECR image tags mutable | Already reasoned in `modules/registry/main.tf`: the deploy flow re-points `:latest`; each push is also SHA-tagged for traceability |

### How it was addressed
All 19 IDs above are accepted and explicitly named in `skip_check` in
`ci.yml` — this is a hard allow-list, not a blanket soft-fail: anything not
on it now blocks the build. If the Terraform changes and introduces a new
finding, the build fails until it's either fixed or added here with the same
kind of documented reasoning.

---

## Accepted Risks Summary

| Risk | Scanner | Reason accepted |
|---|---|---|
| CVE-2026-29786, CVE-2026-31802 in `node:20-alpine` | Trivy | In a base image we don't control; both HIGH not CRITICAL; no fix available; not reachable at runtime. The CRITICAL gate still blocks anything at that severity. |
| 19 Checkov IDs (bastion public IP, port 80/22 rules, RDS cost trade-offs, ECR mutability/encryption, SG cross-module false positives — full list and reasoning above) | Checkov | Structural design requirements, cost trade-offs consistent with the project's "minimize credit burn" goal, or verified scanner false positives. Explicitly named in `skip_check`; the gate hard-fails on anything else. |

Superseded by the Summative Terraform expansion: the F3-era **CKV2_AWS_41**
("no IAM role on the instance") no longer applies — the app server now has
an IAM instance role, scoped to pulling from exactly one ECR repository (see
`modules/iam/main.tf`), which the registry-based CD deploy depends on.

**No risks are accepted at the application dependency level.** Scanner 1 is set
to hard-fail on HIGH/CRITICAL, so any newly discovered vulnerability in the app's
own packages will immediately block the PR until fixed.

---

## Monitoring Going Forward

- On every PR (and again as the first job of `cd.yml` on merge to `main`), CI
  automatically re-runs all scans. Any new HIGH/CRITICAL finding in app
  dependencies, any new CRITICAL image CVE, or any new Checkov finding not
  already in `skip_check` will now block the pipeline — including the deploy.
- When a new `node:20-alpine` (or `node:22-alpine`) release resolves the accepted
  CVEs, the base image should be updated in `momosim/Dockerfile` and the fix noted
  here.
- If the Terraform changes and Checkov flags something new, that's expected to
  happen occasionally now that the gate is hard — review it with the
  infrastructure owner and either fix it or add the check ID to `skip_check`
  in `ci.yml` with the same kind of documented reasoning used above. Don't
  widen `skip_check` without a reason recorded here.
