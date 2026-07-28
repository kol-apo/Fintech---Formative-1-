# =============================================================================
# Database module — managed PostgreSQL on RDS.
#
# The instance lives in the private subnets (subnet group spans two AZs, an
# RDS requirement) and is NOT publicly accessible: the only way in is through
# the db security group, which admits the app server and the bastion.
# The master password arrives via a sensitive variable from the gitignored
# secrets.auto.tfvars — it never appears in the repository.
# =============================================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.name_prefix}-db-subnets"
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-db"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false

  # Cost/scope trade-offs, deliberate for coursework (flagged by Checkov,
  # accepted with rationale — see SECURITY.md):
  #   - single-AZ: multi_az doubles the RDS cost for availability we don't need
  #   - no final snapshot / no deletion protection: the environment is
  #     created and destroyed repeatedly while iterating
  multi_az            = false
  skip_final_snapshot = true
  deletion_protection = false

  backup_retention_period    = 1
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.name_prefix}-db"
  }
}
