# =============================================================================
# Root module — wires the three child modules together.
#
#   network  → VPC, public subnet, internet gateway, routing
#   security → security group (the firewall in front of the instance)
#   compute  → EC2 instance + SSH key pair
#
# Each module only receives the values it needs, and the compute module
# consumes outputs from the other two — Terraform derives the correct
# creation order from these references automatically.
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

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
}

module "security" {
  source = "./modules/security"

  name_prefix      = local.name_prefix
  vpc_id           = module.network.vpc_id
  app_port         = var.app_port
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "compute" {
  source = "./modules/compute"

  name_prefix         = local.name_prefix
  subnet_id           = module.network.public_subnet_id
  security_group_ids  = [module.security.security_group_id]
  instance_type       = var.instance_type
  ssh_public_key_path = var.ssh_public_key_path
}
