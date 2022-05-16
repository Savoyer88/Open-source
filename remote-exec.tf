/*AWS does not support changing root user password as key pairs are used to access EC2 instances which we defined and generated unlike GCP and Azure
I believe something similar to the following algorithm could be used to change root password of a root user
#resource "" "ubuntu" {
    ami           = "ami-09d56f8956ab235b3"
    instance_type = var.machine_type

connection {
    type     = "ssh"
    user     = "terraform"
    host = module.ubuntu.public_ip
    private_key = tls_private_key.rsa.private_key_pem
  }


provisioner "remote-exec" {
    inline = [
        "sudo su",
        "vim /etc/ssh/sshd_config",
        "PasswordAuthentication yes",
        "service sshd restart",
        "passwd terraform",
        "passwd bob"
    ]
    }
}
*/
