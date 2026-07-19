# Self-healing, observable AWS infrastructure platform

A highly-available 3-tier AWS environment, provisioned entirely with Terraform,
with automated failure detection and remediation.

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

Work in progress — see commit history for build order:
1. Repo scaffold (this commit)
2. Terraform: networking + compute
3. Terraform: database + monitoring/remediation
4. Simulated incident + runbook
5. Cost review + final writeup

## Incident highlight

_Coming soon: a documented simulated outage — detection, diagnosis, and
automated resolution — linked here once complete._

## Cost

_Coming soon: monthly cost breakdown and optimization notes._
