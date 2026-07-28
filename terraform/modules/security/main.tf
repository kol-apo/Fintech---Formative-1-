# =============================================================================
# Security module — one security group per tier, forming a trust chain:
#
#   internet ──80──▶ bastion ──3000──▶ app ──5432──▶ db
#   team IPs ──22──▶ bastion ──22────▶ app
#
# The bastion is the single public-facing machine: it terminates SSH for the
# team, forwards public HTTP to the app (iptables DNAT), and NATs the private
# subnets' outbound traffic — so it also accepts any traffic originating
# inside the VPC. Every other ingress rule references either an
# operator-supplied CIDR or another security group; the app server has no
# public exposure at all, and the database accepts connections from nowhere
# except the app server and the bastion.
# =============================================================================

# --- Bastion: SSH door, public HTTP front door, and NAT hop ------------------

resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-sg"
  description = "Bastion - SSH from team IPs, public HTTP, NAT for private subnets"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-bastion-sg"
  }
}

# One rule per team member CIDR — adding someone to ssh_allowed_cidrs in
# tfvars adds exactly one auditable rule here.
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each = toset(var.ssh_allowed_cidrs)

  security_group_id = aws_security_group.bastion.id
  description       = "SSH from an approved operator IP"

  cidr_ipv4   = each.value
  from_port   = var.ssh_port
  to_port     = var.ssh_port
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "bastion_http" {
  security_group_id = aws_security_group.bastion.id
  description       = "Public HTTP - forwarded to the app server by iptables"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = var.public_http_port
  to_port     = var.public_http_port
  ip_protocol = "tcp"
}

# The NAT role: outbound traffic from the private subnets (apt, ECR pulls,
# etc.) arrives here to be masqueraded out. Scoped to the VPC CIDR, so this
# opens nothing to the internet.
resource "aws_vpc_security_group_ingress_rule" "bastion_nat_from_vpc" {
  security_group_id = aws_security_group.bastion.id
  description       = "Traffic from inside the VPC, for NAT forwarding"

  cidr_ipv4   = var.vpc_cidr
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_egress_rule" "bastion_all_out" {
  security_group_id = aws_security_group.bastion.id
  description       = "Allow all outbound (NAT-forwarded traffic, SSH to app, apt)"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# --- App server: private, reachable only via the bastion ---------------------

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "App server - HTTP and SSH from the bastion only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-app-sg"
  }
}

# The production traffic path: the bastion's iptables DNAT also masquerades,
# so forwarded public requests arrive with the bastion as their source and
# this SG-to-SG rule is all the app ever needs to accept.
resource "aws_vpc_security_group_ingress_rule" "app_from_bastion" {
  security_group_id = aws_security_group.app.id
  description       = "App traffic forwarded by the bastion (public URL path)"

  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_bastion" {
  security_group_id = aws_security_group.app.id
  description       = "SSH from the bastion only (Ansible jump path)"

  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = var.ssh_port
  to_port                      = var.ssh_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all_out" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound (apt, ECR pulls, database - via the bastion NAT)"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# --- Database: accepts connections from the app tier and bastion only --------

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "RDS - connections from app server and bastion only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id = aws_security_group.db.id
  description       = "Database connections from the app server"

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

# Migrations / psql debugging through an SSH tunnel via the bastion
resource "aws_vpc_security_group_ingress_rule" "db_from_bastion" {
  security_group_id = aws_security_group.db.id
  description       = "Database connections from the bastion (SSH tunnel)"

  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

# No egress rules on the db security group: RDS never initiates outbound
# connections, so security groups' default-deny is exactly what we want.
