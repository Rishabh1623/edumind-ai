variable "aws_region" {
  description = "AWS region (used to construct the Titan embedding model's foundation-model ARN)"
  type        = string
}

variable "aurora_cluster_arn" {
  description = "ARN of the Aurora cluster (from the database module)"
  type        = string
}

variable "aurora_secret_arn" {
  description = "ARN of the Secrets Manager secret holding Aurora credentials (from the database module)"
  type        = string
}

variable "aurora_database_name" {
  description = "Name of the database inside the Aurora cluster that holds the vector table (must match the database module's aws_rds_cluster.database_name, which is \"edumind\")"
  type        = string
  default     = "edumind"
}

variable "curriculum_bucket_arn" {
  description = "ARN of the curriculum S3 bucket (from the storage module)"
  type        = string
}

variable "curriculum_bucket_id" {
  description = "Name/ID of the curriculum S3 bucket (from the storage module)"
  type        = string
}

variable "district_001_kms_key_arn" {
  description = "ARN of the district_001 KMS key (from the storage module) — the curriculum bucket's default SSE-KMS key; the KB role needs kms:Decrypt to read any object encrypted with it"
  type        = string
}

variable "district_002_kms_key_arn" {
  description = "ARN of the district_002 KMS key (from the storage module) — required for objects under the district-002/ prefix, which the bucket policy forces to use this key"
  type        = string
}

variable "tags" {
  description = "Common tags applied to every resource"
  type        = map(string)
}
