terraform {
  backend "s3" {
    bucket = "mtleuberdinov-bucket"
    key    = "key/terraform.tfstate"
    region = "us-east-1"
  }
}
