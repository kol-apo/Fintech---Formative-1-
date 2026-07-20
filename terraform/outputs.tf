# =============================================================================
# Root outputs — the values a human (or Ansible) needs after `terraform apply`.
# Read them any time with `terraform output` (add -raw for scripting).
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.network.public_subnet_id
}

output "security_group_id" {
  description = "ID of the application security group"
  value       = module.security.security_group_id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.compute.instance_id
}

output "instance_public_ip" {
  description = "Public IP of the application server — feed this to the Ansible inventory"
  value       = module.compute.public_ip
}

output "app_url" {
  description = "URL where MoMoSim will answer once Ansible has deployed it"
  value       = "http://${module.compute.public_ip}:${var.app_port}"
}

output "ssh_command" {
  description = "Ready-made SSH command for the instance"
  value       = "ssh -i ${local.ssh_private_key_path} ubuntu@${module.compute.public_ip}"
}

output "ansible_inventory_line" {
  description = "Line to paste into ansible/inventory.ini"
  value       = "${module.compute.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${local.ssh_private_key_path}"
}

output "instance_public_dns" {
  description = "Public DNS hostname of the instance (use instead of IP for stable references)"
  value       = module.compute.public_dns
}

output "instance_private_ip" {
  description = "Private IP of the instance inside the VPC"
  value       = module.compute.private_ip
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.network.vpc_cidr
}

output "region" {
  description = "AWS region the infrastructure was provisioned in"
  value       = var.aws_region
}

output "environment" {
  description = "Deployment environment (dev / staging / prod)"
  value       = var.environment
}
