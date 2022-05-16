terraform {
  required_providers {
    assert = {
      source  = "bwoznicki/assert"
      version = "0.0.1"
    }
  }
}

data "assert_test" "workspace" {
    test = terraform.workspace != "origin"
    throw = "default workspace is not valid in this project"
}

data "aws_region" "current" {}

data "assert_test" "region" {
    test = data.aws_region.current.name == "us-east-1"
    throw = "You cannot deploy this resource in any other region but us-east-1"
}