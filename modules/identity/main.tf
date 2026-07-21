resource "aws_cognito_user_pool" "main" {
  name = "edumind-user-pool"

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  schema {
    name                     = "district_id"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                     = "role"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  tags = merge(var.common_tags, {
    Name = "edumind-user-pool"
  })
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "edumind-auth-${var.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_group" "students" {
  name         = "students"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Student users"
}

resource "aws_cognito_user_group" "teachers" {
  name         = "teachers"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Teacher users"
}

resource "aws_cognito_user_group" "administrators" {
  name         = "administrators"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Administrator users"
}

resource "aws_cognito_user_pool_client" "app" {
  name         = "edumind-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # Cognito app clients do not support the `tags` argument — tagging is
  # only available on the user pool itself.
}
