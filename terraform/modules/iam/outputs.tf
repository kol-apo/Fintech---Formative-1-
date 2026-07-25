output "instance_profile_name" {
  description = "Name of the instance profile to attach to the app server"
  value       = aws_iam_instance_profile.app.name
}

output "role_arn" {
  description = "ARN of the app server role"
  value       = aws_iam_role.app.arn
}
