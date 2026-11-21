# PM-001: Karpenter silently launched on-demand instead of spot

**Date:** 2026-11-21   **Duration:** ~1 min from first launch to detection (but latent since the account was created)   **Severity:** S4 (would be S3 in prod: silent cost regression)

## Summary
During the first live Phase 2 test, a Karpenter scale-up test launched a `c6g.xlarge` **on-demand** node, even though the `default` NodePool prefers spot. Karpenter's first launch attempt (spot) failed because the account had no EC2 Spot service-linked role. Karpenter then fell back to on-demand, as the NodePool allows. Nothing failed and no alert fired; it was noticed only because the `CAPACITY` column said `on-demand`. Fixed by creating the service-linked role once in `bootstrap/`.

## Impact
- No user impact (lab, no workloads).
- Cost: every Karpenter node would have run on-demand, which typically costs around 2–3× the spot price for the same instance. In production this is a silent, cluster-wide cost increase that only shows up on the bill.
- Any spot-specific behaviour (interruption handling, Phase 5b drill) would have been impossible to test.

## Timeline (UTC)
| Time | Event |
|---|---|
| ~05:42 | `inflate` deployment scaled to 5 replicas × 1 CPU to force a scale-up |
| 05:42:18 | Karpenter: `failed launching nodeclaim` … `UnfulfillableCapacity` (NodeClaim `default-s2z2s`) |
| 05:42:28 | Karpenter launches NodeClaim `default-rx6gp`: `c6g.xlarge`, **on-demand**, us-east-1b |
| ~05:43 | Noticed `CAPACITY: on-demand` in `kubectl get nodeclaims` |
| ~05:44 | Karpenter logs read; root cause identified from the CreateFleet error |
| later | `aws_iam_service_linked_role.spot` added to `bootstrap/` |

## Root cause
EC2 needs the account-wide service-linked role `AWSServiceRoleForEC2Spot` before anything can launch spot capacity. The console creates it automatically the first time a person launches spot by hand. This account has only ever been managed through Terraform, so the role never existed.

Karpenter's controller role is deliberately not allowed to create IAM roles, so its spot request failed:

```
AuthFailure.ServiceLinkedRoleCreationNotPermitted: The provided credentials do not
have permission to create the service-linked role for EC2 Spot Instances.
(aws-error-code=UnfulfillableCapacity, aws-operation-name=CreateFleet)
```

Karpenter reports this as `UnfulfillableCapacity`, the same category as "no spot capacity available". It treats it as a capacity problem, and because the NodePool allows `["spot", "on-demand"]`, it falls back to on-demand on the next attempt. Confirmed afterwards with `aws iam get-role --role-name AWSServiceRoleForEC2Spot` → `NoSuchEntity`.

## Detection
Manual and lucky: it was spotted by reading one column during a test. Nothing would have alerted:
- Karpenter logs the error at `ERROR`, but nobody watches its logs and the fallback succeeds.
- Budget alerts are monthly and would only catch it after the money was spent.
- No alert compares a node's capacity type with what was intended.

## What went well / what was hard
- **Went well:** the on-demand fallback meant the workload was never blocked. Karpenter's log message named the exact missing permission.
- **Hard:** the error code (`UnfulfillableCapacity`) suggests "AWS has no spot capacity", which is normal and temporary. The real cause (an IAM prerequisite) is only visible in the full error text.
- **Lesson:** "spot + on-demand fallback" improves availability, but it hides spot failures. A fallback that can fire silently needs its own signal.

## Action items
- [x] Create the Spot service-linked role in `bootstrap/` (account-level, survives teardown)
- [ ] Apply `bootstrap/`, then confirm the next Karpenter node comes up as `spot`
- [ ] Phase 4: alert when on-demand Karpenter nodes exist for > 15 min (e.g. on `karpenter_nodes_allocatable` grouped by capacity type), and on Karpenter `failed launching nodeclaim` errors
- [ ] Add "account prerequisites" (service-linked roles, quotas) to ADR-001 or the spin-up runbook, so a fresh account works first time

## Interview notes
"On my first scale-up test, Karpenter launched on-demand instead of spot. Nothing was broken: the NodePool allows on-demand as a fallback, so it just quietly cost more. The logs showed the spot request had failed with `ServiceLinkedRoleCreationNotPermitted`. The account had never launched spot from the console, so the EC2 Spot service-linked role didn't exist, and Karpenter rightly can't create IAM roles. I added the role to the account bootstrap Terraform. The bigger lesson was that a silent fallback hides failures. I'd now alert on unexpected on-demand capacity, not just on things being down."
