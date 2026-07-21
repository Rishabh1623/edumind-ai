output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "sg_alb_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "sg_app_id" {
  description = "Security group ID for the application tier"
  value       = aws_security_group.app.id
}

output "sg_rds_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "sg_opensearch_id" {
  description = "Security group ID for OpenSearch"
  value       = aws_security_group.opensearch.id
}
