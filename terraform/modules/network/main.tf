# =============================================================================
# Network module — the VPC and all of its plumbing.
#
#   VPC ─┬─ public subnets (x2)  ── public route table ── internet gateway
#        └─ private subnets (x2) ── private route table ── (bastion NAT)
#
# Two of each subnet, spread across two availability zones — the RDS subnet
# group requires subnets in at least two AZs. A "private" subnet is one with
# no route to the internet gateway; its instances can reach the internet only
# through the NAT hop, and nothing on the internet can connect to them.
#
# Free-tier constraint: a managed NAT gateway costs ~$35/month, so the
# BASTION doubles as the NAT (a classic budget pattern). This module only
# creates the private route table; the root module adds the 0.0.0.0/0 route
# pointing at the bastion's network interface, because the bastion instance
# doesn't exist yet when this module runs.
# =============================================================================

# Pick the first two AZs available in the region instead of hardcoding
# "eu-west-1a/b" — keeps the module usable in any region.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Required for instances and RDS to get resolvable DNS names
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

# --- Public subnets ----------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  # Instances launched here (the bastion) automatically get a public IP.
  # Accepted risk: the bastion is meant to be reachable, and its security
  # group only admits SSH from the team's own IPs (plus public HTTP).
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${count.index + 1}"
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
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private subnets ---------------------------------------------------------

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-private-${count.index + 1}"
  }
}

# Deliberately has no default route here — the root module attaches
# 0.0.0.0/0 → bastion ENI once the bastion exists. Until that route lands,
# this table only carries the VPC's implicit local route.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
