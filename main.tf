provider "aws" {
  region = var.region
}

resource "random_pet" "bucket" {}

resource "aws_s3_bucket" "anonymised" {
  bucket        = "meraki-anon-${random_pet.bucket.id}"
  force_destroy = true
}

resource "aws_iam_role" "lambda" {
  name = "meraki_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "lambda" {
  name   = "meraki_lambda_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.anonymised.arn}/*"
        Effect   = "Allow"
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

resource "aws_lambda_function" "collect" {
  function_name = var.collect_lambda_name
  role          = aws_iam_role.lambda.arn
  handler       = "collect.handler"
  runtime       = "python3.9"
  filename      = "lambda/collect.zip"
  source_code_hash = filebase64sha256("lambda/collect.zip")
  environment {
    variables = {
      BUCKET        = aws_s3_bucket.anonymised.bucket
      MERAKI_API_KEY = var.meraki_api_key
      MERAKI_ORG_ID  = var.meraki_org_id
    }
  }
}

resource "aws_lambda_function" "serve" {
  function_name = var.serve_lambda_name
  role          = aws_iam_role.lambda.arn
  handler       = "serve_data.handler"
  runtime       = "python3.9"
  filename      = "lambda/serve_data.zip"
  source_code_hash = filebase64sha256("lambda/serve_data.zip")
  environment {
    variables = {
      BUCKET = aws_s3_bucket.anonymised.bucket
    }
  }
}

resource "aws_api_gateway_rest_api" "api" {
  name = "meraki-data-api"
}

resource "aws_api_gateway_resource" "collect" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "collect"
}

resource "aws_api_gateway_method" "collect_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.collect.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "collect_get" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.collect.id
  http_method = aws_api_gateway_method.collect_get.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = aws_lambda_function.collect.invoke_arn
}

resource "aws_lambda_permission" "collect" {
  statement_id  = "AllowAPIGatewayInvokeCollect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collect.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_resource" "data" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "data"
}

resource "aws_api_gateway_method" "data_get" {
  rest_api_id    = aws_api_gateway_rest_api.api.id
  resource_id    = aws_api_gateway_resource.data.id
  http_method    = "GET"
  authorization  = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "data_get" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.data.id
  http_method = aws_api_gateway_method.data_get.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = aws_lambda_function.serve.invoke_arn
}

resource "aws_lambda_permission" "data" {
  statement_id  = "AllowAPIGatewayInvokeData"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.serve.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deploy" {
  depends_on = [
    aws_api_gateway_integration.collect_get,
    aws_api_gateway_integration.data_get
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.api_stage_name
}

resource "aws_api_gateway_api_key" "user" {
  name = "meraki-user-key"
}

resource "aws_api_gateway_usage_plan" "plan" {
  name = "meraki-plan"
  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_deployment.deploy.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "user" {
  key_id        = aws_api_gateway_api_key.user.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.plan.id
}

