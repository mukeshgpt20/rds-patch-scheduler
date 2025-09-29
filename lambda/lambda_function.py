import boto3
import os

def lambda_handler(event, context):
    rds = boto3.client('rds')
    sns = boto3.client('sns')
    topic_arn = os.environ['SNS_TOPIC_ARN']
    messages = []

    instances = rds.describe_db_instances()['DBInstances']

    for db in instances:
        db_arn = db['DBInstanceArn']
        db_id = db['DBInstanceIdentifier']
        pending = rds.describe_pending_maintenance_actions(ResourceIdentifier=db_arn)
        actions = pending.get('PendingMaintenanceActions', [])

        if actions:
            found_patch = False
            for action in actions:
                for detail in action.get('PendingMaintenanceActionDetails', []):
                    if detail['Action'] == 'system-update':
                        rds.apply_pending_maintenance_action(
                            ResourceIdentifier=db_arn,
                            ApplyAction='system-update',
                            OptInType='next-maintenance'
                        )
                        messages.append(f"✅ {db_id}: Patch scheduled")
                        found_patch = True
                        break
            if not found_patch:
                messages.append(f"🟦 {db_id}: Maintenance pending, but no system-update")
        else:
            messages.append(f"🟩 {db_id}: No pending maintenance")

    summary = "**RDS Patch Summary**\n\n" + "\n".join(f"- {msg}" for msg in messages)
    sns.publish(TopicArn=topic_arn, Subject="RDS Patch Summary", Message=summary)

    return {
        "statusCode": 200,
        "body": summary
    }
