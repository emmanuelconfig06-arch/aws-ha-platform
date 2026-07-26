# --- SNS topic for alerts ---
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- CloudWatch alarms ---
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name          = "CPUUtilization"
  namespace            = "AWS/EC2"
  period               = 60
  statistic            = "Average"
  threshold            = 80
  alarm_description    = "Average ASG CPU above 80% for 2 minutes"
  alarm_actions        = [aws_sns_topic.alerts.arn]
  ok_actions            = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project_name}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 1
  metric_name          = "UnHealthyHostCount"
  namespace            = "AWS/ApplicationELB"
  period               = 60
  statistic            = "Average"
  threshold            = 0
  alarm_description    = "One or more targets failing ALB health checks - triggers auto-remediation Lambda"
  alarm_actions        = [aws_sns_topic.alerts.arn]
  ok_actions            = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# --- Lambda auto-remediation ---
data "archive_file" "remediate_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/remediate.py"
  output_path = "${path.module}/lambda/remediate.zip"
}

resource "aws_iam_role" "lambda_remediate" {
  name = "${var.project_name}-lambda-remediate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_remediate.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_remediate_permissions" {
  name = "${var.project_name}-lambda-remediate-policy"
  role = aws_iam_role.lambda_remediate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:DescribeTargetHealth"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["autoscaling:SetInstanceHealth"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "remediate" {
  function_name    = "${var.project_name}-auto-remediate"
  role             = aws_iam_role.lambda_remediate.arn
  handler          = "remediate.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.remediate_lambda.output_path
  source_code_hash = data.archive_file.remediate_lambda.output_base64sha256

  environment {
    variables = {
      TARGET_GROUP_ARN = aws_lb_target_group.app.arn
      ASG_NAME          = aws_autoscaling_group.app.name
    }
  }
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.remediate.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediate.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}
