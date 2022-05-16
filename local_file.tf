resource "local_file" "TF-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "tfkey"
}
#resource "local_file" "TF-key" {
  #content  = tls_private_key.rsa.private_key_pem
  #filename = "tfkey"
#}