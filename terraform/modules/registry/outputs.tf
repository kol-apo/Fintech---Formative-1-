output "repository_url" {
  description = "Full URL of the repository — what docker tag/push/pull use"
  value       = aws_ecr_repository.app.repository_url
}

output "repository_arn" {
  description = "ARN of the repository — used to scope the app server's pull policy"
  value       = aws_ecr_repository.app.arn
}

output "repository_name" {
  description = "Name of the repository"
  value       = aws_ecr_repository.app.name
}
