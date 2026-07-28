# Changelog — MoMoSim / Amani Market Systems

Documents the evolution of the system across all four assignment milestones.
Most-recent milestone first.

---

## [Summative] — 2026-07-21 → 2026-07-27

### CD pipeline and live AWS deployment

The Summative extended Formative 3's infrastructure to a full Git-to-production
pipeline with a live, publicly accessible deployment.

#### Added

**CD pipeline** (`cd.yml`):
- Triggered automatically on every merge/push to `main`; branches and PRs run CI only
- **Stage 1 — CI gate:** re-runs the full CI pipeline as a reusable workflow (lint,
  tests on Node 20 + 22, npm audit gate, Docker build + Trivy scan, Checkov, smoke test);
  deploy is blocked if any step fails
- **Stage 2 — Push:** builds the image and pushes two tags to ECR —
  `:<commit-sha>` (permanent, immutable) and `:latest` (rolling pointer)
- **Stage 3 — Deploy:** temporarily authorises the GitHub Actions runner's IP on the
  bastion's security group → writes a dedicated deploy key and ProxyCommand inventory
  (runner → bastion → app server via SSH) → runs the Ansible playbook with the new
  `image_uri` → **always** revokes the SG rule on success or failure
- Concurrency group (`group: production`) prevents two deploys racing the same VM

**Expanded Terraform infrastructure:**
- **Bastion host** (EC2 t3.micro, public subnet) doing triple duty:
  SSH jump host + NAT gateway (replaces ~$35/month managed NAT) + public HTTP
  proxy (replaces ~$20/month load balancer) via iptables DNAT `:80` → app `:3000`
- **App server** moved to a private subnet — no public IP; reachable only through
  the bastion
- **Amazon RDS PostgreSQL 16** (`db.t3.micro`, 20 GB encrypted, single-AZ, private
  subnets) — provisioned and reachable from the app server; not publicly accessible
- **Amazon ECR** private repository `momosim-dev`
  (`020262235992.dkr.ecr.eu-west-1.amazonaws.com/momosim-dev`) — scan-on-push
  enabled, lifecycle policy retains the 10 newest images
- **IAM module** — scoped instance profile granting the app server least-privilege
  ECR pull access; no registry credentials stored anywhere
- **`templates/bastion-init.sh.tpl`** — Terraform-rendered first-boot script; sets
  up `ip_forward`, iptables NAT and DNAT rules, persists them with
  `iptables-persistent`
- Live application accessible at **http://34.242.44.65**

---

## [F3] — 2026-07-09 → 2026-07-21

### Infrastructure as Code, configuration management, and security scanning

#### Added

**Terraform** (initial IaC):
- `modules/network` — VPC 10.0.0.0/16, 2 public + 2 private subnets across 2 AZs,
  Internet Gateway, route tables
- `modules/compute` — reusable EC2 module (parametrised for both app server and
  bastion roles)
- `modules/security` — one security group per tier: bastion, app server, database
- `terraform.tfvars.example` and `secrets.auto.tfvars.example` — safe templates with
  no real values; real credentials are gitignored

**Ansible** (`ansible/playbook.yml`):
- Installs Docker and Docker Compose on the app server via SSH
- Clones the repository and runs `docker compose up -d --build`
- Configures UFW — allows ports 22 and 3000 only, default-deny everything else
- Hardens SSH — disables root login and password authentication
- `group_vars/all.yml` — team SSH public keys managed in version control; access
  is granted or revoked by editing this file and re-running the playbook

**CI security scanning** (added to `ci.yml`):
- `dependency-scan` job — `npm audit --audit-level=high --omit=dev` gates merges
  on HIGH or CRITICAL vulnerabilities in production dependencies; all-severities
  audit printed for visibility on every run
- Trivy image scan step — scans the built Docker image for OS and library CVEs
  (CRITICAL/HIGH only, unfixed suppressed); set to report, not block (base-image
  findings with no available patch)
- `iac-scan` job — Checkov static analysis of `terraform/` on every PR; soft-fail
  so findings surface for review without blocking teammates

**Documentation:**
- `SECURITY.md` — scanner findings, fixes applied, and accepted-risk rationale
- `AI_USE_ANNEX.md` — AI usage log for the whole team

#### Fixed
- `brace-expansion` upgraded via `npm audit fix` (HIGH, GHSA-3jxr-9vmj-r5cp)
- `js-yaml` upgraded via `npm audit fix` (HIGH, GHSA-h67p-54hq-rp68 +
  GHSA-52cp-r559-cp3m); re-scan confirmed 0 vulnerabilities in production deps

---

## [F2] — 2026-07-02 → 2026-07-04

### Containerisation and CI pipeline

#### Added

- **`momosim/Dockerfile`** — Node 18 Alpine image; production dependencies only
  (`npm ci --omit=dev`); non-root user
- **`docker-compose.yml`** (repo root) — single-command local setup, maps host `:3000`
- **`momosim/.dockerignore`** — excludes `node_modules`, coverage output, and test
  files from the build context
- **`.github/workflows/ci.yml`** — CI pipeline triggered on every PR targeting `main`
  and on every branch push except `main`:
  - `lint-and-test` job — ESLint + Jest matrix across Node 20 and Node 22; uploads
    Jest coverage report as a downloadable artifact (7-day retention)
  - `docker-build` job — builds the image, smoke-tests it with
    `curl --fail /api/accounts`, confirms the container starts clean
- **Root `.gitignore`** — prevents `node_modules/` from being committed at the repo root
- Docker Compose setup instructions added to README

---

## [F1] — 2026-06-24 → 2026-06-26

### Planning and initial application

#### Added

- **Project setup** — GitHub repository, Project board, task sheet, team roles
  assigned (Kolapo: repo/security; Sydney: transaction logic; Kolade: accounts/data;
  Seyi: planning/docs; Hephzibah: split-bill/docs)
- **`momosim/` REST API** (Node.js + Express):
  - `GET /api/accounts` — list all accounts and balances
  - `POST /api/transfer` — validated, atomic debit/credit between two accounts
  - `POST /api/split` — divide a total amount equally across multiple recipients
    in one request; remainder distributed one unit at a time to avoid floating-point drift
  - `GET /api/transactions` — full ledger with unique `TXN-` references and timestamps
- **In-memory data store** (`data/store.js`) — plain JS objects; no database
  dependency at this stage
- **`services/transactionService.js`** — transfer and splitBill with all-or-nothing
  validation: no balance is touched if any check fails
- **`services/accountService.js`** — getAccount, getAllAccounts, adjustBalance
- **Jest test suite** — 33 tests covering success paths, edge cases (zero/negative
  amounts, unknown accounts, insufficient funds, uneven split remainder distribution),
  and atomicity guarantees
- **ESLint** configuration
- **MIT License**
- **Initial README** — project overview, African context, team, API usage examples
