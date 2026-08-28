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

---

# AWS Infrastructure Planning

Before beginning the manual ClickOps deployment, I planned the AWS infrastructure that will be used to host RONIN.

The architecture was designed before deployment so that the initial manual ClickOps environment and the later Terraform implementation can follow the same overall design.

The full architecture diagram and detailed reasoning behind each infrastructure decision can be found in the:

`architecture-diagram/`

folder.

## Networking

RONIN will use a custom VPC (`10.0.0.0/16`) in `eu-west-2`, spanning two Availability Zones.

The network will contain two public subnets and two private application subnets.

The public subnets will contain the internet-facing infrastructure, including the Application Load Balancer and NAT Gateways.

The RONIN Fargate tasks will run inside the private application subnets, preventing them from being directly exposed to the internet.

An Internet Gateway, public/private route tables and one NAT Gateway per Availability Zone will provide the required routing and controlled outbound connectivity.

VPC endpoints will also be used where appropriate to provide private connectivity to supported AWS services such as S3 and DynamoDB.

## Application Delivery

Amazon Route 53 will provide DNS for RONIN's custom domain.

CloudFront will provide an edge/CDN layer in front of the application, with the Application Load Balancer acting as the origin for dynamic application traffic.

AWS Certificate Manager will provide the TLS certificates required for HTTPS.

The ALB will distribute application traffic between healthy RONIN Fargate tasks through an IP-based Target Group.

The Target Group will use RONIN's `/health` endpoint to determine whether each task is healthy before traffic is forwarded to it.

## Amazon ECS and AWS Fargate

Amazon ECS will provide container orchestration while AWS Fargate will provide the compute required to run RONIN without directly managing EC2 instances.

The ECS Service will maintain a minimum of two RONIN tasks across the multi-AZ architecture for redundancy.

ECS Service Auto Scaling will allow the service to scale between:

- Minimum: `2`
- Desired: `2`
- Maximum: `4`

If a task becomes unhealthy, ECS can replace it while the ALB continues directing traffic towards healthy targets.

## Security

The ALB and ECS workloads will use separate Security Groups.

The ECS Security Group will only accept application traffic from the ALB Security Group.

Combined with private application subnets, this provides multiple layers of protection between the internet and the RONIN containers.

IAM roles will follow least-privilege principles and provide ECS, RONIN and supporting AWS services with only the permissions they require.

## Amazon ECR

The previously created private ECR repository will provide the container image used by ECS.

When a Fargate task starts, ECS/Fargate can retrieve the required version of the RONIN image from ECR.

## DynamoDB and S3

DynamoDB will provide persistent NoSQL storage for structured RONIN data such as analysis runs, findings and report metadata.

Amazon S3 will provide object storage for generated RONIN reports and exports.

This gives the two services separate responsibilities: DynamoDB for structured application records and S3 for report objects.

## AWS Lambda

Lambda will provide event-driven processing for reports uploaded to S3.

The planned workflow is:

`RONIN → S3 → Lambda → DynamoDB`

When RONIN creates a report in S3, an S3 event can invoke Lambda automatically. Lambda can process the event and store the relevant structured metadata in DynamoDB.

This allows the project to demonstrate both long-running container workloads with ECS/Fargate and event-driven serverless processing with Lambda.

## Monitoring and Logging

Amazon CloudWatch will provide centralised logs, metrics and monitoring for the infrastructure.

RONIN container logs will be sent to CloudWatch Logs, while CloudWatch metrics and alarms will be used to monitor areas such as ECS utilisation, unhealthy ALB targets and Lambda errors.

## Infrastructure Automation

The architecture will first be deployed manually using AWS ClickOps to understand and verify how the services connect.

The manually created infrastructure will then be removed and recreated using modular Terraform.

Terraform will use remote state in S3 with state locking.

GitHub Actions will later automate application and infrastructure deployments, using AWS OIDC authentication rather than long-lived AWS access keys.

---

# Infrastructure Design Decisions

The planned architecture was expanded beyond the minimum assignment requirements to demonstrate a broader range of practical AWS and DevOps skills while still giving each service a clear purpose.

The design now demonstrates:

- Custom VPC and CIDR planning
- Public and private subnetting
- Multi-AZ architecture
- Internet Gateway and NAT
- VPC endpoints
- Docker and Amazon ECR
- ECS and Fargate
- Multi-task redundancy
- ECS Auto Scaling
- Application Load Balancing
- Health checks
- Route 53 and HTTPS
- CloudFront
- Security Groups and IAM
- DynamoDB
- Amazon S3
- Lambda event-driven processing
- CloudWatch logging, metrics and alarms
- Terraform and remote state
- CI/CD with GitHub Actions and AWS OIDC

Services are still only included where they can provide a clear architectural or application function rather than being added purely for complexity.

More detailed reasoning for each decision, along with the planned infrastructure diagram, can be found in the `architecture-diagram/` folder.

TIME LOG: + 6 hours (Planning/designing infra is not quick!)





