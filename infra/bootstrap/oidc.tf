data "aws_caller_identity" "current" {}
# Reads the AWS account ID used to build resource ARNs below.

resource "aws_iam_openid_connect_provider" "github" {
  # Registers GitHub Actions as a trusted identity provider in AWS.
  url = var.github_oidc_provider_url
  # Uses GitHub's official OIDC token issuer URL.

  client_id_list = [
    "sts.amazonaws.com"
  ]
  # Only accepts tokens intended for AWS Security Token Service.

  tags = {
    Name    = "github-actions"
    Project = "RONIN"
  }
  # Labels the provider so its purpose is clear in AWS.
}

data "aws_iam_policy_document" "github_actions_trust" {
  # Builds the trust policy that controls who can assume the role.
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    # Allows a verified OIDC identity to request temporary AWS credentials.

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    # Trusts identities only from the GitHub provider created above.

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Requires the GitHub token to be specifically intended for AWS STS.

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_repository_subject]
    }
    # Restricts access to the configured RONIN repository and branch.
  }
}

resource "aws_iam_role" "github_actions" {
  # Creates the AWS role that GitHub Actions will assume.
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
  # Attaches the trust policy generated above to the role.

  tags = {
    Name    = var.github_actions_role_name
    Project = "RONIN"
  }
  # Labels the role as part of the RONIN project.
}

data "aws_iam_policy_document" "github_actions_permissions" {
  # Builds the permissions policy used by RONIN workflows.
  statement {
    sid = "TerraformBackend"
    # Allows Terraform to read, update and lock remote state in S3.
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
    # Limits these permissions to the state bucket and its objects.
  }

  statement {
    sid       = "ECRAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
    # Allows Docker to obtain the login token required by ECR.
  }

  statement {
    sid       = "ECR"
    actions   = ["ecr:*"]
    resources = ["arn:aws:ecr:eu-west-2:${data.aws_caller_identity.current.account_id}:repository/ronin"]
    # Allows image and repository operations against the RONIN ECR repository.
  }

  statement {
    sid       = "EC2Networking"
    actions   = ["ec2:*"]
    resources = ["*"]
    # Allows Terraform to manage VPCs, subnets, routes and security groups.
  }

  statement {
    sid = "ECS"
    actions = [
      "ecs:*",
      "application-autoscaling:*"
    ]
    resources = ["*"]
    # Allows Terraform to manage ECS services and their autoscaling.
  }

  statement {
    sid       = "LoadBalancing"
    actions   = ["elasticloadbalancing:*"]
    resources = ["*"]
    # Allows Terraform to manage the ALB, listeners and target groups.
  }

  statement {
    sid       = "Certificates"
    actions   = ["acm:*"]
    resources = ["*"]
    # Allows Terraform to request and validate HTTPS certificates.
  }

  statement {
    sid       = "DNS"
    actions   = ["route53:*"]
    resources = ["*"]
    # Allows Terraform to manage the hosted zone and DNS records.
  }

  statement {
    sid       = "CloudFront"
    actions   = ["cloudfront:*"]
    resources = ["*"]
    # Allows Terraform to manage the CloudFront distribution.
  }

  statement {
    sid = "ApplicationStorage"
    actions = [
      "s3:*",
      "dynamodb:*"
    ]
    resources = ["*"]
    # Allows Terraform to manage the report bucket and analyses table.
  }

  statement {
    sid = "LambdaAndScheduler"
    actions = [
      "lambda:*",
      "scheduler:*"
    ]
    resources = ["*"]
    # Allows Terraform to manage the weekly Lambda and its schedule.
  }

  statement {
    sid       = "Logging"
    actions   = ["logs:*"]
    resources = ["*"]
    # Allows Terraform to manage CloudWatch log groups and streams.
  }

  statement {
    sid = "IAMForRonin"
    # Allows Terraform to create and configure RONIN service roles.
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
    # PassRole lets AWS services such as ECS and Lambda use their roles.
  }
}

resource "aws_iam_policy" "github_actions" {
  # Creates a reusable managed IAM policy from the document above.
  name        = "ronin-github-actions-policy"
  description = "Permissions used by RONIN GitHub Actions workflows"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json
  # Converts the Terraform policy document into AWS policy JSON.

  tags = {
    Name    = "ronin-github-actions-policy"
    Project = "RONIN"
  }
  # Labels the policy as part of the RONIN project.
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  # Connects the permissions policy to the GitHub Actions role.
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
  # The role can use the permissions only after this attachment exists.
}
