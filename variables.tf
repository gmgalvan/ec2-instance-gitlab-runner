variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "private_subnet_id" {
  description = "The private subnet ID"
  type        = string
}

# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for secret manager
data "aws_secretsmanager_secret_version" "gitlab_runner_token" {
  secret_id = "gitlab-runner-token"
}

# Data source to get the current region
data "aws_region" "current" {}

# Data source to get the current account ID
data "aws_caller_identity" "current" {}