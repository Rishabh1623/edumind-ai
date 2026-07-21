variable "aws_region" {
  description = "AWS region (also used to construct the CloudTrail trail's deterministic ARN)"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to every resource"
  type        = map(string)
}

variable "audit_logs_bucket_name" {
  description = "Name of the audit-logs S3 bucket (from the storage module)"
  type        = string
}

variable "audit_logs_bucket_arn" {
  description = "ARN of the audit-logs S3 bucket (from the storage module)"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (from the application module), used for CloudWatch dimensions"
  type        = string
}

variable "asg_name" {
  description = "Name of the Auto Scaling Group (from the application module)"
  type        = string
}

variable "aurora_cluster_identifier" {
  description = "Cluster identifier of the Aurora cluster (from the database module)"
  type        = string
}
