resource "aws_cloudwatch_log_group" "application" {
  name              = "/edumind/application"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "edumind-application-logs"
  })
}

resource "aws_cloudwatch_log_group" "alb" {
  name              = "/edumind/alb"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "edumind-alb-logs"
  })
}

resource "aws_cloudwatch_log_group" "agent" {
  name              = "/edumind/agent"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "edumind-agent-logs"
  })
}

resource "aws_sns_topic" "alerts" {
  name = "edumind-alerts"

  tags = merge(var.common_tags, {
    Name = "edumind-alerts"
  })
}

# CloudTrail's CreateTrail call validates that the target bucket's policy
# already grants it write access, so the policy must exist *before* the
# trail resource, which means it can't reference the trail's own ARN via a
# live Terraform reference (that would be circular). The trail ARN is
# deterministic, though, so it's constructed as a plain string here and the
# trail resource depends_on the policy explicitly to guarantee ordering.
locals {
  trail_arn = "arn:aws:cloudtrail:${var.aws_region}:${var.account_id}:trail/edumind-trail"
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [var.audit_logs_bucket_arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${var.audit_logs_bucket_arn}/AWSLogs/${var.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = var.audit_logs_bucket_name
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

resource "aws_cloudtrail" "main" {
  name                          = "edumind-trail"
  s3_bucket_name                = var.audit_logs_bucket_name
  is_multi_region_trail         = false
  include_global_service_events = true
  enable_log_file_validation    = true

  tags = merge(var.common_tags, {
    Name = "edumind-trail"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_rate" {
  alarm_name          = "edumind-alb-5xx-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 1
  alarm_description   = "ALB 5xx rate exceeds 1%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "rate"
    expression  = "(errors5xx / requests) * 100"
    label       = "5xx Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors5xx"
    metric {
      metric_name = "HTTPCode_ELB_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id = "requests"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  tags = merge(var.common_tags, {
    Name = "edumind-alb-5xx-rate-high"
  })
}

resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  alarm_name          = "edumind-asg-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ASG average CPU exceeds 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = merge(var.common_tags, {
    Name = "edumind-asg-cpu-high"
  })
}

resource "aws_cloudwatch_metric_alarm" "aurora_connections_high" {
  alarm_name          = "edumind-aurora-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora connections exceed 80"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_identifier
  }

  tags = merge(var.common_tags, {
    Name = "edumind-aurora-connections-high"
  })
}

# CloudWatch dashboards do not support the `tags` argument in AWS.
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "edumind-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 300 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB 5xx Count"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 300 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ASG CPU Utilization"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name, { stat = "Average", period = 300 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Aurora CPU Utilization"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.aurora_cluster_identifier, { stat = "Average", period = 300 }]
          ]
        }
      }
    ]
  })
}
