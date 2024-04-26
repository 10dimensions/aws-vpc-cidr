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
# module "subnet_cidr" {
#   source  = "hashicorp/subnets/cidr"
#   version = "1.0"

#   vpc_cidr  = aws_vpc.main.cidr_block
#   num_subnets = 2
#   cidr_block_size = 24
# }

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Public subnet
resource "aws_subnet" "public_subnet" {
  count = length(module.subnet_cidr.cidr_blocks) - 1

  vpc_id          = aws_vpc.main.id
  cidr_block       = cidrsubnet(var.vpc_cidr, 4, 0)
  map_public_ip_on_launch = true
  availability_zone = var.aws_availability_zone

  tags = {
    Name = "my-public-subnet"
  }
}
//module.subnet_cidr.cidr_blocks[count.index]
//data.aws_availability_zones.available.names[0]

# Internet gateway for public subnet
resource "aws_internet_gateway" "public_gw" {
  vpc_id = aws_vpc.main.id
  tags = module.label_vpc.tags
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = module.label_vpc.tags
}

# Route table association for public subnet
resource "aws_route_table_association" "public_subnet_route" {
  subnet_id = aws_subnet.public.*.id
  route_table_id = aws_internet_gateway.public_gw.id
}

# Private subnet
resource "aws_subnet" "private_subnet" {
  count = 1

  vpc_id          = aws_vpc.main.id
  cidr_block       = cidrsubnet(var.vpc_cidr, 4, 1)
  map_public_ip_on_launch = false
  availability_zone = var.aws_availability_zone
  tags = {
    Name = "my-private-subnet"
  }
}
#module.subnet_cidr.cidr_blocks[0]
#data.aws_availability_zones.available.names[0]

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

#resource "aws_eip" "nat_eip" {
#  vpc = true
#}

# Create NAT Gateway in Public Subnet
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = module.label_vpc.tags
}
