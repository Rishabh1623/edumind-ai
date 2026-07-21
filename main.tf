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
