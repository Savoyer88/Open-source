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

