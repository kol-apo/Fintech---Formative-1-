# =============================================================================
# Security module — the network security rules (AWS security group).
#
# Only two doors in:
#   - SSH (22)      from the single CIDR the operator supplies (their own IP)
#   - the app port  from anywhere, because it's a public API
# Everything else inbound is denied by default (security groups are
# default-deny), and all outbound traffic is allowed so the server can
# pull OS packages and Docker images.
# =============================================================================

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "Firewall rules for the MoMoSim application server"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-app-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app.id
  description       = "SSH access, restricted to the operator's IP only"

  cidr_ipv4   = var.ssh_allowed_cidr
  from_port   = var.ssh_port
  to_port     = var.ssh_port
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id = aws_security_group.app.id
  description       = "Public access to the MoMoSim REST API"

  cidr_ipv4   = var.app_allowed_cidr
  from_port   = var.app_port
  to_port     = var.app_port
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound (apt, Docker Hub, npm)"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
