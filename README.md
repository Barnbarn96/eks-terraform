# eks-platform-infra

Terraform for an ephemeral, production-shaped EKS lab (VPC, EKS, IAM, ArgoCD bootstrap).
Cluster state lives in the companion `eks-platform-gitops` repo.

## Layout

| Path | What |
|---|---|
| `bootstrap/` | One-time, long-lived: S3 state bucket, AWS Budget alerts. Local state. |
| `envs/lab/` | The ephemeral lab environment (remote state in S3). |
| `modules/` | `network`, `cluster`, `platform-iam`, `argocd-bootstrap` (added from Phase 1). |
| `scripts/` | `up.sh`, `down.sh`, `leak-check.sh` (added from Phase 1). |
| `docs/` | ADRs, runbooks, postmortems, upgrade log. |

## First-time setup (Phase 0)

```sh
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set budget_email
terraform init
terraform plan
terraform apply
# Confirm the AWS Budgets subscription email if one arrives

cd ../envs/lab
terraform init     # should configure the S3 backend
terraform apply    # creates nothing; prints account_id to prove state + creds work
```

Every resource is tagged `project=eks-lab`.
