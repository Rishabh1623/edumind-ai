data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "app" {
  name = "edumind-ec2-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "edumind-ec2-app-role"
  })
}

locals {
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonBedrockFullAccess",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonOpenSearchServiceFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(local.managed_policy_arns)
  role       = aws_iam_role.app.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "secrets_and_kms" {
  name = "edumind-secrets-kms-access"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [var.aurora_secret_arn]
      },
      {
        Sid    = "KmsAccess"
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = [
          var.district_001_kms_key_arn,
          var.district_002_kms_key_arn,
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "edumind-ec2-instance-profile"
  role = aws_iam_role.app.name

  tags = merge(var.common_tags, {
    Name = "edumind-ec2-instance-profile"
  })
}

resource "aws_launch_template" "app" {
  name_prefix   = "edumind-launch-template"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.medium"

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = [var.app_security_group_id]

  # Placement across the two private subnets is delegated to the ASG's
  # vpc_zone_identifier below, rather than pinned to a single subnet here,
  # so instances spread across both AZs.
  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tpl", {
    app_py_base64 = filebase64("${path.root}/app/app.py")
  }))

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.common_tags, {
      Name = "edumind-app-instance"
    })
  }

  tags = merge(var.common_tags, {
    Name = "edumind-launch-template"
  })
}

resource "aws_lb" "app" {
  name               = "edumind-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = merge(var.common_tags, {
    Name = "edumind-alb"
  })
}

resource "aws_lb_target_group" "app" {
  name        = "edumind-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, {
    Name = "edumind-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(var.common_tags, {
    Name = "edumind-http-listener"
  })
}

resource "aws_autoscaling_group" "app" {
  name                = "edumind-asg"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.common_tags, { Name = "edumind-asg" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
