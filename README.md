# rds-patch-scheduler
# RDS Patch Automation

This project automates weekly OS patching for Amazon RDS instances using AWS Lambda and Terraform.

## 🔧 Components
- **Lambda Function**: `rds-patch-scheduler`
- **Trigger**: EventBridge (`cron(55 14 ? * FRI *)`)
- **Notifications**: SNS email alerts with color-coded patch summaries

## 🟩 Emoji Legend
- ✅ Patch scheduled
- 🟦 Maintenance pending, but no system-update
- 🟩 No pending maintenance

## 📦 Deployment
1. Zip the Lambda script:
   ```bash
   zip lambda.zip lambda_function.py
