# System design

RONIN is a small Flask app that reviews a sample AWS environment. I used demo data so people can try the app locally or on AWS without connecting their own account.

## How the app works

The demo dataset contains resources, usage figures and cost estimates. When someone opens the dashboard or requests the findings API, Flask runs a set of rules against that data.

For example, the engine flags a running EC2 instance if its average CPU usage is below 5% over at least 72 hours. It also flags unattached EBS volumes and compares the current demo spend with a historical baseline. Each finding shows what triggered it and suggests what to review.

The actions in the interface are simulations. Findings are calculated on request, and the app has no database or saved reports. Any savings shown are estimates based on the demo data.

## Application runtime

The app runs in a Docker container with Python 3.12 and Gunicorn. Gunicorn starts two workers and listens on port 8080. Each Fargate task runs one container with 0.25 vCPU and 512 MiB of memory.

Amazon ECR stores the images. Container output goes to the /ecs/ronin-task log group in CloudWatch Logs, with seven days of retention.

## First deployment and scaling

Terraform creates the ECS service with zero tasks. This lets the infrastructure come up before the first image is available in ECR. The application workflow pushes the image and starts two tasks on the first deployment. After checking the running image digest and the public health endpoint, it sets the autoscaling minimum to two.

The service can then run between two and four tasks. Target tracking aims for 70% average CPU utilisation. Availability Zone rebalancing helps spread the tasks across both zones, and the ALB routes requests to healthy tasks.

Terraform ignores changes to the service's desired count and the autoscaling minimum. This allows the deployment script and autoscaling to manage those values after the initial infrastructure apply.

## How an update goes live

The application workflow pushes the same tested image to ECR as latest and under a run-specific tag. The ECS task definition points to latest, so the workflow starts a new rollout to pick up the image behind that tag.

The deployment script looks up the expected image digest using the run-specific tag and compares it with the digests on the running tasks. It then checks the public /health endpoint. This verifies both the image version and whether the app responds through CloudFront.

## How Terraform is organised

Bootstrap creates the S3 state bucket and GitHub OIDC role. The main configuration uses that backend and manages the VPC, ECR, certificates, DNS, CloudFront, ALB and ECS. Keeping bootstrap separate lets me tear down the app stack and reuse the state bucket and GitHub role when I deploy again.

For more detail, see [Networking](networking.md), [Security](security-overview.md) and the [CI/CD overview](cicd-overview.md).