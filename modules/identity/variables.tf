variable "account_id" {
  description = "AWS account ID, used to make the Cognito domain prefix globally unique"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to every resource"
  type        = map(string)
}
