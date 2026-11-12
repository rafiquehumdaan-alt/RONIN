# Security overview

## Network access

The public entry point is CloudFront. The internet-facing ALB accepts IPv4 traffic on ports 80 and 443, so its origin hostname can also be reached directly. The ALB redirects HTTP requests to HTTPS.

The Fargate tasks have no public IP addresses. Their security group only accepts inbound traffic on port 8080 from the ALB security group. Outbound traffic is allowed on port 443 through NAT. This gives the tasks access to ECR and CloudWatch Logs, and the rule permits other IPv4 destinations on that port too.

## HTTPS

CloudFront uses an ACM certificate in us-east-1 for ronin.humdaan.co.uk. The ALB uses a separate ACM certificate in eu-west-2 for origin.ronin.humdaan.co.uk. Both certificates are validated through DNS in Route 53.

The browser connects to CloudFront over HTTPS, and CloudFront uses a separate HTTPS connection to the ALB. The ALB forwards requests to the private tasks over HTTP on port 8080.

## AWS access

GitHub Actions uses OIDC to obtain temporary AWS credentials. The role's trust policy checks that the token is intended for AWS STS and that it comes from the configured RONIN repository and main branch.

The Terraform and application workflows share this role. Its permissions cover both infrastructure changes and application deployments. The Fargate tasks use a separate execution role so ECS can pull the container image and send logs to CloudWatch. The Flask app uses local demo data and has no application task role.

## Terraform state

Bootstrap creates a private S3 bucket for the main Terraform state. Public access is blocked, encryption at rest uses SSE-S3, and versioning keeps previous copies of the state. Terraform uses an S3 lock file to prevent simultaneous operations from updating the same state.

Bootstrap keeps its own state locally. The main stack uses the S3 backend.

## Container and workflow checks

The Dockerfile installs Python dependencies in a build stage and copies the virtual environment into the runtime image. Gunicorn runs as a non-root user inside the container.

The application workflow checks that the container starts and responds on /health, then scans the image with Trivy. ECR also scans images on push. The Terraform workflow checks formatting, validates the configuration, runs TFLint and scans with Checkov. Trivy and Checkov findings are advisory in the GitHub workflows.

[Read the CI/CD overview](cicd-overview.md)