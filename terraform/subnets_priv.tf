#Configuración de las subredes privadas 
resource "aws_subnet" "private_db_az1" {
  vpc_id            = aws_vpc.dashboard_inventario.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "subnet-private-db"
  }
}

resource "aws_subnet" "private_db_az2" {
  vpc_id            = aws_vpc.dashboard_inventario.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "subnet-private-db-az2"
  }
}
resource "aws_subnet" "private_db_az3" {
  vpc_id            = aws_vpc.dashboard_inventario.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-2c"
  tags = {
    Name = "subnet-private-db-az3"
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.dashboard_inventario.id

  tags = {
    Name = "private-route-table"
  }
}
resource "aws_route_table_association" "private_az1" {
  subnet_id      = aws_subnet.private_db_az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_az2" {
  subnet_id      = aws_subnet.private_db_az2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_az3" {
  subnet_id      = aws_subnet.private_db_az3.id
  route_table_id = aws_route_table.private.id
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas"
  value = [
    aws_subnet.private_db_az1.id,
    aws_subnet.private_db_az2.id,
    aws_subnet.private_db_az3.id
  ]
}

output "private_route_table_id" {
  description = "ID de la tabla de rutas privada"
  value       = aws_route_table.private.id
}
