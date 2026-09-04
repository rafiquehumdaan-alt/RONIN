resource "aws_iam_role" "ecs_execution" {
  name = "ronin-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "ronin-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Creates an IAM execution role that ECS Fargate tasks are allowed to assume.
# Attaches AWS's standard permissions for actions such as pulling ECR images and sending logs to CloudWatch.

resource "aws_iam_role" "ecs_task" {
  name = "ronin-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "ronin-ecs-task-role"
  }
}

resource "aws_iam_role_policy" "ecs_task_storage" {
  name = "ronin-app-storage-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]

        Resource = var.dynamodb_table_arn
      },
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = var.reports_bucket_arn
      },
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = "${var.reports_bucket_arn}/*"
      }
    ]
  })
}

# Creates the IAM task role that the RONIN application assumes while running in ECS.
# Grants the role the required permissions to read/write data in the specified DynamoDB table and S3 bucket.