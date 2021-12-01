terraform {
  backend "s3" {
    bucket = "bucket-for-my-testproject1"
    key    = "my-testproject1/network/terraform.tfstate"
    region = "eu-central-1"
  }
}

data "aws_availability_zones" "available" {}
#=============================================================================
#VPC_and_IGW

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.name}VPC"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name}IGW"
  }
}
#============================================================================================================
#SUBNETS
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name}public-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.name}private-${count.index + 1}"
  }
}

resource "aws_subnet" "DB_subnets" {
  count             = length(var.DB_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.DB_subnet_cidrs, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.name}DB-${count.index + 1}"
  }
}
#========================================================================================================
#EIP_and_NAT
resource "aws_eip" "eip" {
  count      = length(var.private_subnet_cidrs)
  depends_on = [aws_internet_gateway.main]
}
resource "aws_nat_gateway" "NAT" {
  count         = length(var.private_subnet_cidrs)
  allocation_id = element(aws_eip.eip[*].id, count.index)
  subnet_id     = element(aws_subnet.public_subnets[*].id, count.index)

  tags = {
    Name = "${var.name}NAT-${count.index + 1}"
  }
}
#=======================================================================================================
#Public_routes
resource "aws_route_table" "public_subnets" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.name}route-public-subnets"
  }
}

resource "aws_route_table_association" "public_routes" {
  count          = length(aws_subnet.public_subnets[*].id)
  route_table_id = aws_route_table.public_subnets.id
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
}
#======================================================================================
#Private_routes

resource "aws_route_table" "private_subnets" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.NAT[*].id, count.index)
  }
  tags = {
    Name = "${var.name}route-private-subnets"
  }
}

resource "aws_route_table_association" "private_routes" {
  count          = length(aws_subnet.private_subnets[*].id)
  route_table_id = element(aws_route_table.private_subnets[*].id, count.index)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
}
#====================================================================================
#DB_routes

resource "aws_route_table" "DB_subnets" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}route-DB-subnets"
  }
}

resource "aws_route_table_association" "DB_routes" {
  count          = length(aws_subnet.DB_subnets[*].id)
  route_table_id = aws_route_table.DB_subnets.id
  subnet_id      = element(aws_subnet.DB_subnets[*].id, count.index)
}
