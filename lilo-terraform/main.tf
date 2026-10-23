# PROVIDER — cloud and region
provider "aws" {
  region = "us-east-1"
}

# DYNAMODB TABLE
resource "aws_dynamodb_table" "lilo_practice" {
  name         = "lilo-habits-tf"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "taskId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "taskId"
    type = "S"
  }

  tags = {
    Project   = "LILO"
    ManagedBy = "Terraform"
  }
}

# IAM ROLE — the Lambda's execution role
resource "aws_iam_role" "lilo_lambda_role" {
  name = "lilo-lambda-role-tf"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# IAM POLICY — least-privilege DynamoDB access (inline)
resource "aws_iam_role_policy" "lilo_lambda_dynamo" {
  name = "lilo-lambda-dynamo-tf"
  role = aws_iam_role.lilo_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query"]
      Resource = aws_dynamodb_table.lilo_practice.arn
    }]
  })
}

# DATA SOURCE — zip the handler code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/handler.zip"
}

# LAMBDA FUNCTION
resource "aws_lambda_function" "lilo_fn" {
  function_name    = "lilo-fn-tf"
  role             = aws_iam_role.lilo_lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.lilo_practice.name
    }
  }
}

# API GATEWAY — HTTP API
resource "aws_apigatewayv2_api" "lilo_api" {
  name          = "lilo-api-tf"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lilo_integration" {
  api_id                 = aws_apigatewayv2_api.lilo_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lilo_fn.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lilo_route" {
  api_id    = aws_apigatewayv2_api.lilo_api.id
  route_key = "GET /habits"
  target    = "integrations/${aws_apigatewayv2_integration.lilo_integration.id}"
}

resource "aws_apigatewayv2_stage" "lilo_stage" {
  api_id      = aws_apigatewayv2_api.lilo_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "lilo_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lilo_fn.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lilo_api.execution_arn}/*/*"
}

# OUTPUT — the live URL
output "api_url" {
  value = "${aws_apigatewayv2_stage.lilo_stage.invoke_url}habits"
}

# CLOUDWATCH LOG GROUP — Lambda logs with 14-day retention
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lilo_fn.function_name}"
  retention_in_days = 14
}

# CLOUDWATCH ALARM — fires on any Lambda error
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lilo-fn-errors-tf"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Fires when the LILO Lambda records errors in a 5-min window"
  dimensions = {
    FunctionName = aws_lambda_function.lilo_fn.function_name
  }
}

# IAM — let the Lambda write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lilo_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}