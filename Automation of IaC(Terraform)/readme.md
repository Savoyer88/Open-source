Writing simple module to provision basic AWS infrastructure: Ubuntu VM instance with a condition, VPC with a public IP, remote exec, 

Demonstrated basic “structure” for Terraform code files. For instance, a separate TF file for variables, etc.. {on my local machine I splitted all resources into 10 files but later I combined everything under one main.tf file for CI/CD pipeline}

Ensured that all the mandatory variables defined in a way that a CI/CD tool was able to pass them.

tfstate file was hosted on S3 bucket 

Used GitHub Actions to automate infrastructure provisioning - terraform.yml - creates CICD pipeline on Github Actions to validate and deploy our infrastructure code, it works, resources are deployed, under Actions tab
triggered using pull request from a production branch
