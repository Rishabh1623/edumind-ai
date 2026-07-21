variable "account_id" {
  description = "AWS account ID, used to make bucket names globally unique"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to every resource"
  type        = map(string)
}
