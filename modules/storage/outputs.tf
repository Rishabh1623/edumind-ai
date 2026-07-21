output "curriculum_bucket_name" {
  description = "Name of the curriculum S3 bucket"
  value       = aws_s3_bucket.curriculum.id
}

output "curriculum_bucket_arn" {
  description = "ARN of the curriculum S3 bucket"
  value       = aws_s3_bucket.curriculum.arn
}

output "audit_logs_bucket_name" {
  description = "Name of the audit logs S3 bucket"
  value       = aws_s3_bucket.audit_logs.id
}

output "audit_logs_bucket_arn" {
  description = "ARN of the audit logs S3 bucket"
  value       = aws_s3_bucket.audit_logs.arn
}

output "district_001_kms_key_arn" {
  description = "ARN of the district_001 KMS key"
  value       = aws_kms_key.district_001.arn
}

output "district_002_kms_key_arn" {
  description = "ARN of the district_002 KMS key"
  value       = aws_kms_key.district_002.arn
}
