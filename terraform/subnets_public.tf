resource "aws_subnet" "public_fargate_az1" {
  vpc_id                  = aws_vpc.dashboard_inventario.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"  # use2-az1
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-public-fargate"
  }
}
resource "aws_subnet" "public_fargate_az2" {
  vpc_id                  = aws_vpc.dashboard_inventario.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-public-fargate-az2"
  }
}
resource "aws_subnet" "public_fargate_az3" {
  vpc_id                  = aws_vpc.dashboard_inventario.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-2c"  
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-public-fargate-az3"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.dashboard_inventario.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "public-route-table"
  }
}
resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_fargate_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_fargate_az2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az3" {
  subnet_id      = aws_subnet.public_fargate_az3.id
  route_table_id = aws_route_table.public.id
}

# Outputs de las Subredes Públicas
output "public_subnet_ids" {
  description = "IDs de las subredes públicas"
  value = [
    aws_subnet.public_fargate_az1.id,
    aws_subnet.public_fargate_az2.id,
    aws_subnet.public_fargate_az3.id
  ]
}

output "public_route_table_id" {
  description = "ID de la tabla de rutas pública"
  value       = aws_route_table.public.id
}
