# Security overview

## Network access

Fargate tasks have no public IPs. Their security group accepts TCP traffic on port `8080` from the ALB security group. The internet-facing ALB currently accepts public IPv4 traffic on ports `80` and `443`. CloudFront is the intended entry point, and the ALB origin is publicly reachable.

## HTTPS

CloudFront uses an ACM certificate in `us-east-1` for `ronin.humdaan.co.uk`. The ALB uses a separate ACM certificate in `eu-west-2` for `origin.ronin.humdaan.co.uk`. The browser-to-CloudFront and CloudFront-to-ALB connections both use HTTPS. The ALB forwards traffic to the tasks over HTTP on port `8080`.

## AWS access and Terraform state

GitHub Actions uses OIDC to obtain temporary AWS credentials for infrastructure operations and application deployments. The workflows currently share one IAM role. Fargate uses a separate execution role to pull the image from ECR and send logs to CloudWatch.

Terraform state is kept in a private, encrypted and versioned S3 bucket. The S3 backend uses a lock file to coordinate Terraform runs.

## Container and infrastructure checks

The container runs as a non-root user. Trivy scans the Docker image and Checkov scans the Terraform configuration. Both report findings in the current workflows.