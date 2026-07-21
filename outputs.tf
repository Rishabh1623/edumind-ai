# Populated incrementally as each module is wired into main.tf.
# Remaining target set (per project spec):
#   - ALB DNS name              (application module)
#   - CloudFront domain name    (presentation module)
#   - Aurora cluster endpoint   (database module)
#   - DynamoDB table name       (database module)
#   - OpenSearch collection endpoint (search module)

output "cognito_user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = module.identity.user_pool_id
}

output "cognito_app_client_id" {
  description = "ID of the Cognito app client"
  value       = module.identity.app_client_id
}
