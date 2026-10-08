variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version (start one behind latest so there's a real upgrade to do)"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "Subnets for the control plane ENIs and worker nodes"
  type        = list(string)
}

variable "admin_principal_arns" {
  description = "IAM role ARNs granted cluster-admin through EKS access entries"
  type        = map(string)
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint (tighten to your own IP if you like)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "system_instance_types" {
  description = "Instance types for the system managed node group"
  type        = list(string)
  default     = ["t4g.medium"]
}

variable "system_ami_type" {
  description = "AMI type for the system node group; must match the instance architecture"
  type        = string
  default     = "AL2023_ARM_64_STANDARD"
}

variable "log_retention_days" {
  description = "CloudWatch retention for control plane logs"
  type        = number
  default     = 3
}
