variable "region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "my_ip" {
  description = "Your current public IP address for Bastion SSH access (without /32 suffix)"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the existing AWS EC2 Key Pair for SSH access"
  type        = string
}

variable "admin_password" {
  description = "Password for the techcorp-admin user on all servers (username/password SSH access)"
  type        = string
  sensitive   = true
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the Bastion Host"
  type        = string
  default     = "t3.micro"
}

variable "web_instance_type" {
  description = "EC2 instance type for Web Servers"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "EC2 instance type for the Database Server"
  type        = string
  default     = "t3.small"
}
