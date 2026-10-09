output "karpenter_node_role_name" {
  description = "Referenced by the EC2NodeClass in the gitops repo"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "Referenced by Karpenter's settings.interruptionQueue in the gitops repo"
  value       = module.karpenter.queue_name
}
