# Populated incrementally as each module is wired into main.tf.
# Remaining target set (per project spec):
#   - ALB DNS name              (application module)
#   - CloudFront domain name    (presentation module)
#   - OpenSearch collection endpoint (search module)

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
