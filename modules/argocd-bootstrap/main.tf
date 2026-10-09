# The Terraform -> GitOps handover. Terraform installs ArgoCD and ONE root
# Application; everything else in the cluster comes from the gitops repo.

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  wait    = true
  timeout = 600

  values = [yamlencode({
    global = {
      # Keep ArgoCD on the stable system nodes, not on spot capacity
      nodeSelector = { "node-role" = "system" }
    }

    configs = {
      params = {
        # No ingress for ArgoCD; reach the UI with kubectl port-forward
        "server.insecure" = true
      }

      cm = {
        # Since ArgoCD 1.8, Applications don't report health to their parent,
        # so sync waves in an app-of-apps don't wait for child apps to become
        # Healthy. This restores that, so e.g. the LB controller's webhook is
        # up before anything that creates a Service or Ingress.
        "resource.customizations.health.argoproj.io_Application" = <<-EOT
          hs = {}
          hs.status = "Progressing"
          hs.message = ""
          if obj.status ~= nil and obj.status.health ~= nil then
            hs.status = obj.status.health.status
            if obj.status.health.message ~= nil then
              hs.message = obj.status.health.message
            end
          end
          return hs
        EOT
      }

      repositories = {
        # Karpenter's chart is only published as an OCI artifact on public ECR
        karpenter = {
          name      = "karpenter"
          type      = "helm"
          url       = "public.ecr.aws/karpenter"
          enableOCI = "true"
        }
      }
    }

    # Not needed for a single-user lab with the built-in admin account
    dex = { enabled = false }

    # Phase 4 may turn this on for sync-failure alerts
    notifications = { enabled = false }
  })]
}

resource "helm_release" "root_app" {
  name      = "root-app"
  namespace = "argocd"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  # A separate release because the Application CRD must exist before Helm can
  # create an Application object
  depends_on = [helm_release.argocd]

  values = [yamlencode({
    applications = {
      root = {
        namespace = "argocd"
        project   = "default"

        # Deliberately no resources-finalizer: deleting the root app must not
        # cascade-delete every add-on mid-teardown. down.sh handles ordering.

        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_revision
          path           = var.root_app_path
          directory      = { recurse = true }
        }

        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }

        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
        }
      }
    }
  })]
}
