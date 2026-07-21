variable "common_tags" {
  description = "Common tags applied to every resource"
  type        = map(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from the networking module) for the DB subnet group"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security group ID (from the networking module) allowing app-tier access to RDS"
  type        = string
}
