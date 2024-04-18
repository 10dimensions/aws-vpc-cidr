module "label_vpc" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "vpc"
  attributes = ["main"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = module.label_vpc.tags
}

# =========================
# Create your subnets here
# =========================

# Use external module for subnet CIDR calculation
module "subnet_cidr" {
  source  = "hashicorp/subnets/cidr"
  version = "1.0"

  vpc_cidr  = aws_vpc.main.cidr_block
  num_subnets = 2
  cidr_block_size = 24
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Public subnet
resource "aws_subnet" "public" {
  count = length(module.subnet_cidr.cidr_blocks) - 1

  vpc_id          = aws_vpc.main.id
  cidr_block       = module.subnet_cidr.cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "my-public-subnet"
  }
}

# Internet gateway for public subnet
resource "aws_internet_gateway" "public_gw" {

}

# Route table association for public subnet
resource "aws_route_table_association" "public_subnet_route" {
  subnet_id = aws_subnet.public.*.id
  route_table_id = aws_internet_gateway.public_gw.id
}

# Private subnet
resource "aws_subnet" "private" {
  count = 1

  vpc_id          = aws_vpc.main.id
  cidr_block       = module.subnet_cidr.cidr_blocks[0]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "my-private-subnet"
  }
}
