# =============================================================================
# Compute module — the EC2 instance that will run the MoMoSim container.
#
# Terraform only provisions the machine; installing Docker and deploying the
# app is Ansible's job (ansible/ directory), so this instance boots as a
# plain Ubuntu server reachable over SSH.
# =============================================================================

# Look up the latest Ubuntu 22.04 LTS AMI at plan time instead of hardcoding
# an AMI ID — IDs differ per region, so this keeps the module region-agnostic.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.ami_owner_id]

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Upload the operator's public key so Ansible/SSH can authenticate.
# Only the PUBLIC half ever leaves the operator's machine.
resource "aws_key_pair" "app" {
  key_name   = "${var.name_prefix}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = aws_key_pair.app.key_name

  # Require IMDSv2 (session tokens) for instance metadata — blocks the
  # credential-theft trick that abuses the older IMDSv1 endpoint.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = var.root_volume_type
    encrypted   = true
  }

  # Detailed monitoring costs extra and isn't needed for a formative
  monitoring = false

  tags = {
    Name = "${var.name_prefix}-app-server"
  }
}
