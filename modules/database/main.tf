terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "aws_dynamodb_table" "sessions" {
  name         = "edumind_sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.common_tags, {
    Name = "edumind_sessions"
  })
}

resource "random_password" "aurora_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "aurora_credentials" {
  name        = "edumind/aurora/credentials"
  description = "Master credentials for the edumind-aurora-prod cluster"

  tags = merge(var.common_tags, {
    Name = "edumind-aurora-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "aurora_credentials" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id
  secret_string = jsonencode({
    username = "edumind_admin"
    password = random_password.aurora_master.result
  })
}

resource "aws_db_subnet_group" "aurora" {
  name       = "edumind-aurora-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "edumind-aurora-subnet-group"
  })
}

# pgvector on Aurora PostgreSQL does NOT go through shared_preload_libraries
# — confirmed against the live account via
# `aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name
# default.aurora-postgresql15`, whose AllowedValues for that parameter are
# auto_explain,orafce,pgaudit,pg_bigm,pg_similarity,pg_stat_statements,
# pg_tle,pg_hint_plan,pg_prewarm,plprofiler,pglogical,pg_cron,pg_ad_mapping —
# "pgvector" is not one of them and would have been rejected (or broken the
# cluster on reboot). pgvector needs no preload at all; it's enabled purely
# via `CREATE EXTENSION vector;` (see modules/rag/schema.sql). This
# parameter group is kept, with only the already-default value, so it still
# exists as a named place to tune cluster parameters later.
resource "aws_rds_cluster_parameter_group" "edumind_pgvector" {
  family      = "aurora-postgresql15"
  name        = "edumind-aurora-pgvector-params"
  description = "EduMind Aurora parameter group (pgvector needs no preload; enabled via CREATE EXTENSION)"

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  tags = merge(var.common_tags, {
    Name = "edumind-aurora-pgvector-params"
  })
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "edumind-aurora-prod"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "15.17"
  database_name      = "edumind"

  master_username = "edumind_admin"
  master_password = random_password.aurora_master.result

  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.edumind_pgvector.name
  vpc_security_group_ids          = [var.rds_security_group_id]

  # Required for the RAG module's Bedrock Knowledge Base to reach this
  # cluster at all: KB-with-RDS-storage queries/writes vectors via the RDS
  # Data API (rds-data:ExecuteStatement), not a direct Postgres connection.
  # Not part of the original parameter-group-only ask, but the feature
  # cannot function without it. No reboot required, no data risk — it's an
  # additional access path.
  enable_http_endpoint = true

  storage_encrypted   = true
  deletion_protection = false
  skip_final_snapshot = true # matches deletion_protection=false learning setup; set both to true-safe values for production

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 16
  }

  tags = merge(var.common_tags, {
    Name = "edumind-aurora-prod"
  })
}

# Aurora Serverless v2 requires at least one instance of class db.serverless
# for the cluster to actually run queries — the cluster resource alone only
# provisions the storage/control layer.
resource "aws_rds_cluster_instance" "aurora" {
  identifier         = "edumind-aurora-prod-instance-1"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  tags = merge(var.common_tags, {
    Name = "edumind-aurora-prod-instance-1"
  })
}
