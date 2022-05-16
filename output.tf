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

/*output "Root_Password" {
 value       = module.ubuntu.password_data
 sensitive = false
}
*/