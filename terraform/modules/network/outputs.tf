output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (bastion)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (app server + database)"
  value       = aws_subnet.private[*].id
}

output "private_route_table_id" {
  description = "ID of the private route table — the root module adds the NAT route to it"
  value       = aws_route_table.private.id
}
