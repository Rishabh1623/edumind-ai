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

module "search" {
  source = "./modules/search"

  common_tags                  = local.common_tags
  vpc_id                       = module.networking.vpc_id
  private_subnet_ids           = module.networking.private_subnet_ids
  opensearch_security_group_id = module.networking.sg_opensearch_id
  app_role_arn                 = module.application.app_role_arn
}
