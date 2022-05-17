terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

resource "aws_vpc" "network-prod" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "default_VPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.network-prod.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = var.zone

  tags = {
    Name = "my_subnet"
  }
}

resource "aws_internet_gateway" "ubuntu_ig" {
  vpc_id = aws_vpc.network-prod.id

  tags = {
    Name = "Internet Gateway"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.network-prod.id

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

resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}


resource "aws_instance" "ubuntu" {
  

  #name = "${var.instance_name}-${substr(var.environment, 0, 1)}-${random_string.random.result}"

  ami                         = "ami-09d56f8956ab235b3"
  instance_type               = var.machine_type
  key_name                    = "TF_key"
  monitoring                  = true
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.ubuntu-sg.id]
  associate_public_ip_address = var.public_ip
  get_password_data     =   "true"
  provisioner "remote-exec"  {
    inline = ["echo hello world"]
      connection {
        type = "winrm"
        host = aws_instance.ubuntu.public_ip
        password = "${rsadecrypt(self.password_data,tls_private_key.rsa.private_key_pem)}"
    }
  }
  /* In case if we need to increase a number of instances 
  count = var.ec2_count */

  tags = {
    Terraform   = "true"
    Team        = "Badal"
    Environment = substr(var.environment, 0, 1)
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

