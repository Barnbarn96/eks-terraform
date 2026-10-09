variable "gitops_repo_url" {
  description = "Git repo ArgoCD treats as the source of truth"
  type        = string
}

variable "gitops_revision" {
  description = "Branch / tag / commit the root app tracks"
  type        = string
  default     = "main"
}

variable "root_app_path" {
  description = "Directory in the gitops repo holding the child Application manifests"
  type        = string
  default     = "argocd-apps"
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version (argoproj/argo-helm)"
  type        = string
}

variable "argocd_apps_chart_version" {
  description = "argocd-apps Helm chart version, used only to create the root Application"
  type        = string
}
