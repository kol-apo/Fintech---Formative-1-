output "endpoint" {
  description = "Connection endpoint in host:port form"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "DNS hostname of the database instance"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "Port the database listens on"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.main.db_name
}
