resource "aws_kms_key" "district_001" {
  description             = "KMS key for district_001 data encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "edumind-district-001-key"
  })
}

resource "aws_kms_alias" "district_001" {
  name          = "alias/edumind-district-001-key"
  target_key_id = aws_kms_key.district_001.key_id
}

resource "aws_kms_key" "district_002" {
  description             = "KMS key for district_002 data encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "edumind-district-002-key"
  })
}

resource "aws_kms_alias" "district_002" {
  name          = "alias/edumind-district-002-key"
  target_key_id = aws_kms_key.district_002.key_id
}

resource "aws_s3_bucket" "curriculum" {
  bucket = "edumind-curriculum-${var.account_id}"

  tags = merge(var.common_tags, {
    Name = "edumind-curriculum-${var.account_id}"
  })
}

resource "aws_s3_bucket_versioning" "curriculum" {
  bucket = aws_s3_bucket.curriculum.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "curriculum" {
  bucket = aws_s3_bucket.curriculum.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket-level default encryption can only reference a single KMS key, so it
# is set to the district_001 key as a baseline. Real per-district key
# isolation is enforced at write time by the bucket policy below, which
# denies PutObject under each district's prefix unless the request specifies
# that district's own KMS key.
resource "aws_s3_bucket_server_side_encryption_configuration" "curriculum" {
  bucket = aws_s3_bucket.curriculum.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.district_001.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "curriculum" {
  bucket = aws_s3_bucket.curriculum.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}

data "aws_iam_policy_document" "curriculum" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.curriculum.arn,
      "${aws_s3_bucket.curriculum.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "RequireDistrict001KeyUnderDistrict001Prefix"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.curriculum.arn}/district-001/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.district_001.arn]
    }
  }

  statement {
    sid    = "RequireDistrict002KeyUnderDistrict002Prefix"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.curriculum.arn}/district-002/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.district_002.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "curriculum" {
  bucket = aws_s3_bucket.curriculum.id
  policy = data.aws_iam_policy_document.curriculum.json
}

resource "aws_s3_bucket" "audit_logs" {
  bucket = "edumind-audit-logs-${var.account_id}"

  tags = merge(var.common_tags, {
    Name = "edumind-audit-logs-${var.account_id}"
  })
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The observability module attaches the CloudTrail-specific bucket policy
# (granting the cloudtrail.amazonaws.com service principal write access)
# once the trail exists, so that resource owns its own policy statement.
