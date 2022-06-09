resource "aws_db_subnet_group" "database-subnet-group" {
  name        = "database_subnets"
  subnet_ids  = [aws_subnet.private_sub1.id, aws_subnet.private_sub2.id, aws_subnet.private_sub3.id, aws_subnet.private_sub4.id]
  description = "Subnets for Database Instance"

  tags = {
    Name = "Database Subnets"
  }
}

resource "aws_security_group" "db_security_group" {
  name   = "DB_SG"
  vpc_id = "vpc-065f859a493dfdce0"

  ingress {
    description     = "SSH"
    from_port       = 3306
    protocol        = "tcp"
    to_port         = 3306
    self            = false
    security_groups = []
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self            = false
    security_groups = []
    cidr_blocks     = ["0.0.0.0/0"]

  }
}

resource "aws_db_instance" "db_a" {
  engine                  = "mysql"
  engine_version          = "5.7"
  username                = "terraform"
  password                = "terraform01234"
  instance_class          = "db.t2.micro"
  skip_final_snapshot     = true
  backup_retention_period = 5
  allocated_storage       = 10
  identifier              = "db-1-mysql"
  db_subnet_group_name    = aws_db_subnet_group.database-subnet-group.name
  multi_az                = false
  vpc_security_group_ids  = [aws_security_group.db_security_group.id]
}

resource "aws_db_instance" "db_b" {
  engine                 = "mysql"
  engine_version         = "5.7"
  username               = "terraform"
  password               = "terraform01234"
  instance_class         = "db.t2.micro"
  replicate_source_db    = aws_db_instance.db_a.identifier
  skip_final_snapshot    = true
  allocated_storage      = 10
  multi_az               = false
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
}

resource "aws_db_instance" "db_c" {
  engine                 = "mysql"
  engine_version         = "5.7"
  username               = "terraform"
  password               = "terraform01234"
  instance_class         = "db.t2.micro"
  replicate_source_db    = aws_db_instance.db_a.identifier
  skip_final_snapshot    = true
  allocated_storage      = 10
  multi_az               = false
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
}
