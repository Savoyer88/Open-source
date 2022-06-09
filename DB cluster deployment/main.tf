terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

resource "aws_internet_gateway" "ubuntu_ig" {
  vpc_id = var.default_VPC

  tags = {
    Name = "Internet Gateway"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = var.default_VPC

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ubuntu_ig.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.ubuntu_ig.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_subnet" "private_sub1" {
  vpc_id            = "vpc-065f859a493dfdce0"
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.3.0/24"

  tags = {
    Name = "Main"
  }
}

resource "aws_subnet" "private_sub2" {
  vpc_id            = "vpc-065f859a493dfdce0"
  availability_zone = "us-east-1b"
  cidr_block        = "10.0.4.0/24"

  tags = {
    Name = "Standby1"
  }
}

resource "aws_subnet" "private_sub3" {
  vpc_id            = "vpc-065f859a493dfdce0"
  availability_zone = "us-east-1c"
  cidr_block        = "10.0.5.0/24"

  tags = {
    Name = "Standby2"
  }
}

resource "aws_subnet" "private_sub4" {
  vpc_id            = "vpc-065f859a493dfdce0"
  availability_zone = "us-east-1d"
  cidr_block        = "10.0.8.0/24"

  tags = {
    Name = "Standby2"
  }
}

resource "aws_security_group" "ubuntu-sg" {
  name   = "ubuntu-sg"
  vpc_id = var.default_VPC

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "instance-sg"
  }
}

resource "aws_instance" "ubuntu1" {
  ami           = "ami-005de95e8ff495156"
  instance_type = var.machine_type
  key_name      = "TF_key"
  monitoring    = true
  subnet_id     = var.subnet1
  #count                  = var.ec2_count
  #subnet_id              = element(var.subnets, count.index)
  vpc_security_group_ids = [aws_security_group.ubuntu-sg.id]


  tags = {
    Terraform = "true"
    Team      = "Zerion"
  }
}

resource "aws_eip" "eip1" {
  instance = aws_instance.ubuntu1.id
  vpc      = true
}

resource "aws_eip" "eip2" {
  instance = aws_instance.ubuntu2.id
  vpc      = true
}

resource "aws_eip" "eip3" {
  instance = aws_instance.ubuntu3.id
  vpc      = true
}

resource "aws_eip" "eip4" {
  instance = aws_instance.ubuntu4.id
  vpc      = true
}

resource "aws_instance" "ubuntu2" {
  ami           = "ami-005de95e8ff495156"
  instance_type = var.machine_type
  key_name      = "TF_key"
  monitoring    = true
  subnet_id     = var.subnet2
  #count                  = var.ec2_count
  #subnet_id              = element(var.subnets, count.index)
  vpc_security_group_ids = [aws_security_group.ubuntu-sg.id]


  tags = {
    Terraform = "true"
    Team      = "Zerion"
  }
}

resource "aws_instance" "ubuntu3" {
  ami           = "ami-005de95e8ff495156"
  instance_type = var.machine_type
  key_name      = "TF_key"
  monitoring    = true
  subnet_id     = var.subnet3
  #count                  = var.ec2_count
  #subnet_id              = element(var.subnets, count.index)
  vpc_security_group_ids = [aws_security_group.ubuntu-sg.id]


  tags = {
    Terraform = "true"
    Team      = "Zerion"
  }
}

resource "aws_instance" "ubuntu4" {
  ami           = "ami-005de95e8ff495156"
  instance_type = var.machine_type
  key_name      = "TF_key"
  monitoring    = true
  subnet_id     = var.subnet4
  #count                  = var.ec2_count
  #subnet_id              = element(var.subnets, count.index)
  vpc_security_group_ids = [aws_security_group.ubuntu-sg.id]


  tags = {
    Terraform = "true"
    Team      = "Zerion"
  }
}

resource "aws_key_pair" "TF_key" {
  key_name   = "TF_key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "TF-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "tfkey"
}
