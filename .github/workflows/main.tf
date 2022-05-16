terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  cloud {
    organization = "Terraform_Marlen"

    workspaces {
      name = "gh-actions-demo"
    }
  }
}


provider "aws" {
  region = var.region

}

resource "aws_security_group" "ubuntu-sg" {
  name   = "ubuntu-sg"
  vpc_id = aws_vpc.network-prod.id

  ingress {
    from_port   = 80
    to_port     = 80
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

variable "region" {
  type    = string
  default = ""
}

variable "instance_name" {
  type    = string
  default = ""
}

variable "machine_type" {
  type    = string
  default = "t2.micro"
  validation {
    condition = contains(
      ["t3.nano", "t2.micro", "t2.large", "m4.large"],
      var.machine_type
    )
    error_message = "Err: Machine type is not allowed."
  }
}


variable "ec2_count" {
  type    = number
  default = "1"
}
variable "zone" {
  type    = string
  default = ""
}

variable "environment" {
  type    = string
  default = "production"
}

variable "network_id" {
  type    = string
  default = "network-prod"
}

variable "public_ip" {
  type    = bool
  default = false
}



module "ubuntu" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "${var.instance_name}-${substr(var.environment, 0, 1)}-${random_string.random.result}"

  ami                         = "ami-09d56f8956ab235b3"
  instance_type               = var.machine_type
  key_name                    = "TF_key"
  monitoring                  = true
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.ubuntu-sg.id]
  associate_public_ip_address = var.public_ip
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

resource "local_file" "TF-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "tfkey"
}

output "vm_name" {
  value = "${var.instance_name}-${substr(var.environment, 0, 1)}-${random_string.random.result}"

}

output "public_IP_address" {
  value = module.ubuntu.public_ip
}

output "private_IP_address" {
  value     = module.ubuntu.private_ip
  sensitive = false
}

terraform {
  backend "s3" {
    bucket = "mtleuberdinov-bucket"
    key    = "key/terraform.tfstate"
    region = "us-east-1"
  }
}

terraform {
  required_providers {
    assert = {
      source  = "bwoznicki/assert"
      version = "0.0.1"
    }
  }
}

data "assert_test" "workspace" {
  test  = terraform.workspace != "origin"
  throw = "default workspace is not valid in this project"
}

data "aws_region" "current" {}

data "assert_test" "region" {
  test  = data.aws_region.current.name == "us-east-1"
  throw = "You cannot deploy this resource in any other region but us-east-1"
}