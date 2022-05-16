Tasks 1, 2 and 3.

1.  Using Terraform I coded a module that provisions a VM instance in AWS Cloud. Module performs the following:

1.1 Creates an Ubuntu VM instance based on the input parameters passed to the module.
{All input parameters via vars except for ami, however, ami could also be set via variable

1.2 Sets the instance name according to agreed naming convention (refer to the addtional info section).
{done}

1.3 Attaches a network (VPC) to the VM instance.
{done, with a cidr block and a public subnet}

1.5 Provisions a public IP address.
{done}
1.6 Assigns labels to the compute resource.
{done, Team & Environment}

1.7 Validates the machine type variable making sure that only the allowed machine type is requested.
{done, preset to 4 options, next time I will use Free-tier instances}

1.8 Using remote exec, sets a unique random password to the root user on the VM instance 
{this is not quite doneI have an idea how to do it but a lack of knowledge leaves this (Or maybe AWS Cloud does not really allow this, maybe it works only with Azure and GCP}

1.9 Returns required module outputs
{done}

2. Information about the created VM instance must be saved to a local file. The file should contain the following information: - Instance name - Private IP addresses - Public IP address - Password

Additional information:

Naming convention for a vm-instance: <instance_name>-<env_code>-<random_string>. For example: db-srv001-p-dg64, where:
instance_name: db-srv001
env_code: p
random string: dg64
The "env_code” string must be parsed from the environment variable using a Terraform function inside the module.
{To meet name convention requirements, I used variables + random string resource}

Assume that a network (VPC) is already created, "network-prod" . If it's required by the provider, declare a subnetwork as well.
Variables such as Region, Zone, Labels should not be hardcoded.
Public IP provisioning must be contoled by a Boolean switch: true/false.
For mandaroty variables refer to the next section. Feel free to introduce any other variuables to support the functionality of your module.

Module Inputs:

Input	Type	Mandatory	Default
instance_name	string	yes	-
environment	string	yes	production
region	string	yes	-
zone	string	yes	-
machine_type	string	no	n2-standard
network_id	string	no	network-prod
public_ip	boolean	no	false
labels	map	no	-

Module Outputs:

Output	Type	Value
vm_name	string	vm-instance full name
Private IP address	string	string
Public IP address	string	string
*Root Password	string	string - not completed, I have added my comments with an idea how to complete it

3. Write Terraform infrastructure code for deploying a VM instance in Cloud using the module you have created in the previous task.

3.1 Demonstrate “structure” for your Terraform code files. For instance, a separate TF file for variables, etc..
{on my local machine I splitted all resources into 10 files but later I combined everything under one main.tf file for CI/CD pipeline}

3.2 Make sure that you define all the mandatory variables values in a way that a CI/CD tool will be able to pass them.
{done}

3.3 (optional) Make sure that your Terraform state file is NOT hosted on you local PC.
{hosted on S3 bucket}

3.4 Commit your Infra code into any version control tool with “public access” (GitHub).
{done}
