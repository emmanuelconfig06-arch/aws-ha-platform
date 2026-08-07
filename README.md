# Self-healing, observable AWS infrastructure platform

A highly-available 3-tier AWS environment, provisioned entirely with Terraform,
with automated failure detection and a documented, tested recovery process.

## Why this project exists

Built to demonstrate practical AWS operations skills — infrastructure as code,
monitoring, incident response, and cost awareness — for cloud support,
infrastructure, sysadmin, and cloud ops roles.

## Architecture

![Architecture diagram](diagrams/architecture.svg)

- VPC spanning 2 Availability Zones
- Public subnets: Application Load Balancer
- Private subnets: EC2 instances in an Auto Scaling Group
- RDS in Multi-AZ configuration (primary + standby)
- CloudWatch alarms → SNS → Lambda auto-remediation
- IAM least-privilege roles, Secrets Manager, GuardDuty enabled

## Repo structure

```
terraform/    Infrastructure as code (VPC, compute, database, monitoring)
runbooks/     Incident response documentation from simulated failures
diagrams/     Architecture diagrams
screenshots/  Console/CLI evidence of the running system
```

## Status

Fully deployed and tested:
1. ✅ Repo scaffold
2. ✅ Architecture diagram
3. ✅ Terraform — deployed live, verified traffic balancing across both AZs
4. ✅ Simulated incident + runbook (see below)
5. ⬜ Cost review + final writeup

## Incident highlight

To validate the self-healing design, I manually terminated a running EC2
instance and traced the full detection/recovery chain through CloudWatch,
Lambda logs, and Auto Scaling Group activity history — including an
unexpected finding about which mechanism actually drove the recovery.

📄 [Full runbook: EC2 termination simulation](runbooks/2026-08-06-ec2-termination-simulation.md)

**Result:** zero downtime. The ALB kept routing traffic to the healthy
instance in the second AZ for the ~13 minutes it took the ASG to launch and
health-check a replacement.

## Cost

_Coming soon: monthly cost breakdown and optimization notes._
