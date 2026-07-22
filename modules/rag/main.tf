terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

data "aws_caller_identity" "current" {}

# 1. IAM role for Bedrock Knowledge Base
resource "aws_iam_role" "bedrock_kb_role" {
  name = "edumind-bedrock-kb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "kb_invoke_embedding_model" {
  name = "edumind-kb-invoke-embedding-model"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel"]
      Resource = ["arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"]
    }]
  })
}

resource "aws_iam_role_policy" "kb_rds_data_access" {
  name = "edumind-kb-rds-data-access"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      # rds:DescribeDBClusters is required alongside the Data API actions —
      # confirmed live: CreateKnowledgeBase failed with an AccessDenied on
      # exactly this action when it was missing (Bedrock validates the
      # cluster's config before accepting the storage configuration).
      Action   = ["rds-data:ExecuteStatement", "rds-data:BatchExecuteStatement", "rds:DescribeDBClusters"]
      Resource = [var.aurora_cluster_arn]
    }]
  })
}

resource "aws_iam_role_policy" "kb_secrets_access" {
  name = "edumind-kb-secrets-access"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.aurora_secret_arn]
    }]
  })
}

resource "aws_iam_role_policy" "kb_s3_access" {
  name = "edumind-kb-s3-access"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${var.curriculum_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [var.curriculum_bucket_arn]
      }
    ]
  })
}

# 2. Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "curriculum" {
  name     = "edumind-curriculum-kb"
  role_arn = aws_iam_role.bedrock_kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }

  storage_configuration {
    type = "RDS"
    rds_configuration {
      resource_arn           = var.aurora_cluster_arn
      credentials_secret_arn = var.aurora_secret_arn
      database_name          = var.aurora_database_name
      table_name             = "curriculum_embeddings"
      field_mapping {
        primary_key_field = "id"
        vector_field      = "embedding"
        text_field        = "content"
        metadata_field    = "metadata"
      }
    }
  }

  tags = var.tags

  # Bedrock validates the RDS backend (extension + table) when the
  # knowledge base is created, so modules/rag/schema.sql must already be
  # applied to the Aurora database before this resource is created —
  # otherwise CreateKnowledgeBase fails outright. This can't be expressed as
  # a Terraform dependency since the schema is applied via the RDS Data API,
  # outside Terraform's graph.
}

# 3. Bedrock Data Source — S3
resource "aws_bedrockagent_data_source" "curriculum_s3" {
  name              = "edumind-curriculum-s3"
  knowledge_base_id = aws_bedrockagent_knowledge_base.curriculum.id

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.curriculum_bucket_arn
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 512
        overlap_percentage = 10
      }
    }
  }
}

# 4. IAM role for ingestion Lambda
resource "aws_iam_role" "ingestion_lambda_role" {
  name = "edumind-ingestion-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "edumind-ingestion-lambda-s3-access"
  role = aws_iam_role.ingestion_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["${var.curriculum_bucket_arn}/*"]
    }]
  })
}

resource "aws_iam_role_policy" "lambda_start_ingestion" {
  name = "edumind-ingestion-lambda-start-ingestion"
  role = aws_iam_role.ingestion_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:StartIngestionJob"]
      Resource = [aws_bedrockagent_knowledge_base.curriculum.arn]
    }]
  })
}

resource "aws_iam_role_policy" "lambda_logs" {
  name = "edumind-ingestion-lambda-logs"
  role = aws_iam_role.ingestion_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = [
        "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/edumind-curriculum-ingestion:*"
      ]
    }]
  })
}

# 5. Lambda function — curriculum ingestion trigger
data "archive_file" "ingestion_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

resource "aws_lambda_function" "curriculum_ingestion" {
  function_name = "edumind-curriculum-ingestion"
  role          = aws_iam_role.ingestion_lambda_role.arn
  runtime       = "python3.12"
  handler       = "index.handler"
  timeout       = 60

  filename         = data.archive_file.ingestion_lambda.output_path
  source_code_hash = data.archive_file.ingestion_lambda.output_base64sha256

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.curriculum.id
      DATA_SOURCE_ID    = aws_bedrockagent_data_source.curriculum_s3.data_source_id
    }
  }

  tags = var.tags
}

# 6. S3 event notification -> Lambda
resource "aws_s3_bucket_notification" "curriculum_upload" {
  bucket = var.curriculum_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.curriculum_ingestion.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# 7. Lambda permission for S3 to invoke it
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.curriculum_ingestion.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.curriculum_bucket_arn
}
