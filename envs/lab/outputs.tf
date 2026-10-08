output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.cluster.cluster_name
}

output "cluster_version" {
  value = module.cluster.cluster_version
}

output "cluster_endpoint" {
  value = module.cluster.cluster_endpoint
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.cluster.cluster_name}"
}
