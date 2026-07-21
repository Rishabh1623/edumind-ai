# Populated incrementally as each module is wired into main.tf.
# Remaining target set (per project spec):
#   - CloudFront domain name    (presentation module)

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

output "opensearch_collection_endpoint" {
  description = "Endpoint of the OpenSearch Serverless collection"
  value       = module.search.collection_endpoint
}
