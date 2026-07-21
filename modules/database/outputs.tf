output "dynamodb_table_name" {
  description = "Name of the DynamoDB sessions table"
  value       = aws_dynamodb_table.sessions.name
}

output "aurora_cluster_endpoint" {
  description = "Writer endpoint of the Aurora cluster"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Reader endpoint of the Aurora cluster"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_secret_arn" {
  description = "ARN of the Secrets Manager secret holding Aurora master credentials"
  value       = aws_secretsmanager_secret.aurora_credentials.arn
}

output "aurora_cluster_identifier" {
  description = "Cluster identifier of the Aurora cluster, used as the DBClusterIdentifier dimension in CloudWatch metrics"
  value       = aws_rds_cluster.aurora.cluster_identifier
}
