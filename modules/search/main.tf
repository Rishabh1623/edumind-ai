# OpenSearch Serverless removed — replaced by pgvector on Aurora
# Reason: $700+/month fixed cost not justified for EdTech startup
# RAG implemented via Bedrock Knowledge Base + Aurora pgvector
# See modules/rag/ for implementation

# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }
#
# resource "aws_opensearchserverless_security_policy" "encryption" {
#   name = "edumind-curriculum-encryption"
#   type = "encryption"
#
#   policy = jsonencode({
#     Rules = [
#       {
#         ResourceType = "collection"
#         Resource     = ["collection/edumind-curriculum"]
#       }
#     ]
#     AWSOwnedKey = true
#   })
# }
#
# # VPC endpoints and security/access policies do not support the `tags`
# # argument in the OpenSearch Serverless provider resources — only the
# # collection itself does.
# resource "aws_opensearchserverless_vpc_endpoint" "main" {
#   name               = "edumind-opensearch-vpce"
#   vpc_id             = var.vpc_id
#   subnet_ids         = var.private_subnet_ids
#   security_group_ids = [var.opensearch_security_group_id]
# }
#
# resource "aws_opensearchserverless_security_policy" "network" {
#   name = "edumind-curriculum-network"
#   type = "network"
#
#   policy = jsonencode([
#     {
#       Rules = [
#         {
#           ResourceType = "collection"
#           Resource     = ["collection/edumind-curriculum"]
#         }
#       ]
#       AllowFromPublic = false
#       SourceVPCEs     = [aws_opensearchserverless_vpc_endpoint.main.id]
#     }
#   ])
# }
#
# resource "aws_opensearchserverless_access_policy" "data" {
#   name = "edumind-curriculum-data-access"
#   type = "data"
#
#   policy = jsonencode([
#     {
#       Rules = [
#         {
#           ResourceType = "collection"
#           Resource     = ["collection/edumind-curriculum"]
#           Permission   = ["aoss:*"]
#         },
#         {
#           ResourceType = "index"
#           Resource     = ["index/edumind-curriculum/*"]
#           Permission   = ["aoss:*"]
#         }
#       ]
#       Principal = [var.app_role_arn]
#     }
#   ])
# }
#
# resource "aws_opensearchserverless_collection" "curriculum" {
#   name = "edumind-curriculum"
#   type = "VECTORSEARCH"
#
#   tags = merge(var.common_tags, {
#     Name = "edumind-curriculum"
#   })
#
#   depends_on = [
#     aws_opensearchserverless_security_policy.encryption,
#     aws_opensearchserverless_security_policy.network,
#   ]
# }
