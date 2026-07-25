# =============================================================================
# Root outputs — the values a human (or Ansible, or the CD pipeline) needs
# after `terraform apply`. Read them any time with `terraform output`
# (add -raw for scripting).
# =============================================================================

# --- The headline: where the app answers -------------------------------------

output "app_url" {
  description = "Public URL of the application (the bastion forwards this to the app server)"
  value       = "http://${module.bastion.public_ip}${var.public_http_port == 80 ? "" : ":${var.public_http_port}"}"
}

# --- Access (SSH goes through the bastion) -----------------------------------

output "bastion_public_ip" {
  description = "Public IP of the bastion — SSH entry point, public URL host, and the private tier's outbound IP"
  value       = module.bastion.public_ip
}

output "app_private_ip" {
  description = "Private IP of the app server — reachable only via the bastion"
  value       = module.app_server.private_ip
}

output "ssh_bastion_command" {
  description = "SSH to the bastion itself"
  value       = "ssh -i ${local.ssh_private_key_path} ubuntu@${module.bastion.public_ip}"
}

output "ssh_app_command" {
  description = "SSH to the app server, jumping through the bastion (-J)"
  value       = "ssh -i ${local.ssh_private_key_path} -J ubuntu@${module.bastion.public_ip} ubuntu@${module.app_server.private_ip}"
}

# ProxyCommand rather than the shorter ProxyJump: -J does not reliably pass
# the identity file to the jump hop on every OpenSSH build (verified failing
# on Windows), while an explicit ProxyCommand with its own -i always works.
output "ansible_inventory_snippet" {
  description = "Lines to paste into ansible/inventory.ini — app host reached via the bastion as a jump host"
  value       = <<-EOT
    [momosim]
    ${module.app_server.private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${local.ssh_private_key_path} ansible_ssh_common_args='-o ProxyCommand="ssh -i ${local.ssh_private_key_path} -W %h:%p -o StrictHostKeyChecking=accept-new ubuntu@${module.bastion.public_ip}"'
  EOT
}

# --- Registry (CD pushes here, the app server pulls from here) ---------------

output "ecr_repository_url" {
  description = "URL of the private container registry — docker tag/push/pull target"
  value       = module.registry.repository_url
}

output "ecr_login_command" {
  description = "Log Docker in to the registry (on the app server this uses the instance role — no stored credentials)"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.registry.repository_url}"
}

# --- Database ----------------------------------------------------------------

output "db_endpoint" {
  description = "RDS connection endpoint (host:port) — only resolvable/reachable from inside the VPC"
  value       = module.database.endpoint
}

output "db_name" {
  description = "Name of the initial database"
  value       = module.database.db_name
}

# --- IDs for cross-stack references and debugging ----------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (bastion)"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (app server + database)"
  value       = module.network.private_subnet_ids
}

output "app_instance_id" {
  description = "ID of the app server EC2 instance"
  value       = module.app_server.instance_id
}

output "bastion_instance_id" {
  description = "ID of the bastion EC2 instance"
  value       = module.bastion.instance_id
}

output "region" {
  description = "AWS region the infrastructure was provisioned in"
  value       = var.aws_region
}

output "environment" {
  description = "Deployment environment (dev / staging / prod)"
  value       = var.environment
}
