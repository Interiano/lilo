# LILO — Serverless Stack (Terraform)

Infrastructure-as-Code for a serverless AWS application, provisioned end-to-end with Terraform: an HTTP API backed by a Lambda function and a DynamoDB table, with least-privilege IAM and CloudWatch monitoring.

## Architecture

    Client (HTTP)
        │
        ▼
    API Gateway (HTTP API) ──▶ Lambda (Python 3.12) ──▶ DynamoDB
                                     │
                                     ▼
                           CloudWatch (logs + error alarm)

A GET request hits API Gateway, which invokes the Lambda. The function uses boto3 to read/write DynamoDB and returns the item as JSON. Logs flow to CloudWatch, and a metric alarm watches for errors.

## Resources provisioned

| Resource | Purpose |
|---|---|
| `aws_dynamodb_table` | Habit data; on-demand billing, `userId` (partition) + `taskId` (sort) |
| `aws_iam_role` + inline policy | Lambda execution role, least-privilege scoped to just this table |
| `aws_lambda_function` | Python handler; reads/writes the table via boto3 |
| `aws_apigatewayv2_*` | HTTP API, integration, route (`GET /habits`), `$default` stage |
| `aws_lambda_permission` | Allows API Gateway to invoke the Lambda |
| `aws_cloudwatch_log_group` | Lambda logs with 14-day retention |
| `aws_cloudwatch_metric_alarm` | Fires on any Lambda error |
| `aws_iam_role_policy_attachment` | Grants the role CloudWatch Logs access |

## Prerequisites
- Terraform >= 1.x
- AWS CLI configured (`aws configure`), region `us-east-1`

## Deploy