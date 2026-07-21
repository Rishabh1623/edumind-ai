variable "common_tags" {
  description = "Common tags applied to every resource"
  type        = map(string)
}

variable "vpc_id" {
  description = "VPC ID (from the networking module)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (from the networking module) for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from the networking module) for the ASG"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID (from the networking module) for the ALB"
  type        = string
}

variable "app_security_group_id" {
  description = "Security group ID (from the networking module) for the app tier"
  type        = string
}

variable "aurora_secret_arn" {
  description = "ARN of the Secrets Manager secret holding Aurora credentials (from the database module)"
  type        = string
}

variable "district_001_kms_key_arn" {
  description = "ARN of the district_001 KMS key (from the storage module)"
  type        = string
}

variable "district_002_kms_key_arn" {
  description = "ARN of the district_002 KMS key (from the storage module)"
  type        = string
}
