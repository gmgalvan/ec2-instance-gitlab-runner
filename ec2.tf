# Security group
resource "aws_security_group" "instance_sg" {
  name        = "instance-sg"
  description = "Security group for EC2 instance"
  vpc_id      = var.vpc_id

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
    Name = "instance-sg"
  }
}

# IAM role for Session Manager and Secrets Manager access
resource "aws_iam_role" "ssm_secrets_role" {
  name = "ssm-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach SSM policy to the role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm_secrets_role.name
}

# Create a policy for Secrets Manager access
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "secrets-manager-read-policy"
  path        = "/"
  description = "Policy to allow reading from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:gitlab-runner-token-*"
      }
    ]
  })
}

# Attach Secrets Manager policy to the role
resource "aws_iam_role_policy_attachment" "secrets_manager_policy_attachment" {
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
  role       = aws_iam_role.ssm_secrets_role.name
}

# Instance profile
resource "aws_iam_instance_profile" "ssm_secrets_instance_profile" {
  name = "ssm-secrets-instance-profile"
  role = aws_iam_role.ssm_secrets_role.name
}

# EC2 instance
resource "aws_instance" "gitlab_instance_runner" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_secrets_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

              set -x  # Enable command tracing
              set -e  # Exit immediately if a command exits with a non-zero status.

              echo "Starting user data script execution"

              # Update and install basic packages
              sudo apt-get update
              sudo apt-get install -y ca-certificates curl gnupg lsb-release jq unzip

              # Add Docker's official GPG key
              sudo mkdir -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

              # Set up the Docker repository
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

              # Install Docker
              sudo apt-get update
              sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

              # Install AWS CLI
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              sudo ./aws/install

              # Create directories for GitLab Runner
              sudo mkdir -p /srv/gitlab-runner/config

              echo "Retrieving GitLab Runner token from Secrets Manager"
              SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id gitlab-runner-token --region ${data.aws_region.current.name} --query SecretString --output text)
              RUNNER_TOKEN=$(echo $SECRET_JSON | jq -r '."gitlab-runner-token"')

              if [ -z "$RUNNER_TOKEN" ]; then
                echo "Failed to retrieve GitLab Runner token from Secrets Manager"
                exit 1
              fi

              echo "Successfully retrieved GitLab Runner token"

              echo "Registering GitLab Runner"
              sudo docker run --rm -v /srv/gitlab-runner/config:/etc/gitlab-runner gitlab/gitlab-runner register \
                --non-interactive \
                --url "https://gitlab.com/" \
                --token "$RUNNER_TOKEN" \
                --executor "docker" \
                --docker-image alpine:latest

              echo "GitLab Runner registered successfully"

              # Start the GitLab Runner
              echo "Starting GitLab Runner"
              sudo docker run -d --name gitlab-runner --restart always \
                  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
                  -v /var/run/docker.sock:/var/run/docker.sock \
                  gitlab/gitlab-runner:latest

              echo "GitLab Runner started"
              sudo docker ps

              echo "User data script completed"
              EOF

  tags = {
    Name = "gitlab-instance-runner"
  }
}