# Security Scanning — MoMoSim

This document describes the automated security scanning added to the MoMoSim CI
pipeline for Formative 3. Three scanners run on every pull request targeting `main`:
one checks the application's npm dependencies, one checks the built Docker image,
and one checks the Terraform infrastructure code. All run automatically — no manual
steps are needed.

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
`terraform/` directory. It runs on every pull request targeting `main`.

### Settings

| Setting | Value |
|---|---|
| Scope | `terraform/` directory, Terraform framework only |
| Output | Failed checks only (quiet) |
| On findings | Report (write results to the log); **does not** fail the build (`soft_fail`) |

The scan is intentionally set to report rather than block (see rationale below).

### Findings (scan date: 2026-07-21)

The Terraform is already substantially hardened — the EC2 instance requires IMDSv2,
its root volume is encrypted, the security group is default-deny, and SSH is
restricted to the operator's IP. Checkov evaluated 33 checks and returned
**26 passed, 7 failed**. None of the 7 are exploitable defects; they are intentional
design choices, cost trade-offs for a short-lived formative environment, or a
static-analysis limitation — each is explained below.

| Checkov ID | Finding | Resource |
|---|---|---|
| CKV_AWS_130 | Public subnet auto-assigns public IPs on launch | `module.network.aws_subnet.public` |
| CKV2_AWS_41 | No IAM role attached to the EC2 instance | `module.compute.aws_instance.app` |
| CKV_AWS_126 | Detailed monitoring not enabled on the instance | `module.compute.aws_instance.app` |
| CKV2_AWS_11 | VPC flow logging not enabled | `module.network.aws_vpc.main` |
| CKV_AWS_135 | Instance not marked EBS-optimized | `module.compute.aws_instance.app` |
| CKV2_AWS_5 | Security group not detected as attached to a resource | `module.security.aws_security_group.app` |
| CKV2_AWS_12 | Default VPC security group does not restrict all traffic | `module.network.aws_vpc.main` |

### How it was addressed — Accepted risks (documented)

Each finding is either an intentional project requirement or a limitation of the
scanner, not an oversight:

1. **Public IP on the subnet (CKV_AWS_130).** Intentional — the app server needs a
   public IP so Ansible and API users can reach it; a NAT gateway / bastion is out
   of scope for a formative. The dedicated security group still controls exactly
   which ports are open.

2. **No IAM role on the instance (CKV2_AWS_41).** Intentional, and safer here — the
   server only runs the container and never calls AWS APIs, so attaching no instance
   role means there are no AWS credentials on the box for an attacker to steal.

3. **Detailed monitoring & VPC flow logs off (CKV_AWS_126, CKV2_AWS_11).** Both add
   AWS cost and are out of scope for a short-lived formative environment.

4. **EBS optimization not set (CKV_AWS_135).** A performance flag, not a security
   control; the small instance type in use does not require it. No security impact.

5. **Security group "not attached" (CKV2_AWS_5).** A static-analysis limitation, not
   a real gap: the security group *is* attached to the EC2 instance, but through a
   cross-module reference (the `compute` module consumes the `security` module's
   output), which Checkov cannot trace. Verified manually.

6. **Default VPC security group not locked down (CKV2_AWS_12).** The project uses its
   own dedicated, default-deny security group; the VPC's built-in default group is
   left unused. This one could optionally be hardened with an
   `aws_default_security_group` resource that denies all traffic — noted for the
   infrastructure owner.

Because these live in the infrastructure workstream's Terraform and represent
conscious design trade-offs, the scan is configured to **report and document**
rather than block — so findings are visible on every PR and reviewed with the
infrastructure owner, without freezing the team's merges over accepted risks.

---

## Accepted Risks Summary

| Risk | Scanner | Reason accepted |
|---|---|---|
| CVE-2026-29786 in `node:20-alpine` | Trivy | In base image we don't control; no fix available; not reachable at runtime |
| CVE-2026-31802 in `node:20-alpine` | Trivy | Same as above |
| Public IP on subnet (CKV_AWS_130) | Checkov | Required for Ansible/API access; no bastion in scope; security group limits open ports |
| No IAM role on instance (CKV2_AWS_41) | Checkov | Instance makes no AWS API calls; omitting the role means no credentials to steal |
| No detailed monitoring / flow logs (CKV_AWS_126, CKV2_AWS_11) | Checkov | Extra AWS cost, out of scope for a short-lived formative environment |
| EBS optimization off (CKV_AWS_135) | Checkov | Performance flag, not a security control; not needed for the instance type used |
| SG "unattached" (CKV2_AWS_5) | Checkov | False positive — SG is attached via a cross-module reference Checkov cannot trace |
| Default VPC SG not restricted (CKV2_AWS_12) | Checkov | Project uses a dedicated default-deny SG; VPC default group is unused (could be hardened) |

**No risks are accepted at the application dependency level.** Scanner 1 is set
to hard-fail on HIGH/CRITICAL, so any newly discovered vulnerability in the app's
own packages will immediately block the PR until fixed.

---

## Monitoring Going Forward

- On every PR, CI automatically re-runs all three scans. Any new HIGH/CRITICAL
  finding in app dependencies will block the PR.
- When a new `node:20-alpine` (or `node:22-alpine`) release resolves the accepted
  CVEs, the base image should be updated in `momosim/Dockerfile` and the fix noted
  here.
- If the Terraform changes, the Checkov scan re-evaluates it on the PR; any new
  infrastructure finding should be reviewed with the infrastructure owner and
  either fixed or added to the accepted-risks list above.
