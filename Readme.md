# EC2 Runner Instance Provisioner

## Description

This project provisions a GitLab Runner on an AWS EC2 instance using Terraform. The GitLab Runner is configured to run CI/CD jobs for your GitLab projects.

## Setup Instructions

1. **Store the `gitlab-runner-token` in AWS Secrets Manager:**
   Ensure you have the GitLab Runner registration token stored in AWS Secrets Manager with the name `gitlab-runner-token`.

2. **Configure Terraform variables:**
   Add necessary variables in the `terraform.tfvars` file. The GitLab Runner token will be retrieved from AWS Secrets Manager.

3. **Apply the Terraform configuration:**
   Run the following command to provision the resources:

   ```bash
   terraform apply
   ```
## Work In Progress (WIP)

- **Session Manager:** Integration with AWS Session Manager for secure access to the EC2 instance without needing SSH keys.
- **Private Subnet Functionality:** Configuring the EC2 instance to run within a private subnet for enhanced security.
