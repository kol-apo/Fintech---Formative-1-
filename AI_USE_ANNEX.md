# AI Use Annex — MoMoSim Formative 3

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
