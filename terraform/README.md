# MoMoSim — Infrastructure as Code (Terraform)

This directory provisions the complete AWS environment for MoMoSim: a VPC
with public and private subnets, a bastion host, an application server with
no public IP, a managed PostgreSQL database (RDS), and a private container
registry (ECR) — designed for **near-zero cost** on the team's
credits-based free AWS account (see "Costs & credits" below). Terraform stops at
"reachable, empty infrastructure exists" — installing Docker and deploying
the container is handled by the Ansible playbook in
[`../ansible/`](../ansible/), driven by the CD pipeline.

## Architecture

```
                          internet
                             │
              :80 (public)   │   :22 (team IPs only)
                             ▼
                      ┌─────────────┐          VPC 10.0.0.0/16
                      │   bastion   │
                      │  (public    │  three jobs, one t3.micro:
                      │   subnet)   │   1. SSH jump host
                      └──────┬──────┘   2. iptables :80 → app:3000
             :3000 ┌─────────┤ :22     3. NAT for the private subnets
                   ▼         ▼
        ┌──────────────────────────────┐
        │  app server (private subnet) │──outbound (apt, ECR)──▶ via bastion NAT
        │  no public IP, IAM pull role │
        └──────────────┬───────────────┘
                       │ :5432
                       ▼
        ┌──────────────────────────────┐
        │  RDS PostgreSQL (private x2) │
        │  not publicly accessible     │
        └──────────────────────────────┘

        ECR (regional service): CD pushes ──▶ app server pulls via IAM role
```

Traffic rules are strictly tiered: users and operators only ever touch the
bastion, the app server accepts traffic from the bastion alone, and the
database only accepts connections from the app server and the bastion.

**Why no NAT gateway or load balancer?** They'd cost ~$55/month combined —
the two most expensive items in a design like this, and enough to exhaust
the account's credits by themselves. The bastion replaces both with ~15
lines of iptables
([`templates/bastion-init.sh.tpl`](templates/bastion-init.sh.tpl)): a
MASQUERADE rule makes it the private subnets' NAT, and a DNAT rule forwards
its public port 80 to the app server — which is exactly what the assignment's
"public URL via the Bastion Host's IP" option describes. The trade-off is a
single point of failure with no health checks, which is acceptable for a
single-VM coursework deployment and documented as such.

## What gets created

| Resource | Purpose | Cost |
|---|---|---|
| VPC (`10.0.0.0/16`) | Isolated network for the project | free |
| 2 public + 2 private subnets | Bastion tier / app+DB tier (RDS needs 2 AZs) | free |
| Internet gateway, route tables | Inbound for public tier; private routes via bastion | free |
| Bastion host (`t3.micro`) | SSH door, public :80 front door, NAT | ~$0.27/day |
| App server (`t3.micro`, Ubuntu 22.04) | Runs the MoMoSim container; no public IP | ~$0.27/day |
| Public IPv4 (bastion, 1 of) | The public URL / SSH address | ~$0.12/day |
| RDS PostgreSQL 16 (`db.t3.micro`, 20 GB) | Managed database, private subnets only | ~$0.50/day |
| ECR repository | Private registry for CD images | ~free (<1 GB) |
| IAM role + instance profile | Lets the app server pull from exactly our ECR repo | free |
| 3 security groups | One per tier: bastion, app, database | free |
| Key pair | Your SSH public key, shared by both instances | free |

## Costs & credits — read before applying

The team account (created 2026-07-21) is on AWS's **credits-based FREE
plan**: it has **no payment method and cannot be billed** — usage draws down
prepaid credits (~$98 as of 2026-07-25, valid until 2027-01-21), and AWS
suspends resources if they ever run out. So nobody can be surprised with a
bill; the only thing to manage is the credit balance.

The full environment burns **≈ $1.20/day while it exists and $0 when
destroyed** — the credits cover ~80 always-on days, or effectively unlimited
create-for-a-session/destroy-after use. The design keeps the burn low: no
NAT gateway, no load balancer, no Elastic IPs (~$55/month avoided), micro
instances with CPU bursting capped to "standard" so load can never
accelerate the drain. Check the balance any time:

```bash
aws freetier get-account-plan-state --region us-east-1
```

## Layout

```
terraform/
├── main.tf                     # Wires the modules together + bastion NAT route
├── variables.tf                # All tunable inputs (region, CIDRs, ports, DB, ...)
├── outputs.tf                  # URLs, IPs, ready-made SSH/Ansible/ECR commands
├── providers.tf                # AWS provider + default tags
├── versions.tf                 # Terraform/provider version pins
├── terraform.tfvars.example    # Template for your local values
├── secrets.auto.tfvars.example # Template for the gitignored credentials file
├── templates/
│   └── bastion-init.sh.tpl     # Bastion first-boot: NAT + :80 forwarding
└── modules/
    ├── network/                # VPC, subnets, IGW, routing
    ├── security/               # The three security groups + rules
    ├── compute/                # Generic EC2 module (instantiated as app + bastion)
    ├── database/               # RDS instance + subnet group
    ├── registry/               # ECR repository + lifecycle policy
    └── iam/                    # App server's scoped ECR-pull role
```

## Prerequisites

1. **Terraform ≥ 1.5** — `terraform -version`
2. **The team AWS account's credentials and a DB password** in a local,
   gitignored secrets file:

   ```bash
   cd terraform
   cp secrets.auto.tfvars.example secrets.auto.tfvars
   # then fill in the team keys and a db_password (min 12 chars)
   ```

   Terraform loads any `*.auto.tfvars` file automatically, and
   `terraform/.gitignore` ignores all `*.tfvars` files, so real secrets can
   never be committed — only the `.example` template is. The variables are
   marked `sensitive`, so Terraform redacts them from plan output.

   *Alternative for the AWS keys:* use a named profile instead
   (`aws configure --profile momosim-team`) — the provider falls back to
   `var.aws_profile` when no keys are set. `db_password` is always required.
3. **An SSH key pair** for the servers:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/momosim
   ```

## How to run it

```bash
cd terraform

# 1. Create your local variables file (gitignored) and edit it:
#    - ssh_allowed_cidrs → team members' public IPs + /32
#    - ssh_public_key_path, region, instance sizes as needed
cp terraform.tfvars.example terraform.tfvars

# 2. Download providers and initialise the working directory
terraform init

# 3. Sanity checks
terraform fmt -recursive -check
terraform validate

# 4. See exactly what will be created (~34 resources)
terraform plan

# 5. Create the infrastructure (RDS takes ~5-10 minutes)
terraform apply
```

When `apply` finishes, Terraform prints the outputs:

```
app_url                   = "http://<bastion-ip>"
bastion_public_ip         = "<bastion-ip>"
app_private_ip            = "10.0.11.x"
ssh_app_command           = "ssh -i ~/.ssh/momosim -J ubuntu@<bastion-ip> ubuntu@10.0.11.x"
ansible_inventory_snippet = "<ready-made [momosim] section with ProxyJump>"
ecr_repository_url        = "<account>.dkr.ecr.eu-west-1.amazonaws.com/momosim-dev"
db_endpoint               = "momosim-dev-db....rds.amazonaws.com:5432"
```

Copy `ansible_inventory_snippet` into `../ansible/inventory.ini` — the app
server has no public IP, so Ansible reaches it through the bastion with SSH's
`ProxyJump`. Re-print outputs any time with `terraform output` (add `-raw`
for scripting, e.g. `terraform output -raw ecr_repository_url` in CD).

## How the pieces are used downstream

- **CD pipeline** builds the image, logs in to ECR, and pushes
  `$(terraform output -raw ecr_repository_url):latest` + a commit-SHA tag.
- **Ansible** (via the bastion) installs Docker + the AWS CLI, logs the app
  server in to ECR (`ecr_login_command` output — the instance IAM role means
  no registry password exists anywhere), pulls the new image, and restarts
  the service.
- **Users** hit `app_url` — the bastion forwards :80 straight to the app
  server's port 3000.
- **Database**: the app reads the connection details from its environment
  (`db_endpoint`, `db_name`, `db_username` outputs + the password the
  operator supplied). It is reachable from a laptop only through an SSH
  tunnel via the bastion:
  ```bash
  ssh -i ~/.ssh/momosim -L 5432:$(terraform output -raw db_endpoint) ubuntu@$(terraform output -raw bastion_public_ip)
  ```

## Variables reference

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `project_name` | string | `"momosim"` | no | Prefix for all resource names |
| `environment` | string | `"dev"` | no | One of: dev, staging, prod |
| `aws_region` | string | `"eu-west-1"` | no | AWS region to deploy into |
| `aws_profile` | string | `"momosim-team"` | no | Named profile in ~/.aws/credentials |
| `aws_access_key` | string | `null` | no | Team access key (use secrets file) |
| `aws_secret_key` | string | `null` | no | Team secret key (use secrets file) |
| `vpc_cidr` | string | `"10.0.0.0/16"` | no | CIDR block for the VPC |
| `public_subnet_cidrs` | list | `["10.0.1.0/24", "10.0.2.0/24"]` | no | Public subnets |
| `private_subnet_cidrs` | list | `["10.0.11.0/24", "10.0.12.0/24"]` | no | Private subnets (2 AZs) |
| `instance_type` | string | `"t3.micro"` | no | App server instance type |
| `bastion_instance_type` | string | `"t3.micro"` | no | Bastion instance type |
| `app_port` | number | `3000` | no | Port the MoMoSim container listens on |
| `public_http_port` | number | `80` | no | Public port the bastion forwards to the app |
| `ssh_allowed_cidrs` | list | — | **yes** | Team IPs (+ /32) allowed to SSH to the bastion |
| `ssh_public_key_path` | string | `"~/.ssh/momosim.pub"` | no | Path to your SSH public key |
| `db_name` | string | `"momosim"` | no | Initial database name |
| `db_username` | string | `"momosim"` | no | Master username |
| `db_password` | string | — | **yes** | Master password (secrets file, min 12 chars) |
| `db_port` | number | `5432` | no | Database port |
| `db_engine_version` | string | `"16"` | no | PostgreSQL major version |
| `db_instance_class` | string | `"db.t3.micro"` | no | RDS instance class (free-tier eligible) |

## Outputs reference

| Name | Description | Typical use |
|---|---|---|
| `app_url` | Public URL (bastion IP, port 80) | **The** deliverable link |
| `bastion_public_ip` | Bastion's public IP | SSH / Ansible jump host |
| `app_private_ip` | App server's private IP | Ansible inventory |
| `ssh_bastion_command` | Ready-made SSH to bastion | Quick access |
| `ssh_app_command` | SSH to app via `-J` bastion | Quick access |
| `ansible_inventory_snippet` | `[momosim]` section with ProxyJump | Paste into inventory.ini |
| `ecr_repository_url` | Registry URL | CD push target, compose image |
| `ecr_login_command` | Docker login via IAM role | Ansible deploy step |
| `db_endpoint` / `db_name` | Database connection details | App environment |
| `vpc_id`, subnet + instance IDs | Resource IDs | Console / debugging |
| `region`, `environment` | Deployment context | CI scripts / tagging |

## Tearing it down

```bash
terraform destroy
```

Everything (including RDS and ECR with images in it) destroys cleanly —
`skip_final_snapshot` and ECR `force_delete` are set on purpose, because
nothing in this environment holds data worth keeping. Destroy whenever the
environment will sit idle: destroyed infrastructure burns zero credits.

## Design notes

- **Private-by-default compute.** The app server has no public IP; its only
  exposure is the app port and SSH, both exclusively from the bastion.
  Outbound traffic (apt, ECR pulls) leaves through the bastion's NAT.
- **One generic compute module, instantiated twice.** The app server and
  bastion are the same module with different subnet/IP/role wiring — no
  copy-pasted EC2 code. The bastion additionally disables
  `source_dest_check` (an AWS requirement for anything that forwards
  packets) and runs the iptables first-boot script.
- **Cost as a hard constraint.** The team account cannot pay a bill, so the
  design minimizes credit burn: no NAT gateway, no load balancer, no Elastic
  IPs, micro instances with capped CPU bursting, 20 GB RDS. The costed
  alternatives (managed NAT, ALB with health checks, multi-AZ RDS) are the
  obvious production upgrades and are named in SECURITY.md as accepted
  trade-offs rather than oversights.
- **No registry credentials exist.** The app server pulls images with an IAM
  instance role scoped to exactly one ECR repository; CI/CD authenticates
  with its own credentials on the push side.
- **Secrets never touch the repo.** AWS keys and the DB password live in the
  gitignored `secrets.auto.tfvars`, are marked `sensitive`, and RDS storage
  is encrypted at rest (as are both EBS root volumes; IMDSv2 is enforced).
- **State is local and gitignored.** Fine for a single-operator coursework
  flow; a team/production setup would use a remote backend (S3 + DynamoDB
  locking) — noted as a known limitation.
