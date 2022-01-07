PROJECT DESCRIPTION

SHORT VERSION:
AWS VPC with 6 subnets in 2 different availability zones.
Each subnet contains one or more instances,
each of them serves their purposes.
Technology used: Terraform (building vpc and instances),
Ansible (setting up and configurating instances), Docker (docker container is used).

FULL:
For this Project I used Terraform, Ansible and docker.
Purpose of Project: Create a VPC in AWS, with several instances in it.

ABOUT VPC: 
Backend of this project is a S3 Bucket, so Terraform will be able to use Outputs while creating instances.
First VPC itself is created, and Internet Gateway.
VPC will contain 6 subnets in two availability zones (3 subnets for each)
Variables are used in this project, so the network will be flexible for changes.
Next NAT will be created, and elastic ip for it.
Next Route Tables will be created and associated to each subnet.

ABOUT INSTANCES:
New instances AMI is Amazon Linux 2.
There will be created 7 instances: 2 web-servers, 2 private servers, 2 database servers
(each one of above mentioned are for different availability zones) and one bastion host server
wich have access to other servers.
Web-servers are created using autoscaling group and elastic load ballancer.
Basion Host is created using autoscaling group.
Private and Daatabase servers are created without autoscaling group.
For every type of server it's own security group will be created.

ABOUT ANSIBLE:
Ansible is used for setting all servers for work and transfering all necessary files.
Ansible is used on local machine to set up Bastion Host server and transfer file there
then ansible will be used on Bastion Host server to connect, set up and transfer files to all other server.
On web-servers there will be a publicaly available internet page with public information.
On private servers there will be a private web page with private company information, wich is taken from database.
On DB servers there will be deployed docker containers with MariaDB.
