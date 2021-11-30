provider "aws" {
  region = "eu-central-1"
}

terraform {
  backend "s3" {
    bucket = "bucket-for-my-testproject1"
    key    = "my-testproject1/instances/terraform.tfstate"
    region = "eu-central-1"
  }
}
#==========================================================================
#DATA
data "aws_availability_zones" "available" {}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "bucket-for-my-testproject1"
    key    = "my-testproject1/network/terraform.tfstate"
    region = "eu-central-1"
  }
}

data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
#========================================================================
#WEB_servers(ASG+ELB)_and_SG

resource "aws_launch_configuration" "web" {
  name            = "Higly_Available_WebServer-LC"
  image_id        = data.aws_ami.latest_amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.webserver.id]
  user_data       = file("user_data.sh")
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "Higly_Available_WebServer-ASG"
  launch_configuration      = aws_launch_configuration.web.name
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 2
  vpc_zone_identifier       = [data.terraform_remote_state.network.outputs.public_subnet_ids[0], data.terraform_remote_state.network.outputs.public_subnet_ids[1]]
  health_check_type         = "ELB"
  wait_for_capacity_timeout = "5m"
  load_balancers            = [aws_elb.ELB.name]

  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG"
      Owner  = "Dmitriy"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "ELB" {
  name               = "terraform-elb"
  availability_zones = ["eu-central-1a", "eu-central-1b"]
  security_groups    = [aws_security_group.web.id]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 4
    target              = "HTTP:80/"
    interval            = 5
  }
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}


resource "aws_security_group" "webserver" {
  name   = "WebServer Security Group"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}web-server-sg"
  }
}

#===========================================================================================
#BastionHost_server_and_SG

resource "aws_launch_configuration" "BH" {
  name            = "bastionhost_launch_conf"
  image_id        = data.aws_ami.latest_amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.bastionhost.id]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "BH" {
  name                      = "ASG_for_bastionhost"
  launch_configuration      = aws_launch_configuration.BH.name
  min_size                  = 1
  desired_capacity          = 1
  max_size                  = 1
  vpc_zone_identifier       = [data.terraform_remote_state.network.outputs.public_subnet_ids[]]
  health_check_type         = "EC2"
  wait_for_capacity_timeout = "5m"

  dynamic "tag" {
    for_each = {
      Name   = "${var.name}bastionhost"
      Owner  = "Dmitriy"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_security_group" "bastionhost" {
  name   = "bastionhost Security Group"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "${var.name}bastionhost-sg"
  }
}
#===========================================================================================
#Private_servers_and_SG

resource "aws_instance" "Private_servers" {
  count                  = length(data.terraform_remote_state.network.outputs.private_subnet_ids)
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.private.id]
  subnet_id              = data.terraform_remote_state.network.outputs.private_subnet_ids[count.index]
  availability_zone      = data.aws_availability_zones.available.names[count.index]
  key_name   = "private_servers_key_pair${count.index + 1}"

  tags = {
    Name = "${var.name}private-server ${count.index + 1}"
  }
}

resource "aws_security_group" "private" {
  name   = "private Security Group"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}private-server-sg"
  }
}
#===============================================================================================
#DB_servers_and_SG

resource "aws_instance" "DB" {
  count                  = length(data.terraform_remote_state.network.outputs.DB_subnet_ids)
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.DB.id]
  subnet_id              = data.terraform_remote_state.network.outputs.DB_subnet_ids[count.index]
  availability_zone      = data.aws_availability_zones.available.names[count.index]
  key_name   = "DB_servers_key_pair${count.index + 1}"

  tags = {
    Name = "${var.name}DB-server ${count.index + 1}"
  }
}

resource "aws_security_group" "DB" {
  name   = "DB Security Group"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}DB-server-sg"
  }
}

#===============================================================================================================
#Security_keys_for_DB_and_private_servers

resource "tls_private_key" "gen_ssh_key_for_private_servers" {
  count = length(data.terraform_remote_state.network.outputs.private_subnet_ids)
  algorithm   = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "private_servers_key_pair" {
  count = length(data.terraform_remote_state.network.outputs.private_subnet_ids)
  key_name   = "private_servers_key_pair${count.index + 1}"
  public_key = tls_private_key.gen_ssh_key_for_private_servers.public_key_openssh[count.index]
}

resource "tls_private_key" "gen_ssh_key_for_DB_servers" {
  count = length(data.terraform_remote_state.network.outputs.DB_subnet_ids)
  algorithm   = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "DB_servers_key_pair" {
  count = length(data.terraform_remote_state.network.outputs.DB_subnet_ids)
  key_name   = "DB_servers_key_pair${count.index + 1}"
  public_key = tls_private_key.gen_ssh_key_for_DB_servers.public_key_openssh[count.index]
}
