# ADR-001: Ephemeral lab environment and project scope

**Status:** Proposed   **Date:** YYYY-MM-DD

## Context

<!-- Fill in, in your own words:
- The goal: hands-on evidence of operating production-shaped EKS (upgrades, drains, failure drills).
- The constraint: personal budget (target < US$50 total), so a 24/7 cluster isn't viable.
- The EKS control plane, NAT gateway and nodes bill hourly whether or not they're used.
-->

## Decision

<!-- Suggested starting point — edit to match what you actually believe:
- The cluster exists only during work sessions; it is destroyed at the end of every session.
- Everything must rebuild from `terraform apply` + ArgoCD sync with no console clicks.
- Long-lived, near-free resources stay up: S3 state bucket, budget, Route 53 hosted zone, ECR.
- Region us-east-1, one dedicated AWS account, all resources tagged project=eks-lab.
-->

## Out of scope

<!-- e.g. multi-account / multi-region, service mesh, multi-tenant RBAC, compliance controls,
     running 24/7, HA NAT per AZ (see a later ADR). Say WHY each is out. -->

## Alternatives considered

<!-- e.g. always-on cluster; KIND/minikube only; EKS Auto Mode; a managed sandbox. Why not each? -->

## Consequences (incl. what production would do differently)

<!-- Positive: forces fully reproducible IaC, cheap, teardown becomes its own learning.
     Negative: ~20–25 min spin-up per session; no long-running drift or real traffic history;
     controller-created resources (ALBs, EBS, DNS records) must be cleaned up in order.
     Production: long-lived clusters, separate accounts per env, change windows, etc. -->
