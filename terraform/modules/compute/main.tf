# =============================================================================
# Compute module — one Ubuntu EC2 instance.
#
# Generic on purpose: the root module instantiates it twice, once as the app
# server (private subnet, no public IP, ECR pull role) and once as the bastion
# (public subnet, public IP, no role). Terraform only provisions the machine;
# installing Docker and deploying the app is Ansible's job (ansible/ directory),
# so every instance boots as a plain Ubuntu server reachable over SSH.
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

resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name

  # Explicit rather than inherited from the subnet, so moving the instance
  # between subnets can never silently change its exposure.
  associate_public_ip_address = var.associate_public_ip

  # Only the app server gets a role (ECR pull); the bastion passes null
  iam_instance_profile = var.iam_instance_profile

  # Must be false on the bastion: as the NAT hop it forwards packets whose
  # source/destination is not its own address, which this check would drop.
  source_dest_check = var.source_dest_check

  # First-boot script (the bastion's NAT/port-forward setup). Replace the
  # instance when it changes — the script only runs on first boot, so an
  # in-place update would silently never execute.
  user_data                   = var.user_data
  user_data_replace_on_change = true

  # Require IMDSv2 (session tokens) for instance metadata — blocks the
  # credential-theft trick that abuses the older IMDSv1 endpoint. Matters
  # more now that the app instance carries an IAM role.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = var.root_volume_type
    encrypted   = true
  }

  # Detailed monitoring costs extra and isn't needed for coursework
  monitoring = false

  # T-family instances default to "unlimited" CPU bursting, which quietly
  # bills extra when the instance bursts too long. "standard" caps us at the
  # baseline instead — the team account runs on fixed credits, so a surprise
  # burn-down is worse than a briefly slow server.
  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "${var.name_prefix}-${var.server_role}"
  }
}
