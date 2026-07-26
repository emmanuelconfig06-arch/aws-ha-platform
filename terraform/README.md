# Terraform

Provisions the full environment: VPC across 2 AZs, ALB, Auto Scaling Group,
RDS Multi-AZ, and CloudWatch/SNS/Lambda auto-remediation.

## Prerequisites

- An AWS account with an IAM user that has programmatic access
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- AWS CLI configured (`aws configure`) with your access key/secret

## Cost warning

This deploys real, billable resources - mainly a NAT gateway (~$32/mo +
data) and an RDS Multi-AZ instance (~$25-30/mo on db.t3.micro). Nothing
here is exotic, but it is **not free tier**. Plan to `terraform destroy`
when you're done taking screenshots, and set up an AWS Budget alarm before
you start (the console has a free option for this).

## How to run

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with a real db_password and your alert_email

terraform init
terraform plan      # review what it's about to create
terraform apply     # type "yes" to confirm
```

When it finishes, grab the `alb_dns_name` output and open it in a browser -
you should see a simple page confirming which instance and AZ served the
request. Refresh a few times and you'll see it round-robin across
instances/AZs.

## Tearing down

```bash
terraform destroy
```

Do this before walking away for the day if you're not actively using it -
these resources bill by the hour/GB regardless of traffic.

## What's intentionally simplified

- Single NAT gateway instead of one per AZ (cost, not correctness)
- HTTP only, no ACM cert/HTTPS listener (would need a real domain)
- `skip_final_snapshot = true` and `deletion_protection = false` on RDS, so
  `terraform destroy` doesn't get stuck - flip both to `true`/`false`
  respectively before treating this as anything beyond a learning project
