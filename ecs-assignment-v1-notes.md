# RONIN — Introduction

## What is RONIN?

**RONIN** is a pre-beta cloud infrastructure companion designed to help developers and technical teams understand cloud resources, costs, utilisation, and potential optimisation opportunities.

For this project, RONIN runs as a **safe public demo using simulated AWS infrastructure data**. Visitors do not need an account and do not provide AWS credentials or personal information.

RONIN displays information such as:

* AWS resource health and utilisation
* Monthly cloud spending
* Potential cost savings
* Infrastructure findings and recommendations
* Overall environment health

Although the AWS environment is simulated, RONIN uses a **real deterministic rules engine** to analyse the data. For example, sustained low CPU utilisation can cause an EC2 instance to be flagged as potentially underutilised.

## Why RONIN?

RONIN aims to make cloud infrastructure information easier to understand. Instead of presenting only raw metrics, it identifies noteworthy conditions and explains why they may require attention.

The longer-term vision is for RONIN to become a local-first cloud companion capable of analysing real AWS environments securely while keeping user credentials on their own machine.

The public pre-beta provides a safe way to demonstrate the concept without exposing real AWS accounts or infrastructure.

---

# Day 1 – RONIN Application Development and Docker Containerisation

# Application Setup

## Technology Stack

The initial application uses:

* **Python**
* **Flask** — web application framework
* **Gunicorn** — production application server
* **HTML/CSS/JavaScript** — user interface

The application is lightweight and stateless, making it suitable for later containerisation and deployment to **Amazon ECS Fargate**.

## Local Environment

A Python virtual environment (`.venv`) was created for RONIN.

This isolates RONIN's Python packages and dependencies from the rest of the Linux system and from other projects.

The required application and development dependencies were then installed inside this environment.

## Local Application Testing

RONIN was deliberately tested locally **before introducing Docker or AWS**.

The application was started locally on port `8080` and successfully accessed through:

`http://localhost:8080`

This confirmed that the application itself was working independently of any container or cloud infrastructure.

## Health Endpoint

RONIN provides:

`GET /health`

The endpoint was tested using:

`curl http://localhost:8080/health`

and successfully returned:

`{"status":"ok"}`

This health endpoint will later be useful for Docker verification, AWS Application Load Balancer health checks, ECS health monitoring, and CI/CD post-deployment testing.

## Automated Tests

RONIN's automated test suite was run using pytest.

Result:

`4 passed`

The tests verify important application behaviour including the health endpoint, API functionality, and deterministic rules engine.

## Why Test Locally First?

Testing RONIN before containerisation establishes a known working baseline.

The project is being built and verified in layers:

**Application → Docker → ECR → AWS Infrastructure → Terraform → CI/CD**

If a problem occurs after introducing a new layer, this approach makes troubleshooting easier because the previous layer has already been proven to work.

### Current Status

**Application Setup: Complete**

RONIN:

* Runs successfully locally
* Provides the required `/health` endpoint
* Uses simulated AWS data safely
* Requires no user AWS credentials
* Contains deterministic infrastructure analysis
* Passes its automated tests
* Is ready for containerisation with Docker

Going to take a short break and get back to it later. 

# Docker Containerisation

## Why Containerise RONIN?

RONIN was containerised with Docker so the application and its required dependencies can run consistently across different environments.

Instead of relying on the configuration of the host machine, the Docker image provides RONIN with its own predictable runtime environment. This image can later be stored in Amazon ECR and deployed using ECS Fargate.

## Multi-Stage Dockerfile

RONIN uses a two-stage Docker build:

1. **Builder Stage** — creates a Python virtual environment and installs RONIN's required dependencies.
2. **Runtime Stage** — starts from a fresh lightweight Python image and copies only the required dependencies and application files into it.

This keeps the final runtime image cleaner and avoids including unnecessary development files.

The project uses the lightweight `python:3.12-slim` base image.

## Docker Ignore

A `.dockerignore` file prevents unnecessary files and directories from being included in the Docker build context.

Examples include:

- Local Python virtual environment
- Git/GitHub files
- Python and pytest caches
- Tests
- Terraform infrastructure
- Reference material
- Assignment documentation

This keeps the Docker build context focused on files required to run RONIN.

## Non-Root Container

A dedicated `ronin` user is created inside the container and the application runs using this account instead of `root`.

This follows the principle of least privilege and reduces the privileges available to the application if it were compromised.

This was verified using:

`docker exec ronin whoami`

Result:

`ronin`

The container user was also confirmed as UID/GID `999`.

## Application Server

RONIN is served using **Gunicorn** rather than Flask's development server.

Gunicorn is a production-oriented Python application server and listens on port `80` inside the container.

## Local Docker Verification

The Docker image was successfully built as:

`ronin:local`

The image was then started as a container with host port `80` mapped to container port `80`.

`docker ps` confirmed that the RONIN container was running successfully.

The required health check was tested using:

`curl http://localhost:80/health`

Result:

`{"status":"ok"}`

The full RONIN interface was also successfully accessed through `http://lo
calhost`.

## Result

RONIN has now been successfully:

**Built locally → Tested locally → Containerised → Run and verified through Docker**

The application is ready for the next stage, where the Docker image will be stored in Amazon ECR before deployment to ECS.

TIME LOG : + 5 hours .   

# Day 2 – Amazon ECR and AWS Infrastructure Planning

## Amazon ECR Setup

After successfully building and testing the RONIN Docker image locally, I created a private Amazon ECR repository called `ronin` in the `eu-west-2` region.

Amazon ECR is being used as the private container registry for RONIN. This allows AWS ECS to retrieve and run the same Docker image that was tested locally.

The repository was configured with immutable image tags to help prevent an existing image version from being accidentally overwritten.

## Connecting Docker to ECR

I authenticated my local Docker client with Amazon ECR using the AWS CLI:

```bash
aws ecr get-login-password --region eu-west-2 | \
docker login --username AWS --password-stdin <ECR-REGISTRY>
```

This authenticated Docker with the private ECR registry and allowed the locally built image to be pushed into AWS.

## Tagging and Pushing RONIN

The locally tested RONIN image was tagged for the ECR repository:

```bash
docker tag ronin:local <ECR-REGISTRY>/ronin:v1
```

The image was then pushed to ECR:

```bash
docker push <ECR-REGISTRY>/ronin:v1
```

The `v1` image was successfully confirmed in the ECR console.

For the later CI/CD implementation, image versions will use Git commit SHAs instead of manually created version tags. This will make each deployed image traceable to a specific version of the source code.

---

# AWS Infrastructure Planning

Before beginning the manual ClickOps deployment, I planned the AWS infrastructure that will be used to host RONIN.

The architecture was deliberately designed before deployment so that the manual ClickOps environment and the later Terraform environment can follow the same overall design.

The architecture diagram and more detailed reasoning behind the infrastructure decisions can be found in the:

`architecture-diagram/`

folder.

## Networking

RONIN will use a custom VPC in the `eu-west-2` region with two public subnets spread across two Availability Zones.

An Internet Gateway and public route table will provide internet connectivity to the public subnets.

Using two Availability Zones allows the application architecture to avoid depending entirely on a single AZ and provides the foundation for running redundant RONIN tasks.

Public subnets were selected for this project to keep the networking relatively simple and avoid introducing additional NAT Gateway or VPC endpoint infrastructure.

## Application Load Balancer

An internet-facing Application Load Balancer will provide the public entry point for RONIN.

The ALB will accept HTTPS traffic on port `443`. Requests received over HTTP on port `80` will be redirected to HTTPS.

The ALB will then forward application traffic internally to the healthy RONIN Fargate tasks on port `80`.

## Route 53 and AWS Certificate Manager

Amazon Route 53 will provide DNS for the RONIN custom domain and direct users towards the Application Load Balancer.

AWS Certificate Manager (ACM) will provide the TLS certificate attached to the ALB HTTPS listener.

The ALB therefore handles the HTTPS encryption/decryption while the RONIN containers can continue receiving normal HTTP traffic internally.

## Target Group and Health Checks

The Application Load Balancer will use an IP-based Target Group containing the IP addresses of the running Fargate tasks.

The Target Group will regularly check RONIN's:

`/health`

endpoint.

Only healthy RONIN tasks will receive application traffic from the ALB.

## Amazon ECS and AWS Fargate

Amazon ECS will provide the container orchestration for RONIN, while AWS Fargate will provide the compute required to run the containers without requiring me to provision or manage EC2 instances.

The ECS Service will use a:

`Desired count: 2`

This means ECS will attempt to keep two RONIN Fargate tasks running continuously.

The infrastructure spans two Availability Zones so the RONIN workload can be distributed across AZs, providing redundancy rather than relying on a single running container.

If a task fails, ECS can start a replacement to return the service to its desired state.

## ECS Task Definition

An ECS Task Definition will describe how each RONIN task should run.

This will include settings such as the ECR image, container port, CPU, memory and required IAM configuration.

This provides ECS with a repeatable definition for starting and replacing RONIN tasks.

## Security Groups

Two Security Groups will be used.

The ALB Security Group will allow inbound traffic from the internet on ports `80` and `443`.

The ECS Security Group will allow inbound traffic on RONIN's port `80` only when it originates from the ALB Security Group.

This prevents normal internet traffic from directly accessing the RONIN Fargate tasks and ensures application traffic enters through the load balancer.

## Amazon ECR

Amazon ECR stores the private RONIN Docker image.

When ECS needs to start a RONIN Fargate task, the configured container image can be retrieved from ECR and used to start the container.

This means the same container image that was built and tested locally can be deployed into AWS.

## IAM

IAM roles will provide ECS and Fargate with the AWS permissions required to perform operations such as retrieving the private container image from ECR and sending logs.

Permissions will be kept as limited as reasonably possible rather than giving the application unnecessary access to AWS resources.

## CloudWatch Logs

RONIN container logs will be sent to Amazon CloudWatch Logs.

This provides centralised logging for the running containers and makes it possible to monitor and troubleshoot the application without directly accessing the Fargate tasks.

---

# Infrastructure Design Decisions

The infrastructure has intentionally been kept focused on what RONIN actually requires.

Services such as RDS, DynamoDB, S3, CloudFront and WAF have not been added because the current RONIN application does not require them.

Private subnets were also considered for the Fargate tasks. They would provide an additional layer of network isolation, but would introduce additional outbound networking requirements such as NAT Gateways or VPC endpoints.

For this project, public Fargate networking combined with an ECS Security Group that only accepts application traffic from the ALB provides a simpler and lower-cost architecture.

The final architecture therefore focuses on containerisation, managed compute, redundancy across two Fargate tasks, multi-AZ deployment, load balancing, health checking, HTTPS, restricted network access and centralised logging without introducing unnecessary AWS services.

More detailed reasoning for these decisions, along with the planned infrastructure diagram, can be found in the `architecture-diagram/` folder.

TIME LOG : + 3 & 1/2 hours . 





