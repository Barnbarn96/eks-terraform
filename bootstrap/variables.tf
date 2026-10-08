variable "region" {
  description = "AWS region for the lab"
  type        = string
  default     = "us-east-1"
}

variable "budget_email" {
  description = "Email address that receives AWS Budget alerts"
  type        = string
  default     = "barnabassoh96@gmail.com"
}

variable "budget_limit_usd" {
  description = "Monthly budget ceiling in USD"
  type        = number
  default     = 50
}

variable "budget_alert_thresholds_usd" {
  description = "Actual-spend thresholds (USD) that trigger an email"
  type        = list(number)
  default     = [10, 25, 50]
}
