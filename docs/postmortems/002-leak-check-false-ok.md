# PM-002: leak-check.sh reported "ok" for a check that never ran

**Date:** 2026-11-21   **Duration:** detected on the first full teardown; latent since the log group check was added (commit `8a3e20e`)   **Severity:** S4 (would be S3 in prod: a safety check that can't fail)

## Summary
After the first full `down.sh`, `leak-check.sh` printed `ok` for "EKS control plane log groups", but an AWS CLI error appeared just above that line. Git Bash had rewritten the log group prefix `/aws/eks/eks-lab/` into a Windows path, so the call was rejected. The script only checked whether output was empty, so "the command failed" looked the same as "nothing found". The check could never have detected a leaked log group. Fixed by disabling Git Bash path conversion and making any failed AWS call fail the whole script.

## Impact
- No actual leak: a manual check showed no `/aws/eks/eks-lab/` log groups.
- The risk was real, though: the log group check exists because EKS can recreate its log group after destroy, with no retention, and keep storing data. That would have gone unnoticed indefinitely.
- More broadly, **every** check in the script had the same flaw. An expired SSO token or a throttled call would also have produced "Clean."

## Timeline
| Time | Event |
|---|---|
| — | `down.sh` completes; `leak-check.sh` runs and reports `==> Clean.` |
| — | Re-ran `leak-check.sh` to verify; noticed `InvalidParameterException … logGroupNamePrefix` printed right before `ok    EKS control plane log groups` |
| — | Re-ran the same AWS call with `MSYS_NO_PATHCONV=1`: succeeds, returns no log groups (so no real leak) |
| — | Script fixed; re-run is clean; simulated failure (invalid region) now exits 2 |

## Root cause
Two bugs combined:

1. **Path mangling.** MSYS (Git Bash on Windows) converts arguments that look like Unix paths into Windows paths before passing them to native programs. `--log-group-name-prefix "/aws/eks/eks-lab/"` became something like `C:/Program Files/Git/aws/eks/eks-lab/`, which fails CloudWatch's name validation:
   ```
   InvalidParameterException ... Value at 'logGroupNamePrefix' failed to satisfy
   constraint: Member must satisfy regular expression pattern: [\.\-_/#A-Za-z0-9]+
   ```
2. **Fail-open check design.** Each check was `check "label" "$(aws ...)"`. A failing `aws` command writes to stderr and returns nothing on stdout, and `check` treats empty output as "no leak". The exit status was never looked at.

Bug 1 triggered it; bug 2 is the real problem, because it affected every check.

## Detection
By chance: the stderr line happened to be visible next to the `ok`. When `leak-check.sh` runs at the end of `down.sh`, that line is easy to miss in the scroll. Nothing in the script's exit code or summary showed that anything was wrong.

## What went well / what was hard
- **Went well:** reading the output instead of trusting the summary line. Verifying by hand before calling it a false alarm.
- **Hard:** the script was "tested" by seeing it print `ok` on a clean account, which is exactly what a broken check also prints.
- **Lesson:** a safety check must **fail closed**. If it can't run, it must not report success. Test checks by proving they *can* fail, not just that they pass.

## Action items
- [x] `export MSYS_NO_PATHCONV=1` in `leak-check.sh`
- [x] Wrap `aws` so any failed call is recorded; the script exits **2** with `CHECKS FAILED to run` and names the failed calls
- [x] Verified: clean run exits 0, and a simulated failure (bad region) exits 2
- [ ] Review `up.sh` / `down.sh` for other Unix-style path arguments passed to native tools on Windows
- [ ] When ExternalDNS lands (Phase 3), add its record check and test it by deliberately leaving a record behind

## Interview notes
"My teardown leak check had a check that could never fail. On Windows, Git Bash rewrote a CloudWatch log group prefix into a Windows path, so the AWS call errored. The script only looked at output, not the exit code, so an error looked like 'nothing found' and printed ok. I spotted the error line just above the ok. The fix wasn't just the path issue: I made the script fail closed, so any check that can't run fails the whole script, and I tested it by forcing a failure. The lesson I took is that you don't trust a safety check until you've seen it fail."
