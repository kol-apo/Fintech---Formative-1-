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

---

## How to fill in your section

Copy the template block below, paste it into your section, and complete it.
One block per distinct AI interaction (per prompt/response pair that produced
something you used).

```
### Interaction N

**Prompt given to Claude:**
> Paste your exact prompt here (or paraphrase if very long — keep it accurate).

**Output received:**
Summarise what Claude produced. If it was code, paste the key lines or a short
excerpt. If it was text, note the main content.

**Changes made before using:**
Describe what you edited, rewrote, or decided not to use, and why. If you used
it unchanged, write "Used as-is."

**Where it appears in the project:**
File path and brief description (e.g. `.github/workflows/ci.yml` — Trivy scan step).
```

---

## Team Sections

### Olubanjo Kolapo — Repo & Security

<!-- Paste your interaction blocks here -->

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

<!-- Paste your interaction blocks here -->

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

<!-- Paste your interaction blocks here -->

---

## Notes for graders

- AI was used as a writing and code-generation aid. All outputs were reviewed,
  tested, and adapted by the named team member before being committed.
- The factual content in SECURITY.md (CVE IDs, advisory IDs, scan dates, test
  counts) came from actual tool output, not from Claude.
- No AI tool was used to write or run tests on behalf of the team.
