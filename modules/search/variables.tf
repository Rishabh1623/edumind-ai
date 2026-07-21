variable "common_tags" {
  description = "Common tags applied to every resource"
  type        = map(string)
}

variable "vpc_id" {
  description = "VPC ID (from the networking module) for the OpenSearch Serverless VPC endpoint"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from the networking module) for the VPC endpoint"
  type        = list(string)
}

variable "opensearch_security_group_id" {
  description = "Security group ID (from the networking module) allowing app-tier access to OpenSearch"
  type        = string
}

variable "app_role_arn" {
  description = "ARN of the application IAM role (from the application module), granted full data access to the collection"
  type        = string
}
