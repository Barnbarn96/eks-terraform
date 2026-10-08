variable "name" {
  description = "Name prefix for the VPC and its resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used for Karpenter subnet discovery tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across (2 for the lab)"
  type        = list(string)
}
