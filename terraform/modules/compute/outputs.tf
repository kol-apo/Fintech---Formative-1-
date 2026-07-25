output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the instance (empty for private instances)"
  value       = aws_instance.this.public_ip
}

output "public_dns" {
  description = "Public DNS name of the instance (empty for private instances)"
  value       = aws_instance.this.public_dns
}

output "private_ip" {
  description = "Private IP address inside the VPC"
  value       = aws_instance.this.private_ip
}

output "primary_network_interface_id" {
  description = "ID of the primary ENI — the private route table's NAT route points here (bastion only)"
  value       = aws_instance.this.primary_network_interface_id
}
