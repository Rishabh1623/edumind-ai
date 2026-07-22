output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.curriculum.id
}

output "data_source_id" {
  description = "ID of the Bedrock Knowledge Base's S3 data source"
  value       = aws_bedrockagent_data_source.curriculum_s3.data_source_id
}

output "ingestion_lambda_arn" {
  description = "ARN of the curriculum ingestion Lambda function"
  value       = aws_lambda_function.curriculum_ingestion.arn
}

output "ingestion_lambda_name" {
  description = "Name of the curriculum ingestion Lambda function"
  value       = aws_lambda_function.curriculum_ingestion.function_name
}
