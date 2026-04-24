# ── infra/serverless/lambda.tf ────────────────────────────────────────────────
# Terraform puro — alternativa ao serverless.yml

variable "project_name"       { default = "lanchonete" }
variable "stage"              { default = "prod" }
variable "region"             { default = "sa-east-1" }
variable "lambda_zip_path"    { default = "../../lambda.zip" }
variable "sg_lambda_id"       {}
variable "private_subnet_ids" { type = list(string) }

# ── Lambda Function ───────────────────────────────────────────────────────────
resource "aws_lambda_function" "app" {
  function_name    = "${var.project_name}-api-${var.stage}"
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  handler          = "src/lambda.handler"
  runtime          = "nodejs20.x"
  architectures    = ["arm64"]
  memory_size      = 512
  timeout          = 29
  role             = aws_iam_role.lambda.arn

  vpc_config {
    security_group_ids = [var.sg_lambda_id]
    subnet_ids         = var.private_subnet_ids
  }

  environment {
    variables = {
      NODE_ENV           = "production"
      PORT               = "3000"
      DB_HOST            = data.aws_ssm_parameter.db_host.value
      DB_PORT            = "5432"
      DB_NAME            = "lanchonete"
      DB_USER            = "lanchonete_user"
      DB_PASSWORD        = data.aws_ssm_parameter.db_password.value
      REDIS_HOST         = data.aws_ssm_parameter.redis_host.value
      REDIS_PORT         = "6379"
      REDIS_TTL_CARDAPIO = "300"
    }
  }

  tracing_config { mode = "Active" }  # X-Ray

  tags = { Project = var.project_name, Stage = var.stage }
}

# ── SSM Parameters ────────────────────────────────────────────────────────────
data "aws_ssm_parameter" "db_host" {
  name = "/lanchonete/${var.stage}/db_host"
}
data "aws_ssm_parameter" "db_password" {
  name            = "/lanchonete/${var.stage}/db_password"
  with_decryption = true
}
data "aws_ssm_parameter" "redis_host" {
  name = "/lanchonete/${var.stage}/redis_host"
}

# ── IAM Role ──────────────────────────────────────────────────────────────────
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role-${var.stage}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# ── API Gateway HTTP API ──────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "app" {
  name          = "${var.project_name}-api-${var.stage}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PATCH", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}

resource "aws_apigatewayv2_integration" "app" {
  api_id                 = aws_apigatewayv2_api.app.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.app.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_stage" "app" {
  api_id      = aws_apigatewayv2_api.app.id
  name        = var.stage
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.app.execution_arn}/*/*"
}

# ── Auto Scaling de concorrência ──────────────────────────────────────────────
resource "aws_lambda_function_event_invoke_config" "app" {
  function_name          = aws_lambda_function.app.function_name
  maximum_retry_attempts = 0
}

resource "aws_appautoscaling_target" "lambda" {
  max_capacity       = 100
  min_capacity       = 2
  resource_id        = "function:${aws_lambda_function.app.function_name}:${aws_lambda_function.app.version}"
  scalable_dimension = "lambda:function:ProvisionedConcurrency"
  service_namespace  = "lambda"
}

resource "aws_appautoscaling_policy" "lambda" {
  name               = "${var.project_name}-lambda-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.lambda.resource_id
  scalable_dimension = aws_appautoscaling_target.lambda.scalable_dimension
  service_namespace  = aws_appautoscaling_target.lambda.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "LambdaProvisionedConcurrencyUtilization"
    }
    target_value = 0.7
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "api_endpoint" { value = aws_apigatewayv2_stage.app.invoke_url }
output "lambda_arn"   { value = aws_lambda_function.app.arn }
