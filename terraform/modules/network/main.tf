# =============================================================================
# Network module — the VPC and everything needed to reach the internet.
#
#   VPC ── public subnet ── route table ── internet gateway
#
# A "public" subnet is just a subnet whose route table sends 0.0.0.0/0
# through an internet gateway; that association is what we build here.
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Required for the instance to get a resolvable public DNS name
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr

  # Instances launched here automatically get a public IP, which is how
  # Ansible (and users) will reach the server. Accepted risk for this
  # project: the security group still controls what traffic gets in.
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
