output "cognito_user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = module.identity.user_pool_id
}

output "cognito_app_client_id" {
  description = "ID of the Cognito app client"
  value       = module.identity.app_client_id
}

output "aurora_cluster_endpoint" {
  description = "Writer endpoint of the Aurora cluster"
  value       = module.database.aurora_cluster_endpoint
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB sessions table"
  value       = module.database.dynamodb_table_name
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.application.alb_dns_name
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.presentation.cloudfront_domain_name
}

output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = module.rag.knowledge_base_id
}

output "ingestion_lambda_arn" {
  description = "ARN of the curriculum ingestion Lambda function"
  value       = module.rag.ingestion_lambda_arn
}
