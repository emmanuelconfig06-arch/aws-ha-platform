output "alb_dns_name" {
  description = "Public URL of the load balancer - open this in a browser once applied"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "RDS connection endpoint"
  value       = aws_db_instance.main.endpoint
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}
