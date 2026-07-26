"""
Auto-remediation function for the aws-ha-platform project.

Triggered by an SNS notification whenever the "unhealthy-hosts" CloudWatch
alarm fires. Looks up which instance(s) in the target group are unhealthy
and sets their ASG health status to Unhealthy, which tells the Auto Scaling
Group to terminate and replace them automatically - no human has to SSH in
at 2am to bounce a box.

Everything is logged to CloudWatch Logs so the whole remediation is
traceable after the fact (this log output is what the incident runbook
screenshots reference).
"""
import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

asg_client = boto3.client("autoscaling")
elbv2_client = boto3.client("elbv2")

TARGET_GROUP_ARN = os.environ["TARGET_GROUP_ARN"]
ASG_NAME = os.environ["ASG_NAME"]


def handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    for record in event.get("Records", []):
        message = json.loads(record["Sns"]["Message"])
        alarm_name = message.get("AlarmName", "unknown")
        new_state = message.get("NewStateValue", "unknown")
        logger.info("Alarm '%s' is now %s", alarm_name, new_state)

        if new_state != "ALARM":
            logger.info("Not in ALARM state, nothing to do.")
            continue

        unhealthy_instance_ids = get_unhealthy_instance_ids()

        if not unhealthy_instance_ids:
            logger.info("No unhealthy targets found - alarm may have self-resolved.")
            continue

        for instance_id in unhealthy_instance_ids:
            remediate_instance(instance_id)

    return {"statusCode": 200}


def get_unhealthy_instance_ids():
    response = elbv2_client.describe_target_health(TargetGroupArn=TARGET_GROUP_ARN)
    unhealthy = [
        t["Target"]["Id"]
        for t in response["TargetHealthDescriptions"]
        if t["TargetHealth"]["State"] == "unhealthy"
    ]
    logger.info("Unhealthy targets: %s", unhealthy)
    return unhealthy


def remediate_instance(instance_id):
    logger.info("Marking instance %s unhealthy in ASG %s", instance_id, ASG_NAME)
    asg_client.set_instance_health(
        InstanceId=instance_id,
        HealthStatus="Unhealthy",
        ShouldRespectGracePeriod=False,
    )
    logger.info(
        "Instance %s marked unhealthy - ASG will terminate and replace it.",
        instance_id,
    )
