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

<!-- Paste your interaction blocks here -->

---

### Sydney Wamalwa — Core Transaction Logic

<!-- Paste your interaction blocks here -->

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
