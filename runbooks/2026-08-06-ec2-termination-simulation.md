# Incident runbook: simulated EC2 instance failure

**Date:** 2026-08-06
**Type:** Planned simulation (manual instance termination)
**Impact:** None — application remained available throughout via the second AZ
**Status:** Resolved (automatically)

## Summary

To validate the self-healing design of this platform, I manually terminated
one of the two running EC2 instances behind the Application Load Balancer,
simulating an unplanned instance failure (crash, underlying hardware issue,
etc.). This runbook documents what was observed, in the order it happened,
using timestamps pulled directly from the AWS console (CloudWatch, Lambda
logs, and ASG activity history).

## Environment at time of incident

- ASG: `aws-ha-platform-asg`, desired capacity 2, spanning `us-east-1a` and `us-east-1b`
- Target group: `aws-ha-platform-tg`, 2/2 healthy before the test
- Instance terminated: `i-0abe98c5b9a0c88b2` (`us-east-1a`)

## Timeline

All times UTC unless noted.

| Time | Event | Source |
|---|---|---|
| 12:20:08 | Instance `i-0abe98c5b9a0c88b2` manually terminated via EC2 console | EC2 console action |
| 12:20:08 | ASG's own EC2 health check detects the instance is gone and marks it for replacement (*"an instance was taken out of service in response to an EC2 health check indicating it has been terminated or stopped"*) | ASG Activity history |
| ~12:20:10 | ASG launches replacement instance `i-0e207982a26cd870b` (*"an instance was launched in response to an unhealthy instance needing to be replaced"*) | ASG Activity history |
| 12:23:55 | CloudWatch alarm `aws-ha-platform-unhealthy-hosts` transitions to `ALARM` | CloudWatch console |
| 12:23:55 | SNS publishes the alarm notification to the `aws-ha-platform-alerts` topic, invoking the Lambda subscriber | SNS / Lambda logs |
| 12:23:56 | Lambda (`aws-ha-platform-auto-remediate`) queries the target group for unhealthy targets, finds none (`Unhealthy targets: []`) | CloudWatch Logs |
| 12:23:56 | Lambda logs `"No unhealthy targets found - alarm may have self-resolved"` and exits cleanly | CloudWatch Logs |
| ~12:33 | Replacement instance passes health checks; target group back to 2/2 healthy | Target group console |

## What actually drove recovery

The recovery was handled by the **ASG's native EC2 health check**, not the
Lambda. When an instance is terminated, AWS deregisters it from the target
group almost immediately — by the time the CloudWatch alarm fired and the
Lambda ran (about 4 minutes later, gated by the alarm's evaluation period),
there was no "unhealthy" target left for it to act on. The Lambda correctly
identified this and logged it rather than taking any action.

This is expected, and it's a useful distinction to be able to explain:

- **Hard failures** (instance terminated, stopped, or otherwise deregistered)
  are caught by the ASG's own health check and require no custom code.
- **Soft failures** (instance still running but failing ALB health checks —
  e.g. the app has hung, is out of memory, or is returning 5xxs) are the
  case the Lambda is actually built for: the instance stays registered and
  shows as `unhealthy` in the target group, which is exactly what
  `get_unhealthy_instance_ids()` looks for.

Both paths converge on the same outcome (ASG replaces the bad instance),
they just start from different triggers.

## Impact

None. The ALB continued routing traffic to the healthy instance in
`us-east-1b` for the entire ~13 minutes it took the replacement to launch
and pass health checks. This was confirmed by repeatedly loading the app
during the test and seeing consistent `200 OK` responses.

## Follow-ups / improvements identified

- The Lambda's current logic only handles the "soft failure" case. A more
  complete version could also react to `EC2 Instance Terminate Successful`
  events directly (via EventBridge) to log a unified incident timeline
  regardless of which failure mode occurred.
- Alarm evaluation period (currently 1 minute, 1 datapoint) means there's a
  multi-minute gap between the actual failure and the alarm firing. For
  faster detection this could be tightened, at the cost of more sensitivity
  to transient blips.
- No alerting currently fires on successful auto-recovery (only on the
  breach). Adding an `OK` state notification would give clearer visibility
  into "problem happened and was already fixed" versus needing to check
  manually.

## Screenshots

See `../screenshots/`:
- `07-before-healthy-targets.png` — baseline, 2/2 healthy
- `08-before-terminate.png` — both instances running prior to the test
- `09-alarm-triggered.png` — CloudWatch alarm in ALARM state
- `11-lambda-remediation-logs.png` — Lambda execution log for this incident
- `12-asg-replacement.png` — ASG activity history showing termination + replacement
