provider "aws" {
    region = "us-east-1"
}

resource "aws_dynamodb_table" "lilo_practice" {
    name = "lilo-habits-tf"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "userId"
    range_key = "taskId"

    attribute {
        name = "userId"
        type = "S"
    }

    attribute {
        name = "taskId"
        type = "S"
    }
    tags = {
        Project = "LILO"
        ManagedBy = "Terraform"
    }
}

resource "aws_iam_role" "lilo_lambda_role" {
    name = "lilo-lambda-role-tf"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = { Service = "lambda.amazonaws.com"}
        }]
    })
}

resource "aws_iam_role_policy" "lilo_lambda_dynamo" {
    name = "lilo-lambda-dynamo-tf"
    role = aws_iam_role.lilo_lambda_role.id 

    policy = jsonencode ({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = ["dynamodb:GetItem","dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:DeleteItem","dynamodb:Query"]
            Resource = aws_dynamodb_table.lilo_practice.arn
        }]
    })
}

data "archive_file" "lambda_zip" {
    type = "zip"
    source_file = "${path.module}/handler.py"
    output_path = "${path.module}/handler.zip"
}

resource "aws_lambda_function" "lilo_fn" {
    function_name = "lilo-fn-tf"
    role = aws_iam_role.lilo_lambda_role.arn
    handler = "handler.lambda_handler"
    runtime = "python3.12"
    filename = data.archive_file.lambda_zip.output_path
    source_code_hash = data.archive_file.lambda_zip.output_base64sha256

    environment {
        variables = {
            TABLE_NAME = aws_dynamodb_table.lilo_practice.name
        }
    }
}

#http api
resource "aws_apigatewayv2_api" "lilo_api" {
    name = "lilo-api-tf"
    protocol_type = "HTTP"
}

#integration - wires api to lambda
resource "aws_apigatewayv2_integration" "lilo_integration" {
    api_id = aws_apigatewayv2_api.lilo_api.id
    integration_type ="AWS_PROXY"
    integration_uri = aws_lambda_function.lilo_fn.invoke_arn
    payload_format_version = "2.0"
}

#route - which request (method + path) goes to that integration
resource "aws_apigatewayv2_route" "lilo_route" {
    api_id = aws_apigatewayv2_api.lilo_api.id
    route_key = "GET /habits"
    target = "integrations/${aws_apigatewayv2_integration.lilo_integration.id}"
}    

#stage - deployment of api. $default auto-deploys on change
resource "aws_apigatewayv2_stage" "lilo_stage" {
    api_id = aws_apigatewayv2_api.lilo_api.id
    name = "$default"
    auto_deploy = true
}

#5 permissions - let's api gateway invoke your lambda (resource-based policy)
resource "aws_lambda_permission" "lilo_apigw" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lilo_fn.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.lilo_api.execution_arn}/*/*"
}

#output - prints the live url after apply so you can call integration
output "api_url" {
    value ="${aws_apigatewayv2_stage.lilo_stage.invoke_url}/habits"
}

