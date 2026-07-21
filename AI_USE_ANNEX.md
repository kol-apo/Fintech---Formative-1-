# AI Use Annex — MoMoSim Formative 3

This document records every use of AI assistance (Claude) during Formative 3.
Each teammate fills in their own section. **Collect this as you go** — trying to
reconstruct conversations from memory at the end is unreliable and will likely
produce incomplete records.

---

## What counts as "AI use"

Record any interaction where Claude produced output you used or adapted in the
assignment. This includes:

- Generated code (CI steps, Terraform, Ansible playbooks, Dockerfiles, scripts)
- Generated text (documentation, SECURITY.md write-ups, README sections)
- Explanations you then applied ("explain how Trivy flags work" → used to write
  the rationale in SECURITY.md)
- Debugging help ("my Trivy step exits 1, why?" → applied the fix)

You do **not** need to record general background questions where you did not use
the output directly in the project.
## Team Sections

### Olubanjo Kolapo — Repo & Security

# AI Use Annex — DevSecOps Security Scanning (CI)

## Summary of AI use

Claude was used as a pair-programming assistant to help draft and troubleshoot
the GitHub Actions configuration for three security scanners. I directed the
work end to end: I set the goals, made the engineering and risk decisions,
reviewed every change before it was committed, ran and verified each pipeline
run, diagnosed the failures with real scan output, and integrated the result
into the shared repository through branches and pull requests. Claude generated
draft YAML and explained trade-offs; the decisions, verification, and
integration were mine.

## Prompts, outputs, and how I used/modified them

| # | What I asked for | What Claude produced | What I did with it (review / decision / change) |
|---|---|---|---|
| 1 | Explain the task and plan the branch strategy and steps | A phased plan; flagged that I had to branch from `main` (not my stale branch) because the Dockerfile/Terraform lived there | I verified this against the repo myself and chose the branch accordingly |
| 2 | Add dependency scanning (npm audit) to CI | A dedicated `dependency-scan` job with a non-blocking report step and a gating `--audit-level=high` step | I reviewed the severity choice, agreed `high` was the right gate for the team, and ran `npm audit` locally to confirm the findings |
| 3 | Add container image scanning (Trivy) | A Trivy step inside the Docker build job, pinned to a fixed action version, gating on CRITICAL/HIGH | I confirmed the action version, decided the placement, and validated it on a real pipeline run |
| 4 | Diagnose the failing checks | Identified base-image CVEs in bundled `tar`, and (after an advisory-DB update) two HIGH devDependency advisories | I supplied the real CI logs, decided the remediation strategy, and chose fix-vs-accept per finding |
| 5 | Remediate the findings | Ran `npm audit fix` for the fixable dependency issues; switched the container scan to report-and-document for unfixable base-image CVEs | I decided to *fix* what we own and *accept/document* what we don't; I re-ran lint and tests to confirm nothing broke |
| 6 | Add the third scan (Checkov for Terraform) | A report-only `iac-scan` job scoped to `terraform/` | I reviewed the Terraform first, decided report-mode was correct since infra is a teammate's area, and coordinated accordingly |

## My own contributions and changes

- **Set the direction and scope**, including the decision to add the third
  (IaC) scan to reach the higher marking band.
- **Made the risk decisions**: gate dependencies hard at `high`; fix the
  fixable advisories via `npm audit fix`; run the container and IaC scans in
  report-and-document mode because those findings sit in a base image and in
  a teammate's Terraform that we don't unilaterally change.
- **Verified everything on real runs**: I ran `npm audit`, lint, and the test
  suite locally, and watched each check on the pull requests rather than
  trusting the config blindly.
- **Debugged a live failure** when the npm advisory database re-rated two
  packages to HIGH mid-task, and drove it to a green pipeline.
- **Handled all version control and integration myself**: created the
  branches, made commits (including my own edits such as the README update),
  pushed, opened the pull requests, and coordinated review and merge with
  teammates.
- **Reviewed and approved every AI-drafted change** before it entered the
  repository; nothing was committed without my check.

## Verification

All three scanners are merged to `main` and run on every pull request. I
confirmed the pipeline is green and that findings are captured for SECURITY.md.


---

### Sydney Wamalwa — Core Transaction Logic

<!-- Paste your interaction blocks here -->

#### Interaction 1

**Prompt given to Claude:**
> Write the docker-compose.yml (one-command launch for MoMoSim, in-memory app so
> likely a single service) and the CI pipeline (.github/workflows/ci.yml): run on
> push to every branch except main, and on PRs targeting main; checkout → set up
> Node → install deps → lint → test → build the Docker image. Fail loudly on any
> step failure.

**Output received:**
A `momosim/Dockerfile` (node:20-alpine, cached `npm ci` layer, non-root `USER
node`), a root-level `docker-compose.yml` (single `momosim` service, port 3000),
an ESLint flat config (`momosim/eslint.config.js`) plus a `lint` script added to
`package.json` so the CI lint step had something real to run, and an updated
`.github/workflows/ci.yml` with `push.branches-ignore: [main]` +
`pull_request.branches: [main]` triggers, a lint → test (Node 20.x/22.x matrix)
job, and a second `docker-build` job that builds the image and curl-checks
`/api/accounts` inside a running container.

**Changes made before using:**
Ran `npm run lint` and `npm test` locally and fixed two ESLint errors the
generated config caught in `tests/transactionService.test.js` (empty
`catch (_) {}` blocks used intentionally to assert no state change) by adding
`allowEmptyCatch` and an ignore pattern for `_`, rather than changing the test
file. Verified the full stack end-to-end with `docker compose up --build` and
confirmed `/api/accounts` returned the seeded accounts from inside the
container. Changed the original CI suggestion of a Node 18.x/20.x matrix to
20.x/22.x after finding ESLint 10 no longer supports Node 18 (EOL since April
2025).

**Where it appears in the project:**
`momosim/Dockerfile`, `docker-compose.yml`, `momosim/eslint.config.js`,
`momosim/package.json` (lint script), `.github/workflows/ci.yml`.

---

### Adepoju Kolade — Accounts & Data Layer

### Interaction 1

**Prompt given to Claude:**
> I need to add missing outputs to terraform/outputs.tf 

**Output received:**
5 new output blocks referencing module.compute.public_dns, module.compute.private_ip, module.network.vpc_cidr, var.aws_region, and var.environment.

**Changes made before using:**
Used as-is.

**Where it appears in the project:**
`terraform/outputs.tf` — lines 46–69


### Interaction 2

**Prompt given to Claude:**
> Add a variables reference table and outputs reference table to terraform/README.md.

**Output received:**
Two markdown tables — one listing all 12 variables with name, type, default, required, and description columns; one listing all 13 outputs with name, description, and typical use columns.

**Changes made before using:**
Inserted before the "Tearing it down" section.

**Where it appears in the project:**
`terraform/README.md` — Variables reference and Outputs reference sections.

---

### Adebayo Seyi — Project Planning / Board

#### Interaction 1

**Prompt given to Claude:**
> Write SECURITY.md documenting two security scanners (npm audit and Trivy) added
> to the CI pipeline, with exact CVEs, what was fixed, and what was accepted as
> documented risk. [Full facts provided in prompt.]

**Output received:**
Complete SECURITY.md covering: intro, scanner 1 (npm audit — findings fixed via
`npm audit fix`), scanner 2 (Trivy — CVE-2026-29786 and CVE-2026-31802 accepted),
and an accepted-risks summary table.

**Changes made before using:**
Reviewed for accuracy against the actual CI config and scan output. Adjusted
wording in the "not reachable at runtime" rationale to match the team's specific
deployment setup.

**Where it appears in the project:**
`SECURITY.md` — root of repo.

#### Interaction 2

**Prompt given to Claude:**
> Write a Docker Compose instructions section for README.md. Only update the
> README — do not create any other files.

**Output received:**
A "Running with Docker Compose" section with steps to clone, run, stop, and
detach the service.

**Changes made before using:**
Used as-is; section was appended to the existing README under Getting Started.

**Where it appears in the project:**
`README.md` — Running with Docker Compose section.

---

### Ofomi Hephzibah — Documentation & Split-Bill Feature

#### Interaction 1

**Prompt given to Claude:**
> What is the standard structure for an Ansible project README? Give me a blank 
> markdown template with standard headings for prerequisites, inventory setup, 
> and execution commands.

**Output received:**
A markdown template with standard headings and generic placeholder text for 
Ansible documentation.

**Changes made before using:**
I used the structural headings but completely replaced the placeholder text to 
write the specific instructions for our MoMoSim project. I manually documented 
our exact `ansible-playbook` commands, the necessary Terraform outputs required 
for the inventory, and the specific `curl` command to verify our deployment.

**Where it appears in the project:**
`ansible/README.md` — Ansible usage instructions.

---

## Notes for graders

- AI was used as a writing and code-generation aid. All outputs were reviewed,
  tested, and adapted by the named team member before being committed.
- The factual content in SECURITY.md (CVE IDs, advisory IDs, scan dates, test
  counts) came from actual tool output, not from Claude.
- No AI tool was used to write or run tests on behalf of the team.
