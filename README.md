# MoMoSim — Amani Market Systems

> A Node.js mobile-money payment simulator deployed on AWS through a fully automated Git-to-production pipeline.

## Live Application

**http://34.242.44.65**

Traffic hits the bastion's public IP on port 80 and is forwarded by iptables to the app server's private IP on port 3000. The IP changes if the bastion is ever rebuilt — always check the source of truth:

```bash
terraform -chdir=terraform output -raw app_url
```

---

## The Problem It Solves

Across Africa, mobile money services like MTN MoMo and Airtel Money are the dominant payment rail, serving millions who are unbanked or far from physical banks. Developers and students lack a safe, free environment to model and test how these transactions behave under real conditions.

Amani Market Systems' MoMoSim replicates the core logic of a mobile money transfer — account lookup, balance validation, atomic debit/credit, transaction logging, and split-bill distribution — without touching real money or telecom infrastructure. The goal is a realistic testbed for fintech developers prototyping payment flows before integrating a live provider.

---

## Team

| Name | Role |
|---|---|
| Olubanjo Kolapo | Repo lead & security |
| Sydney Wamalwa | Core transaction logic & infrastructure |
| Adepoju Kolade | Accounts & data layer |
| Adebayo Seyi | Project planning, documentation |
| Ofomi Hephzibah | Split-bill feature & deployment |

---

## Architecture

> Save the diagram as **`docs/architecture.drawio`** so it renders in the VS Code Draw.io extension and is tracked in the repo. For a full guide on what to draw and how to connect everything, see the [Architecture Diagram Guide](#architecture-diagram-guide) at the end of this file.

### Infrastructure overview

```
Internet
    │  :80
    ▼
┌──────────────────────────────────────────────────────────────────┐
│  AWS VPC  10.0.0.0/16  ·  eu-west-1 (Ireland)                   │
│                                                                  │
│  ┌─── Public Subnets (AZ-a 10.0.1.0/24, AZ-b 10.0.2.0/24) ───┐ │
│  │                                                             │ │
│  │   Bastion Host  (EC2 t3.micro · Ubuntu 22.04)              │ │
│  │   ① SSH jump host — team reaches private VMs via ProxyJump │ │
│  │   ② NAT — private subnet's outbound traffic masquerades    │ │
│  │      through this ENI instead of a $35/mo NAT gateway      │ │
│  │   ③ Public front door — iptables DNAT :80 → app :3000      │ │
│  │      (replaces a $20/mo load balancer)                     │ │
│  │                                                             │ │
│  └─────────────────────────────────────────────────────────────┘ │
│           │ :3000 (DNAT)              │ NAT (MASQUERADE)         │
│           ▼                           ▼                          │
│  ┌─── Private Subnets (AZ-a 10.0.11.0/24, AZ-b 10.0.12.0/24) ┐ │
│  │                                                             │ │
│  │   App Server  (EC2 t3.micro · Ubuntu 22.04)                │ │
│  │   • No public IP — reachable only via bastion              │ │
│  │   • Runs Docker container: node server.js (port 3000)      │ │
│  │   • IAM instance role → pulls images from ECR              │ │
│  │                                                             │ │
│  │   RDS PostgreSQL 16  (db.t3.micro · 20 GB encrypted)       │ │
│  │   • Private subnets only — not publicly accessible         │ │
│  │   • Port 5432, reachable from app server SG + bastion SG   │ │
│  │                                                             │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│   Amazon ECR  (private)                                          │
│   020262235992.dkr.ecr.eu-west-1.amazonaws.com/momosim-dev      │
│   • Scan-on-push enabled · lifecycle: keep 10 newest images     │
│   • App server pulls using IAM role — no stored credentials     │
└──────────────────────────────────────────────────────────────────┘

GitHub Actions
  CI  (every PR)   → lint · test · npm audit · docker build · Trivy · Checkov · smoke test
  CD  (merge/main) → CI gate → push :sha + :latest to ECR → Ansible deploy via bastion
```

### Traffic paths

| Path | Detail |
|---|---|
| User → app | Bastion `:80` → iptables DNAT → app server `:3000` |
| Team SSH | `ssh -J ubuntu@<bastion> ubuntu@<app-server>` (ProxyJump) |
| App → database | Private DNS, port 5432; SG allows app SG only |
| App → internet (outbound) | iptables MASQUERADE on bastion (NAT) |
| CD → ECR | GitHub Actions pushes `:<sha>` and `:latest` on merge to main |
| CD → app server | Runner gets temp SG rule → Ansible via SSH ProxyCommand → runs playbook → SG rule always revoked |

### Security groups

| Group | Inbound allowed |
|---|---|
| Bastion | `:22` from team IPs; `:80` from `0.0.0.0/0`; `:22` temp from GitHub runner (CD only, always revoked) |
| App server | `:3000` from bastion SG; `:22` from bastion SG only |
| Database | `:5432` from app server SG; `:5432` from bastion SG (SSH-tunnel debugging/migrations) |

### Cost trade-offs

The bastion's triple role was a deliberate architectural decision. A managed NAT Gateway costs ~$35/month and an Application Load Balancer ~$20/month on the AWS pricing for eu-west-1 — a combined $55/month that the team's credit-based account could not sustain. Using the bastion's existing ENI for iptables NAT and DNAT achieves the same network topology at zero additional cost, at the trade-off of a single point of failure for both public access and outbound routing. Acceptable for a development environment.

---

## Technology Stack

| Layer | Technology |
|---|---|
| Application | Node.js 20, Express 5 |
| Containerisation | Docker, Docker Compose |
| Cloud | AWS eu-west-1 |
| Compute | EC2 t3.micro × 2 (bastion + app server), Ubuntu 22.04 LTS |
| Database | Amazon RDS PostgreSQL 16, db.t3.micro, 20 GB encrypted storage |
| Container registry | Amazon ECR — `momosim-dev`, private, scan-on-push |
| Networking | VPC 10.0.0.0/16, 2 public + 2 private subnets across 2 AZs, iptables NAT/DNAT |
| IaC | Terraform (modular: network, compute, security, database, registry, IAM) |
| Configuration management | Ansible |
| CI/CD | GitHub Actions (`ci.yml` + `cd.yml`) |
| Security scanning | npm audit (dependency gate), Trivy (container image), Checkov (IaC) |
| Testing | Jest 29 — 33 tests with coverage |
| Linting | ESLint |

---

## Getting Started

### Run locally — Node

```bash
git clone https://github.com/kol-apo/Fintech---Formative-1-.git
cd Fintech---Formative-1-/momosim
npm install
node server.js
# http://localhost:3000
```

### Run locally — Docker Compose

```bash
git clone https://github.com/kol-apo/Fintech---Formative-1-.git
cd Fintech---Formative-1-
docker compose up -d
# http://localhost:3000
docker compose down   # stop
```

### Deploy to AWS — full engineer walkthrough

**Prerequisites:** Terraform ≥ 1.5, Ansible, AWS CLI configured, SSH key pair at `~/.ssh/momosim`.

#### Step 1 — Provision infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Fill in: aws_region, ssh_allowed_cidrs (your IP), ssh_public_key_path
cp secrets.auto.tfvars.example secrets.auto.tfvars
# Fill in: aws_access_key, aws_secret_key, db_password (min 12 chars)

terraform init
terraform plan
terraform apply
```

Capture the outputs you'll need:

```bash
terraform output app_url                   # live URL
terraform output bastion_public_ip         # bastion IP
terraform output ansible_inventory_snippet # paste into ansible/inventory.ini
terraform output ecr_repository_url        # 020262235992.dkr.ecr.eu-west-1.amazonaws.com/momosim-dev
```

#### Step 2 — Configure and deploy with Ansible

```bash
# Paste ansible_inventory_snippet into ansible/inventory.ini
cd ansible
ansible-playbook -i inventory.ini playbook.yml \
  --extra-vars "image_uri=020262235992.dkr.ecr.eu-west-1.amazonaws.com/momosim-dev:latest \
                ecr_repository_url=020262235992.dkr.ecr.eu-west-1.amazonaws.com/momosim-dev \
                db_password=<your-db-password>"
```

The playbook: installs Docker and the AWS CLI, renders a `docker-compose.yml` from a Jinja2 template, logs in to ECR using the instance's IAM credentials, pulls the image, starts the container with `docker compose up -d --remove-orphans`, opens UFW ports 22, 80, and 3000, and hardens SSH (no root login, no password auth).

#### Step 3 — Verify

```bash
curl http://$(terraform -chdir=terraform output -raw bastion_public_ip)/api/accounts
# Expected: JSON array of accounts
```

### How the CD pipeline deploys (automatic)

Every merge to `main` triggers `cd.yml`:

1. **CI gate** — re-runs the full CI pipeline (lint, tests, npm audit, Docker build, Trivy, Checkov, smoke test). Deploy is blocked if any step fails.
2. **Push to ECR** — builds the image, tags it `:<commit-sha>` and `:latest`, pushes to `020262235992.dkr.ecr.eu-west-1.amazonaws.com/momosim-dev`.
3. **Deploy** — temporarily adds the runner's IP to the bastion's security group, writes a deploy key and ProxyCommand inventory (runner → bastion → app server), runs the Ansible playbook with the new `image_uri`, then **always** revokes the SG rule — even if the deploy fails.

A concurrency group (`group: production-deploy`) prevents two deploys from racing the same VM.

---

## API Reference

**Live base URL:** `http://34.242.44.65`
**Local base URL:** `http://localhost:3000`

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/accounts` | List all accounts and balances |
| `GET` | `/api/transactions` | Full transaction history |
| `POST` | `/api/transfer` | Transfer between two accounts |
| `POST` | `/api/split` | Split a total equally across multiple recipients |

**Transfer**
```bash
curl -X POST http://34.242.44.65/api/transfer \
  -H "Content-Type: application/json" \
  -d '{"from": "user_001", "to": "user_002", "amount": 500}'
```

**Split bill**
```bash
curl -X POST http://34.242.44.65/api/split \
  -H "Content-Type: application/json" \
  -d '{"from": "user_001", "recipients": ["user_002","user_003","user_004"], "totalAmount": 300}'
```

---

## Repository Structure

```
Fintech---Formative-1-/
├── .github/workflows/
│   ├── ci.yml          # Lint, test, npm audit, Trivy, Checkov — every PR
│   └── cd.yml          # CI gate + ECR push + Ansible deploy — merge to main
├── momosim/            # Application source
│   ├── data/store.js
│   ├── services/
│   ├── routes/
│   ├── tests/          # Jest, 33 tests
│   ├── server.js
│   └── Dockerfile
├── terraform/          # AWS infrastructure (modular)
│   ├── modules/network, compute, security, database, registry, iam
│   ├── main.tf
│   ├── templates/bastion-init.sh.tpl   # iptables NAT + DNAT rules
│   └── terraform.tfvars.example
├── ansible/
│   ├── playbook.yml    # Docker install, container deploy, SSH hardening
│   ├── inventory.ini
│   └── group_vars/all.yml
├── docker-compose.yml
├── SECURITY.md
├── CHANGELOG.md
└── AI_USE_ANNEX.md
```

---

## Architecture Diagram Guide

Open [draw.io](https://app.diagrams.net/), enable the **AWS shape library** (Extras → Edit Diagram, or Shapes panel → AWS19).

**Canvas layout — four zones:**

| Zone | Contents |
|---|---|
| Top, outside VPC | "Internet / Users" cloud + "GitHub Actions" box |
| Inside VPC, left band | Public subnets rectangle (light blue) containing the Bastion EC2 |
| Inside VPC, right band | Private subnets rectangle (light orange) containing App Server EC2 + RDS icon |
| Right, outside VPC | Amazon ECR box |

**Components to place:**

- Internet cloud (AWS Internet Gateway shape or plain cloud)
- Bastion EC2 — label: *Bastion (t3.micro) · SSH jump · NAT · HTTP proxy*
- App Server EC2 — label: *App Server (t3.micro) · Docker · Node :3000 · no public IP*
- RDS icon — label: *RDS PostgreSQL 16 · db.t3.micro · 20 GB encrypted*
- ECR box — label: *Amazon ECR · momosim-dev · private*
- GitHub Actions box (outside VPC, top-right)
- Team laptop icon (outside VPC, top-left)

**Connections to draw:**

| From | To | Line style | Label |
|---|---|---|---|
| Internet cloud | Bastion | Solid, bold | `:80 HTTP` |
| Bastion | App Server | Solid | `:3000 (iptables DNAT)` |
| App Server | RDS | Solid | `:5432 PostgreSQL` |
| App Server | ECR | Dashed | `docker pull (IAM role)` |
| Bastion | Internet (loop/outbound) | Dashed | `NAT (MASQUERADE)` |
| GitHub Actions | ECR | Dashed | `docker push (:sha, :latest)` |
| GitHub Actions | Bastion | Dashed | `Ansible SSH (temp SG rule)` |
| Bastion | App Server | Dashed | `SSH ProxyCommand` |
| Team laptop | Bastion | Dashed | `SSH :22 (ProxyJump)` |

**Style tips:**
- Solid lines = live user traffic; dashed = deployment/management
- Add a padlock icon on the App Server and RDS to indicate no public IP/access
- Label the bastion with all three roles clearly — graders will look for it
- Add subnet CIDR labels inside each rectangle (10.0.1.0/24, 10.0.11.0/24, etc.)

---

## Links

- [Project Board](https://github.com/kol-apo/Fintech---Formative-1-/projects)
- [Task Sheets](https://docs.google.com/spreadsheets/d/1vvY5NJ8Aj2NM7L4KviNWLulCJvoscEkdLuV4_2ArjZM/edit?usp=sharing)
- [SECURITY.md](./SECURITY.md)
- [CHANGELOG.md](./CHANGELOG.md)
- [AI Use Annex](./AI_USE_ANNEX.md)

## License

MIT License
