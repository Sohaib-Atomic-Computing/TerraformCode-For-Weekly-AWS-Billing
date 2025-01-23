variable "access_key" {
  description = "AWS Access key to be used in the provider block"
  type        = string
  default     = ""
}

variable "secret_key" {
  description = "AWS Seceret Access key to be used in the provider block"
  type        = string
  default     = ""
}

variable "token" {
  description = "AWS session token to be used in the provider block"
  type        = string
  default     = ""
}

variable "account_name" {
  description = "The account name to be used in the Lambda function"
  type        = string
  default     = "Testing with Terraform"
}

variable "slack_webhook_url" {
  description = "The Slack webhook URL to send notifications"
  type        = string
  default     = "https://hooks.slack.com/services/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"
}
