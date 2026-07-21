# Populated incrementally as each module is wired into main.tf.
# Final target set (per project spec):
#   - ALB DNS name              (application module)
#   - CloudFront domain name    (presentation module)
#   - Cognito user pool ID      (identity module)
#   - Cognito app client ID     (identity module)
#   - Aurora cluster endpoint   (database module)
#   - DynamoDB table name       (database module)
#   - OpenSearch collection endpoint (search module)
