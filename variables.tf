variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS account ID. Never hardcode this — supply via terraform.tfvars or CI variables."
  type        = string
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Project name used for tagging and naming"
  type        = string
  default     = "EduMind"
}
