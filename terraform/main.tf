# =============================================================================
# Root module — wires the child modules together.
#
#   network   → VPC, public/private subnets, IGW, routing
#   security  → one security group per tier (bastion, app, database)
#   registry  → private container registry (ECR)
#   iam       → instance role that may pull from that one registry
#   compute   → EC2 instances (instantiated twice: app server + bastion)
#   database  → managed PostgreSQL (RDS) in the private subnets
#
# The whole environment fits the AWS free tier: instead of a NAT gateway and
# a load balancer (~$55/month together), the BASTION does both jobs via
# iptables (see templates/bastion-init.sh.tpl).
#
# Traffic paths this creates:
#   users   → bastion :80 (public) ──forwarded──▶ app server (private, :3000)
#   team    → bastion :22 ──▶ app server :22 (Ansible/SSH ProxyJump)
#   app     → RDS :5432 (private subnets)
#   app     → internet (apt, ECR pulls) ──NAT'd through the bastion──▶
#   CD      → pushes image to ECR; app server pulls it via its IAM role
#
# Each module only receives the values it needs, and Terraform derives the
# correct creation order from the output references between them.
# =============================================================================

locals {
  # Single place to build the "momosim-dev" style prefix used in resource names
  name_prefix = "${var.project_name}-${var.environment}"

  # The private key sits next to the public key, minus the .pub suffix —
  # derived here so the SSH/Ansible outputs never hardcode a path
  ssh_private_key_path = trimsuffix(var.ssh_public_key_path, ".pub")
}

module "network" {
  source = "./modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  app_port          = var.app_port
  public_http_port  = var.public_http_port
  db_port           = var.db_port
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
}

module "registry" {
  source = "./modules/registry"

  # ECR repository names must be lowercase
  repository_name = lower(local.name_prefix)
}

module "iam" {
  source = "./modules/iam"

  name_prefix        = local.name_prefix
  ecr_repository_arn = module.registry.repository_arn
}

# Upload the operator's public key so Ansible/SSH can authenticate.
# Created once here and shared by both instances — only the PUBLIC half
# ever leaves the operator's machine.
resource "aws_key_pair" "main" {
  key_name   = "${local.name_prefix}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# The application server: private subnet, no public IP. Reached by users
# and operators only through the bastion.
module "app_server" {
  source = "./modules/compute"

  name_prefix          = local.name_prefix
  server_role          = "app-server"
  subnet_id            = module.network.private_subnet_ids[0]
  security_group_ids   = [module.security.app_security_group_id]
  instance_type        = var.instance_type
  key_name             = aws_key_pair.main.key_name
  associate_public_ip  = false
  iam_instance_profile = module.iam.instance_profile_name
}

# The bastion: SSH entry point, NAT for the private subnets, and public HTTP
# front door. Its first-boot script sets up the iptables forwarding; nothing
# else runs on it. source_dest_check must be off for the NAT role.
module "bastion" {
  source = "./modules/compute"

  name_prefix         = local.name_prefix
  server_role         = "bastion"
  subnet_id           = module.network.public_subnet_ids[0]
  security_group_ids  = [module.security.bastion_security_group_id]
  instance_type       = var.bastion_instance_type
  key_name            = aws_key_pair.main.key_name
  associate_public_ip = true
  source_dest_check   = false

  user_data = templatefile("${path.module}/templates/bastion-init.sh.tpl", {
    vpc_cidr         = var.vpc_cidr
    app_private_ip   = module.app_server.private_ip
    app_port         = var.app_port
    public_http_port = var.public_http_port
  })
}

# The private subnets' road to the internet: default route → bastion ENI.
# Lives here (not in the network module) because the bastion doesn't exist
# yet when the network module runs — this reference is what sequences it.
resource "aws_route" "private_nat" {
  route_table_id         = module.network.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.bastion.primary_network_interface_id
}

module "database" {
  source = "./modules/database"

  name_prefix        = local.name_prefix
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.security.db_security_group_id]
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  db_port            = var.db_port
  engine_version     = var.db_engine_version
  instance_class     = var.db_instance_class
}
