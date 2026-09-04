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

# Registers GitHub as a trusted OIDC identity provider so GitHub Actions can authenticate with AWS.

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

# Creates a trust policy allowing only the authorised GitHub repository to assume the IAM role through OIDC.

resource "aws_iam_role" "github_actions" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Name    = var.github_actions_role_name
    Project = "RONIN"
  }
}

# Creates the IAM role that authorised GitHub Actions workflows can assume through OIDC.

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

  # GitHub Actions can read and update Terraform's state stored in this S3 bucket

  statement {
    sid       = "ECRAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Allows GitHub Actions to obtain an authorization token for authenticating with Amazon ECR.

  statement {
    sid       = "ECR"
    actions   = ["ecr:*"]
    resources = ["arn:aws:ecr:eu-west-2:${data.aws_caller_identity.current.account_id}:repository/ronin"]
  }

# Allows GitHub Actions to manage images and resources in the RONIN ECR repository.

  statement {
    sid       = "EC2Networking"
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  # Allows GitHub Actions to manage the EC2 networking resources required by the RONIN infrastructure.

  statement {
    sid = "ECS"
    actions = [
      "ecs:*",
      "application-autoscaling:*"
    ]
    resources = ["*"]
  }

  # Allows GitHub Actions to manage the RONIN ECS infrastructure and application auto scaling.

  statement {
    sid       = "LoadBalancing"
    actions   = ["elasticloadbalancing:*"]
    resources = ["*"]
  }

  # Allows GitHub Actions to manage the ALB, listeners and target groups used by RONIN.

  statement {
    sid       = "Certificates"
    actions   = ["acm:*"]
    resources = ["*"]
  }

# Allows GitHub Actions to manage the ACM certificates used to secure RONIN with HTTPS.

  statement {
    sid       = "DNS"
    actions   = ["route53:*"]
    resources = ["*"]
  }

# Allows GitHub Actions to manage the Route 53 DNS resources used by RONIN.

  statement {
    sid       = "CloudFront"
    actions   = ["cloudfront:*"]
    resources = ["*"]
  }

# Allows GitHub Actions to manage the CloudFront distribution used by RONIN.

  statement {
    sid = "ApplicationStorage"
    actions = [
      "s3:*",
      "dynamodb:*"
    ]
    resources = ["*"]
  }

# Allows GitHub Actions to manage the S3 and DynamoDB resources used by RONIN.

  statement {
    sid = "LambdaAndScheduler"
    actions = [
      "lambda:*",
      "scheduler:*"
    ]
    resources = ["*"]
  }

# Allows GitHub Actions to manage the Lambda functions and EventBridge schedules used by RONIN.

  statement {
    sid       = "Logging"
    actions   = ["logs:*"]
    resources = ["*"]
  }

# Allows GitHub Actions to manage the CloudWatch Logs resources used by RONIN.

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

# Allows GitHub Actions to create, manage and pass the IAM roles and policies required by RONIN.

resource "aws_iam_policy" "github_actions" {
  name        = "ronin-github-actions-policy"
  description = "Permissions used by RONIN GitHub Actions workflows"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json

  tags = {
    Name    = "ronin-github-actions-policy"
    Project = "RONIN"
  }
}

# Creates the GitHub Actions IAM policy using the RONIN permissions defined above.

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

# Attaches the RONIN permissions policy to the GitHub Actions IAM role.