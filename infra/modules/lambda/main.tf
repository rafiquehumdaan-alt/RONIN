data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_iam_role" "lambda" {
  name = "ronin-weekly-summary-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "lambda.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "ronin-weekly-summary-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_storage" {
  name = "ronin-weekly-summary-storage-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "dynamodb:Scan"
        ]

        Resource = var.dynamodb_table_arn
      },
      {
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = "${var.reports_bucket_arn}/weekly/*"
      }
    ]
  })
}

resource "aws_lambda_function" "weekly_summary" {
  function_name = "ronin-weekly-summary"
  role          = aws_iam_role.lambda.arn

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  handler = "lambda_function.lambda_handler"
  runtime = "python3.12"

  architectures = ["x86_64"]

  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      REPORTS_BUCKET = var.reports_bucket_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_storage
  ]

  tags = {
    Name = "ronin-weekly-summary"
  }
}

resource "aws_iam_role" "scheduler" {
  name = "ronin-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "scheduler.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "ronin-scheduler-role"
  }
}

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name = "ronin-scheduler-invoke-lambda"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "lambda:InvokeFunction"
      ]

      Resource = aws_lambda_function.weekly_summary.arn
    }]
  })
}

resource "aws_scheduler_schedule" "weekly_summary" {
  name = "ronin-weekly-summary"

  schedule_expression          = "cron(0 9 ? * SUN *)"
  schedule_expression_timezone = "Europe/London"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.weekly_summary.arn
    role_arn = aws_iam_role.scheduler.arn
  }

  depends_on = [
    aws_iam_role_policy.scheduler_invoke_lambda
  ]
}