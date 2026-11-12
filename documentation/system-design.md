# System design

RONIN is a Flask app that uses demo AWS data to show how simple rules can flag issues such as low EC2 utilisation or an unattached EBS volume. Flask calculates the findings when the page is requested. The current app uses demo data and does not save analysis reports.

## Application runtime

The Docker image is stored in Amazon ECR. ECS runs it on Fargate in two private subnets. Each task runs one RONIN container with Flask and Gunicorn and is configured with 0.25 vCPU and 512 MiB of memory. Container logs go to CloudWatch Logs and are retained for seven days.

## Availability and scaling

Terraform creates the ECS service with zero tasks so the infrastructure can come up before the image is available. The first app deployment starts two tasks and sets the scaling minimum to two after verifying the rollout and image digest.

Availability Zone rebalancing is enabled, so ECS aims to spread the tasks across the two zones. The load balancer routes requests to healthy tasks. The service can scale to four tasks based on a target of 70% average CPU usage.

## Infrastructure

Terraform is split into bootstrap and main. Bootstrap creates the S3 state bucket and the GitHub OIDC role. The main configuration uses that backend and manages the VPC, load balancer, ECS, ECR, CloudFront, DNS and certificates.