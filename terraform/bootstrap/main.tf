terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "ronin-terraform-state-435059220418"
  force_destroy = true

  tags = {
    Name    = "ronin-terraform-state"
    Project = "RONIN"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url = var.github_oidc_provider_url

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name    = "github-actions"
    Project = "RONIN"
  }
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_repository_subject]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Name    = var.github_actions_role_name
    Project = "RONIN"
  }
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid = "TerraformBackend"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*"
    ]
  }

  statement {
    sid       = "ECRAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid       = "ECR"
    actions   = ["ecr:*"]
    resources = ["arn:aws:ecr:eu-west-2:${data.aws_caller_identity.current.account_id}:repository/ronin"]
  }

  statement {
    sid       = "EC2Networking"
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  statement {
    sid = "ECS"
    actions = [
      "ecs:*",
      "application-autoscaling:*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "LoadBalancing"
    actions   = ["elasticloadbalancing:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Certificates"
    actions   = ["acm:*"]
    resources = ["*"]
  }

  statement {
    sid       = "DNS"
    actions   = ["route53:*"]
    resources = ["*"]
  }

  statement {
    sid       = "CloudFront"
    actions   = ["cloudfront:*"]
    resources = ["*"]
  }

  statement {
    sid = "ApplicationStorage"
    actions = [
      "s3:*",
      "dynamodb:*"
    ]
    resources = ["*"]
  }

  statement {
    sid = "LambdaAndScheduler"
    actions = [
      "lambda:*",
      "scheduler:*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "Logging"
    actions   = ["logs:*"]
    resources = ["*"]
  }

  statement {
    sid = "IAMForRonin"
    actions = [
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions" {
  name        = "ronin-github-actions-policy"
  description = "Permissions used by RONIN GitHub Actions workflows"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json

  tags = {
    Name    = "ronin-github-actions-policy"
    Project = "RONIN"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}
