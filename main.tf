terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = "Rishabh1623"
  }
}

module "networking" {
  source = "./modules/networking"

  common_tags = local.common_tags
}

module "identity" {
  source = "./modules/identity"

  account_id  = var.account_id
  common_tags = local.common_tags
}

module "storage" {
  source = "./modules/storage"

  account_id  = var.account_id
  common_tags = local.common_tags
}

module "database" {
  source = "./modules/database"

  common_tags           = local.common_tags
  private_subnet_ids    = module.networking.private_subnet_ids
  rds_security_group_id = module.networking.sg_rds_id
}

module "application" {
  source = "./modules/application"

  common_tags              = local.common_tags
  vpc_id                   = module.networking.vpc_id
  public_subnet_ids        = module.networking.public_subnet_ids
  private_subnet_ids       = module.networking.private_subnet_ids
  alb_security_group_id    = module.networking.sg_alb_id
  app_security_group_id    = module.networking.sg_app_id
  aurora_secret_arn        = module.database.aurora_secret_arn
  district_001_kms_key_arn = module.storage.district_001_kms_key_arn
  district_002_kms_key_arn = module.storage.district_002_kms_key_arn
}

# Deliberately not deployed right now: OpenSearch Serverless has no
# scale-to-zero floor (~4 OCU minimum billed 24/7) and Phase 1 has no
# RAG/indexing code that would use it yet. Destroyed on 2026-07-22 to stop
# the idle cost; re-enable this block before starting Phase 2.
# module "search" {
#   source = "./modules/search"
#
#   common_tags                  = local.common_tags
#   vpc_id                       = module.networking.vpc_id
#   private_subnet_ids           = module.networking.private_subnet_ids
#   opensearch_security_group_id = module.networking.sg_opensearch_id
#   app_role_arn                 = module.application.app_role_arn
# }

module "presentation" {
  source = "./modules/presentation"

  account_id  = var.account_id
  common_tags = local.common_tags
}

module "observability" {
  source = "./modules/observability"

  aws_region                = var.aws_region
  account_id                = var.account_id
  common_tags               = local.common_tags
  audit_logs_bucket_name    = module.storage.audit_logs_bucket_name
  audit_logs_bucket_arn     = module.storage.audit_logs_bucket_arn
  alb_arn_suffix            = module.application.alb_arn_suffix
  asg_name                  = module.application.asg_name
  aurora_cluster_identifier = module.database.aurora_cluster_identifier
}
