# MoMoSim — Infrastructure as Code (Terraform)

This directory provisions everything MoMoSim needs to run in AWS: a VPC, a
public subnet with internet routing, a security group, and an Ubuntu EC2
instance. Terraform stops at "a reachable server exists" — installing Docker
and deploying the container is handled by the Ansible playbook in
[`../ansible/`](../ansible/).

## What gets created

| Resource | Purpose |
|---|---|
| VPC (`10.0.0.0/16`) | Isolated network for the project |
| Public subnet (`10.0.1.0/24`) | Where the app server lives |
| Internet gateway + route table | Gives the subnet internet access |
| Security group | Allows SSH (your IP only) and port 3000 (public API) |
| EC2 instance (`t3.micro`, Ubuntu 22.04) | Runs the MoMoSim container |
| Key pair | Your SSH public key, for Ansible/SSH access |

## Layout

```
terraform/
├── main.tf                  # Wires the modules together
├── variables.tf             # All tunable inputs (region, CIDRs, ports, ...)
├── outputs.tf               # IPs, IDs, ready-made SSH/Ansible lines
├── providers.tf             # AWS provider + default tags
├── versions.tf              # Terraform/provider version pins
├── terraform.tfvars.example # Template for your local values
├── secrets.auto.tfvars.example # Template for the gitignored credentials file
└── modules/
    ├── network/             # VPC, subnet, IGW, routing
    ├── security/            # Security group + rules
    └── compute/             # AMI lookup, key pair, EC2 instance
```

## Prerequisites

1. **Terraform ≥ 1.5** — `terraform -version`
2. **The team AWS account's credentials** in a local, gitignored secrets file:

   ```bash
   cd terraform
   cp secrets.auto.tfvars.example secrets.auto.tfvars
   # then paste the TEAM account's access key + secret key into the copy
   ```

   Terraform loads any `*.auto.tfvars` file automatically, and
   `terraform/.gitignore` ignores all `*.tfvars` files, so the real keys can
   never be committed — only the `.example` template is. The variables are
   marked `sensitive`, so Terraform redacts them from plan output.

   *Alternative:* leave the secrets file out and store the keys as a named
   profile instead (`aws configure --profile momosim-team`) — the provider
   falls back to `var.aws_profile` when no keys are set.
3. **An SSH key pair** for the server:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/momosim
   ```

## How to run it

```bash
cd terraform

# 1. Create your local variables file (gitignored) and edit it:
#    - ssh_allowed_cidr  → your public IP + /32 (https://checkip.amazonaws.com)
#    - ssh_public_key_path, region, instance size as needed
cp terraform.tfvars.example terraform.tfvars

# 2. Download providers and initialise the working directory
terraform init

# 3. Sanity checks
terraform fmt -recursive -check
terraform validate

# 4. See exactly what will be created (should be ~9 resources)
terraform plan

# 5. Create the infrastructure
terraform apply
```

When `apply` finishes, Terraform prints the outputs:

```
app_url                = "http://<public-ip>:3000"
instance_public_ip     = "<public-ip>"
ssh_command            = "ssh -i ~/.ssh/momosim ubuntu@<public-ip>"
ansible_inventory_line = "<public-ip> ansible_user=ubuntu ..."
```

Copy `ansible_inventory_line` into `../ansible/inventory.ini`, then run the
playbook to install Docker and deploy the app. Re-print outputs any time with
`terraform output` (or `terraform output -raw instance_public_ip` in scripts).

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
| `public_subnet_cidr` | string | `"10.0.1.0/24"` | no | CIDR for the public subnet |
| `instance_type` | string | `"t3.micro"` | no | EC2 instance type |
| `app_port` | number | `3000` | no | Port the MoMoSim container listens on |
| `ssh_allowed_cidr` | string | — | **yes** | Your IP + /32 — never open to 0.0.0.0/0 |
| `ssh_public_key_path` | string | `"~/.ssh/momosim.pub"` | no | Path to your SSH public key |

## Outputs reference

| Name | Description | Typical use |
|---|---|---|
| `vpc_id` | ID of the VPC | Cross-stack references |
| `public_subnet_id` | ID of the public subnet | Cross-stack references |
| `security_group_id` | ID of the app security group | Cross-stack references |
| `instance_id` | EC2 instance ID | AWS console / debugging |
| `instance_public_ip` | Public IP of the server | Ansible inventory |
| `instance_public_dns` | Public DNS hostname | Stable alternative to IP |
| `instance_private_ip` | Private IP inside the VPC | Internal service calls |
| `vpc_cidr` | VPC CIDR block | Firewall rule references |
| `region` | AWS region deployed into | CI scripts |
| `environment` | dev / staging / prod | CI scripts / tagging |
| `app_url` | Full URL to the running app | Smoke testing |
| `ssh_command` | Ready-made SSH command | Quick server access |
| `ansible_inventory_line` | Line to paste into inventory.ini | Ansible setup |

## Tearing it down

The instance costs money while it exists (t3.micro is free-tier eligible, but
don't rely on it). Destroy everything when you're done:

```bash
terraform destroy
```

## Design notes

- **No hardcoded environment values.** Region, CIDRs, instance type, and ports
  are all variables; the AMI is discovered with a `data` lookup so the code
  works in any region. Secrets never appear anywhere — AWS credentials come
  from the environment and only the SSH *public* key is uploaded.
- **Modular layout.** `network`, `security`, and `compute` are independent
  modules composed by the root; Terraform derives creation order from the
  output references between them.
- **Security defaults.** `ssh_allowed_cidr` has no default on purpose — you
  must consciously choose who can SSH in. The instance enforces IMDSv2 and an
  encrypted root volume, both of which keep the IaC scanners in CI (Part 3)
  quiet.
- **State is local and gitignored.** Fine for a single-operator formative; a
  team/production setup would use a remote backend (S3 + DynamoDB locking).
