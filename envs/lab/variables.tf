variable "region" {
  description = "AWS region for the lab"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-lab"
}

variable "kubernetes_version" {
  description = "Start one minor behind latest; Phase 5 upgrades it"
  type        = string
  default     = "1.36"
}

variable "azs" {
  description = "Two AZs for the lab. Avoid the AZ mapped to use1-az3, which lacks many newer instance types."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
