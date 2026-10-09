variable "cluster_name" {
  description = "EKS cluster the Pod Identity associations attach to"
  type        = string
}

variable "secrets_prefix" {
  description = "Secrets Manager name prefix External Secrets may read (e.g. eks-lab/*)"
  type        = string
}
