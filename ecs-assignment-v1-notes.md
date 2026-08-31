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

# Day 3 — AWS ClickOps Production Deployment

## Objective

The goal of Day 3 was to take the RONIN container image stored in Amazon ECR and manually deploy it to a production-style AWS architecture using ClickOps.

The deployment was intentionally completed manually before Terraform so that I could understand how the individual AWS resources connect together before recreating the infrastructure as code.

The final deployment included:

- Custom VPC
- Public and private subnets across two Availability Zones
- Internet Gateway
- NAT Gateways
- VPC Gateway Endpoints
- Application Load Balancer
- ECS Fargate
- ECS Service Auto Scaling
- ECR
- DynamoDB
- S3
- Lambda
- EventBridge Scheduler
- CloudWatch Logs
- IAM roles
- Route 53
- ACM
- CloudFront
- Custom HTTPS domain

---

## 1. Networking Architecture

A custom VPC was created:

- **Name:** `ronin-vpc`
- **CIDR:** `10.0.0.0/16`
- **Region:** `eu-west-2`

Four subnets were created across two Availability Zones.

### Public Subnets

- `ronin-public-a` — `10.0.1.0/24` — `eu-west-2a`
- `ronin-public-b` — `10.0.2.0/24` — `eu-west-2b`

### Private Application Subnets

- `ronin-private-app-a` — `10.0.11.0/24` — `eu-west-2a`
- `ronin-private-app-b` — `10.0.12.0/24` — `eu-west-2b`

The Application Load Balancer was placed in the public subnets, while the ECS Fargate tasks were placed in the private subnets.

This means the application containers were not directly exposed to the internet.

---

## 2. Internet Gateway and Routing

An Internet Gateway named `ronin-igw` was attached to the VPC.

The public route table contained:

- `10.0.0.0/16` → Local
- `0.0.0.0/0` → Internet Gateway

This allowed internet-facing resources such as the Application Load Balancer and NAT Gateways to communicate with the internet.

Separate private route tables were used for the two private application subnets.

---

## 3. NAT Gateways

Two NAT Gateways were deployed:

- `ronin-nat-a` in Public Subnet A
- `ronin-nat-b` in Public Subnet B

Each private subnet routed outbound internet traffic through the NAT Gateway in the same Availability Zone.

This allowed the private Fargate tasks to initiate outbound connections without assigning public IP addresses to the containers.

Two NAT Gateways were used so that each Availability Zone had its own outbound path rather than both private subnets depending on a single NAT Gateway.

---

## 4. VPC Gateway Endpoints

Gateway endpoints were created for:

- Amazon S3
- Amazon DynamoDB

These endpoints were associated with the private route tables.

This allows traffic from the private Fargate tasks to S3 and DynamoDB to use AWS's private networking rather than travelling through the NAT Gateways.

The NAT Gateways remain available for other outbound traffic that does not use these gateway endpoints.

---

## 5. Security Groups

Two main security groups were created.

### ALB Security Group

The `ronin-alb-sg` security group was attached to the Application Load Balancer.

Inbound access allowed:

- TCP port `80` from the internet
- TCP port `443` from the internet

### ECS Security Group

The `ronin-ecs-sg` security group was attached to the Fargate tasks.

Inbound access allowed:

- TCP port `8080` from `ronin-alb-sg` only

The Fargate tasks therefore did not accept application traffic directly from the internet.

Only traffic that had passed through the Application Load Balancer could reach the RONIN containers.

---

## 6. ECS Fargate

An ECS cluster named `ronin-cluster` was created.

The application was deployed using AWS Fargate, meaning AWS manages the underlying compute infrastructure rather than requiring EC2 instances to be provisioned and maintained manually.

The final task definition was:

- **Task definition:** `ronin-task:3`
- **CPU:** `0.25 vCPU`
- **Memory:** `0.5 GB`
- **Network mode:** `awsvpc`
- **Container port:** `8080`

The container image was pulled from the private RONIN ECR repository.

---

## 7. Container Port 8080 Troubleshooting

The original Docker container attempted to listen on port `80`.

RONIN deliberately runs as a non-root Linux user inside the container as a security measure.

The first Fargate deployment failed with:

`[Errno 13] Permission denied`

CloudWatch Logs showed that Gunicorn could not bind to `0.0.0.0:80`.

Port 80 is a privileged Linux port and the non-root `ronin` user did not have permission to bind to it.

Instead of weakening the security of the container by running the application as root, the internal application port was changed to `8080`.

The Application Load Balancer continued to expose the standard HTTP and HTTPS ports externally while forwarding application traffic internally to port `8080`.

This preserved the non-root container security control while resolving the deployment issue.

---

## 8. ECS Service and High Availability

An ECS Service named `ronin-service` was created.

The desired task count was configured as:

- **Desired tasks:** `2`

The two Fargate tasks were distributed across:

- `eu-west-2a`
- `eu-west-2b`

Both tasks were registered with the Application Load Balancer target group.

This provides redundancy because the application is not dependent on one container or one Availability Zone.

If a task becomes unhealthy or stops, ECS can replace it while traffic continues to be served by another healthy task.

---

## 9. ECS Service Auto Scaling

ECS Service Auto Scaling was configured with:

- **Minimum tasks:** `2`
- **Maximum tasks:** `4`
- **Policy type:** Target tracking
- **Metric:** `ECSServiceAverageCPUUtilization`
- **Target:** `70%`

This allows ECS to increase the number of running RONIN tasks when CPU utilisation rises.

The number of tasks can then decrease again when additional capacity is no longer required.

The minimum remains at two tasks to maintain application availability.

---

## 10. Application Load Balancer

An internet-facing Application Load Balancer named `ronin-alb` was created.

The ALB was deployed across both public subnets.

The final target group was:

- **Name:** `ronin-tg-8080`
- **Protocol:** HTTP
- **Port:** `8080`
- **Target type:** IP

The target type was set to `IP` because Fargate tasks using `awsvpc` networking receive their own network interfaces and private IP addresses.

---

## 11. Health Checks

The ALB target group used the following health check endpoint:

`/health`

RONIN responds to this endpoint with:

`{"status":"ok"}`

Both Fargate targets successfully reached a `Healthy` state.

This allows the Application Load Balancer to avoid sending application traffic to unhealthy containers.

---

## 12. HTTP to HTTPS Redirection

The Application Load Balancer contained two listeners.

### HTTP Listener

- **Port:** `80`
- **Action:** 301 redirect to HTTPS port `443`

### HTTPS Listener

- **Port:** `443`
- **Action:** Forward traffic to `ronin-tg-8080`

The HTTP redirect was verified using:

`curl -I http://origin.ronin.humdaan.co.uk/health`

The response returned:

`HTTP/1.1 301 Moved Permanently`

and redirected the request to:

`https://origin.ronin.humdaan.co.uk:443/health`

This confirmed that HTTP traffic was correctly redirected to HTTPS.

---

## 13. DynamoDB

A DynamoDB table named `ronin-analyses` was created.

The partition key was:

- **Partition key:** `analysis_id`
- **Type:** String

RONIN uses DynamoDB to store structured analysis metadata.

When an analysis is generated, information about the analysis can be persisted in DynamoDB and retrieved later.

DynamoDB was suitable for this use case because it provides serverless structured storage without requiring a database server to be managed.

---

## 14. S3 Reports

A private S3 bucket named `ronin-reports` was created.

RONIN stores generated JSON reports in this bucket.

Objects were organised into prefixes such as:

- `analyses/`
- `weekly/`

DynamoDB and S3 therefore have separate responsibilities.

DynamoDB stores structured and queryable analysis information, while S3 stores generated report files.

The S3 bucket was not publicly exposed.

---

## 15. ECS Task Role

RONIN accesses DynamoDB and S3 using an ECS Task Role named:

`ronin-ecs-task-role`

The application does not contain hardcoded AWS access keys.

The role granted the application only the permissions required for its storage functionality.

DynamoDB permissions were restricted to the `ronin-analyses` table.

S3 permissions were restricted to the `ronin-reports` bucket.

This follows the principle of least privilege.

---

## 16. ECS Execution Role vs Task Role

Two separate IAM roles were used for ECS.

### ECS Execution Role

`ronin-ecs-execution-role`

This role is used by ECS for infrastructure-level operations such as:

- Pulling the container image from ECR
- Sending container logs to CloudWatch
- Starting the ECS task

### ECS Task Role

`ronin-ecs-task-role`

This role is used by the application running inside the container.

It provides RONIN with permission to access:

- DynamoDB
- S3

The execution role therefore provides permissions required by ECS to operate the task, while the task role provides permissions required by the application itself.

---

## 17. Real Application Persistence Test

A real analysis request was sent to the deployed RONIN application using the `/api/analyse` endpoint.

The application generated a new analysis ID.

The corresponding analysis record was then verified inside:

`DynamoDB → ronin-analyses`

The generated report was also verified inside:

`S3 → ronin-reports → analyses/`

This confirmed that the deployed Fargate application could successfully process an API request and persist data to both DynamoDB and S3.

---

## 18. Lambda Weekly Summary

A Lambda function named `ronin-weekly-summary` was created.

The Lambda function handles scheduled background processing separately from the continuously running RONIN web application.

Its purpose is to read analysis information from DynamoDB, generate a weekly summary, and write the generated report into the `weekly/` location in the S3 reports bucket.

Lambda was suitable for this workload because the operation is short-lived and event-driven and does not require another continuously running container.

---

## 19. EventBridge Scheduler

The Lambda function was triggered using Amazon EventBridge Scheduler.

The schedule was configured for:

- **Day:** Sunday
- **Time:** 09:00
- **Timezone:** Europe/London

EventBridge Scheduler invokes the Lambda function automatically according to the schedule.

This keeps scheduled background processing separate from the ECS web application.

---

## 20. Lambda IAM Role

The Lambda function used an IAM role named:

`ronin-lambda-weekly-role`

The role was restricted to the AWS resources required by the weekly summary process.

Its permissions included:

- DynamoDB `Scan` against `ronin-analyses`
- S3 `PutObject` into `ronin-reports/weekly/*`
- Permission to write Lambda logs to CloudWatch

The Lambda function was not given unrestricted access to DynamoDB or S3.

---

## 21. Lambda IAM Troubleshooting

The first Lambda test failed with an `AccessDenied` error while attempting to access DynamoDB.

The Lambda function had accidentally been configured with an automatically generated execution role rather than the intended:

`ronin-lambda-weekly-role`

The Lambda execution role was corrected.

After changing the role, the Lambda test completed successfully and a weekly report appeared inside:

`ronin-reports/weekly/`

This demonstrated the importance of checking which IAM role a workload is actually using when troubleshooting AWS permission errors.

---

## 22. CloudWatch Logging

Fargate application logs were sent to the CloudWatch log group:

`/ecs/ronin-task`

CloudWatch Logs were particularly useful during the initial failed Fargate deployment.

The logs exposed the Gunicorn port 80 permission error, which allowed the failed ECS deployment to be diagnosed.

Lambda also generated CloudWatch logs for its executions.

An additional issue occurred during the initial ECS deployment because the expected `/ecs/ronin-task` log group did not yet exist.

After the required log group was created, ECS was able to initialise logging correctly and the next application-level error became visible.

---

## 23. Route 53 and the Existing Cloudflare Domain

The parent domain:

`humdaan.co.uk`

is registered and managed through Cloudflare.

Rather than moving the entire domain's DNS infrastructure to Route 53, a dedicated subdomain was delegated:

`ronin.humdaan.co.uk`

NS records were added at the Cloudflare parent DNS level that delegated authority for `ronin.humdaan.co.uk` to an AWS Route 53 public hosted zone.

This allowed the project to demonstrate Route 53 while leaving the existing DNS configuration for the parent domain under Cloudflare.

---

## 24. ACM Certificates

AWS Certificate Manager was used to provide TLS certificates for HTTPS.

CloudFront requires its viewer certificate to exist in the `us-east-1` region.

The CloudFront certificate for:

`ronin.humdaan.co.uk`

was therefore created in:

`us-east-1`

Certificates used by the Application Load Balancer were created in:

`eu-west-2`

This included the certificate used for:

`origin.ronin.humdaan.co.uk`

The certificates were validated using DNS records.

This allowed encrypted HTTPS connections between the user and CloudFront and between CloudFront and the Application Load Balancer.

---

## 25. CloudFront

CloudFront was placed in front of the Application Load Balancer.

The public application domain was:

`https://ronin.humdaan.co.uk`

The CloudFront origin was:

`https://origin.ronin.humdaan.co.uk`

The default CloudFront behaviour had caching disabled because RONIN contains dynamic application and API traffic.

A separate CloudFront behaviour was created for:

`/static/*`

Static content could therefore benefit from CDN caching without incorrectly caching dynamic API responses.

CloudFront was also configured to redirect HTTP viewer requests to HTTPS.

---

## 26. End-to-End HTTPS Test

The final public deployment was tested using:

`curl -i https://ronin.humdaan.co.uk/health`

The response returned:

`HTTP/2 200`

The response headers also contained CloudFront information including:

- `x-cache`
- `via`
- `x-amz-cf-pop`

The application returned:

`{"status":"ok"}`

This confirmed that the custom domain, Route 53, CloudFront, HTTPS, Application Load Balancer, ECS Fargate and RONIN health endpoint were working together successfully.

---

## 27. CloudFront Troubleshooting

During the initial CloudFront configuration, requesting:

`https://ronin.humdaan.co.uk/health`

returned an HTTP `504` error.

Direct access to the Application Load Balancer was still working correctly.

This helped isolate the issue to the connection between CloudFront and the ALB rather than the ECS/Fargate application itself.

The CloudFront origin was subsequently configured using:

`origin.ronin.humdaan.co.uk`

with the appropriate ACM certificate and HTTPS origin connection.

After correcting the origin configuration, the public CloudFront request successfully returned HTTP `200`.

---

## 28. Why ECS Fargate Instead of EC2?

ECS Fargate was chosen instead of manually deploying the Docker container onto an EC2 instance.

Using EC2 would require additional management of:

- The operating system
- OS patching
- Docker installation and maintenance
- Instance capacity
- Instance replacement
- Server configuration

With Fargate, I define the container requirements while AWS manages the underlying compute infrastructure.

This allows the project to focus more directly on container orchestration, networking, scaling and deployment.

---

## 29. Why ECS Instead of Vercel or Netlify?

RONIN was deliberately deployed using ECS because one of the main purposes of the project is to demonstrate container and cloud infrastructure skills.

A highly managed application hosting platform would hide much of the infrastructure that this project is intended to demonstrate.

Using ECS allowed the project to demonstrate practical knowledge of:

- Docker
- ECR
- ECS
- Fargate
- VPC networking
- Public and private subnets
- Load balancing
- Health checks
- IAM roles
- Auto Scaling
- CloudWatch
- HTTPS
- DNS
- Infrastructure as Code
- CI/CD

---

## 30. ClickOps Teardown

Once the deployment was working correctly and the required evidence had been captured, the manually created infrastructure was destroyed.

This was intentional because the next stage of the assignment is to recreate the infrastructure using Terraform.

The manual ClickOps deployment provided a known-working architecture that can now be reproduced using Infrastructure as Code.

Resources removed included:

- CloudFront distribution
- Route 53 application records
- ECS Service
- ECS Cluster
- ECS task definition revisions
- Application Load Balancer
- Target groups
- EventBridge schedule
- Lambda function
- DynamoDB table
- S3 reports bucket
- ECR repository
- CloudWatch log groups
- VPC Gateway Endpoints
- NAT Gateways
- Elastic IP addresses
- Internet Gateway
- VPC and associated networking resources
- RONIN IAM roles
- ACM certificates
- ACM validation DNS records

---

## 31. Route 53 Hosted Zone Preserved

One resource was deliberately not destroyed:

`ronin.humdaan.co.uk`

The Route 53 public hosted zone was preserved.

The application records and ACM validation records were removed, leaving the hosted zone's required:

- NS record
- SOA record

The hosted zone was preserved because Cloudflare already delegates `ronin.humdaan.co.uk` to the Route 53 nameservers assigned to this zone.

Deleting and recreating the hosted zone could result in a new set of Route 53 nameservers and would therefore break the existing Cloudflare delegation until it was manually updated.

The Terraform implementation will need to account for this existing DNS boundary rather than blindly recreating the hosted zone.

---

## 32. Key Troubleshooting and Lessons Learned

Several useful issues were encountered during the manual deployment.

### Fargate Port Permission Error

The first Fargate deployment failed because the non-root `ronin` container user could not bind to privileged port 80.

CloudWatch Logs revealed:

`[Errno 13] Permission denied`

The internal container port was changed to `8080` instead of running the container as root.

### CloudWatch Log Group Error

An initial ECS task also failed during resource initialisation because the expected CloudWatch log group did not exist.

The required log group was created and the task was redeployed.

### Lambda AccessDenied

The Lambda function initially failed to read DynamoDB because it was using the wrong IAM execution role.

The function was changed to use `ronin-lambda-weekly-role`, after which the execution succeeded.

### CloudFront 504

CloudFront initially returned an HTTP `504` even though direct ALB requests worked.

This isolated the problem to the CloudFront-to-ALB origin connection.

The CloudFront origin configuration and HTTPS origin certificate were corrected, after which the public application returned HTTP `200`.

### DNS Delegation

The entire `humdaan.co.uk` domain could not simply be moved to Route 53 while retaining the existing Cloudflare setup.

Instead, `ronin.humdaan.co.uk` was delegated from the Cloudflare-managed parent domain to a Route 53 hosted zone.

This allowed Route 53 to be used specifically for RONIN without disrupting the rest of the domain.

---

## Day 3 Result

By the end of Day 3, RONIN had been successfully deployed as a highly available containerised AWS application using a production-style architecture.

The deployment demonstrated:

- Custom VPC networking
- Public and private subnet separation
- Multi-AZ deployment
- Private Fargate workloads
- NAT Gateway outbound connectivity
- S3 and DynamoDB VPC Gateway Endpoints
- Application Load Balancing
- Health checking
- HTTP to HTTPS redirection
- ECS Service Auto Scaling
- Least-privilege IAM
- DynamoDB persistence
- S3 report storage
- Scheduled Lambda processing
- EventBridge Scheduler
- Centralised CloudWatch logging
- Route 53 DNS
- Cloudflare subdomain delegation
- ACM certificates
- CloudFront
- Static asset caching
- Custom HTTPS domain
- End-to-end application testing
- Practical AWS troubleshooting
- Manual infrastructure teardown

The ClickOps deployment was then destroyed after evidence was captured, leaving the delegated `ronin.humdaan.co.uk` Route 53 hosted zone in place for the next stage.

The next stage is to recreate the infrastructure using modular Terraform with remote state and state locking, followed by automated CI/CD using GitHub Actions and AWS OIDC.

TIME LOG: + 5 & 1/2 hours

# Day 4 — Terraform Infrastructure as Code

## Objective

Day 4 focused on starting the Infrastructure as Code stage of RONIN.

After building and testing the infrastructure manually through ClickOps on Day 3, I began recreating the architecture using Terraform.

The main focus today was:

- Setting up the Terraform project structure
- Splitting the infrastructure into modules
- Creating the root Terraform configuration
- Configuring variables and outputs
- Setting up remote Terraform state
- Enabling S3 state locking
- Connecting modules together
- Preparing the project for the remaining Terraform deployment work

---

## Terraform Project Structure

The Terraform configuration was created inside the `infra/` directory.

Rather than putting the entire infrastructure into one large `main.tf`, the configuration was separated into modules.

The root Terraform configuration is responsible for calling these modules and passing information between them.

This structure was chosen because the assignment requires modular Terraform and it also makes the infrastructure easier to maintain and understand.

---

## Terraform Modules

The AWS infrastructure was separated into modules based on responsibility.

Each module generally contains:

- `main.tf` — resources created by the module
- `variables.tf` — values the module receives
- `outputs.tf` — values the module exposes

The basic pattern used throughout the project is:

**Variables go into a module, resources are created, and outputs expose information that other parts of the infrastructure need.**

---

## Connecting Modules

One of the main things implemented and reviewed today was how modules pass information between each other through the root configuration.

For example, the VPC module exposes the ID of the VPC:

```hcl
output "vpc_id" {
  description = "ID of the RONIN VPC"
  value       = aws_vpc.main.id
}
```

The root `main.tf` can then pass that value into the ALB module:

```hcl
module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}
```

In this example:

```hcl
module.vpc.vpc_id
```

retrieves the `vpc_id` output from the VPC module.

The value is then passed into the ALB module through its `vpc_id` variable.

The same approach is used for the public subnet IDs.

This allows modules to remain separate while still sharing the information required to build the complete infrastructure.

---

## Terraform State

I also reviewed how Terraform state works.

Terraform state is Terraform's persistent record of the infrastructure it manages.

For example, Terraform may create:

```hcl
aws_vpc.main
```

and AWS may assign the real VPC an ID such as:

```text
vpc-0123456789
```

Terraform state keeps track of the relationship between the Terraform resource and the real AWS resource.

This allows Terraform to understand what it already manages when running commands such as:

```bash
terraform plan
terraform apply
terraform destroy
```

---

## Remote Terraform Backend

Rather than relying on Terraform state stored only on the local machine, the project was configured to use a remote backend.

Amazon S3 is used to store the Terraform state centrally.

This is important because Terraform will eventually run from both:

- My local development environment
- GitHub Actions

Both environments therefore need access to the same Terraform state.

A remote backend is also a mandatory requirement of the assignment.

---

## S3 State Locking

S3 state locking was enabled using:

```hcl
use_lockfile = true
```

State locking prevents conflicting Terraform operations from modifying the same shared state simultaneously.

For example, if one Terraform process is performing an operation against the state, another conflicting operation should not modify that same state at the same time.

This will become particularly useful once Terraform deployments are automated through GitHub Actions.

---

## Existing Route 53 Hosted Zone

The existing Route 53 hosted zone for:

```text
ronin.humdaan.co.uk
```

was preserved from the ClickOps deployment.

This was intentional because Cloudflare already delegates the RONIN subdomain to the AWS nameservers assigned to this hosted zone.

Recreating the hosted zone could generate different nameservers and break the existing delegation.

The Terraform configuration therefore needs to work with this existing DNS boundary rather than unnecessarily replacing it.

---

## Git and Docker Ignore Updates

The project ignore files were also updated to account for the new Terraform configuration.

### `.gitignore`

Terraform-generated and potentially sensitive files were excluded from Git, including:

```gitignore
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfplan
*.tfvars
*.tfvars.json
```

Terraform configuration itself remains committed to Git.

`.terraform.lock.hcl` is also **not ignored**, because the dependency lock file should be committed so that consistent Terraform provider versions can be used locally and later in CI/CD.

### `.dockerignore`

The Terraform infrastructure directory was excluded from the Docker build context:

```dockerignore
infra
```

The RONIN application container does not require Terraform configuration, so there is no reason to include the infrastructure files when building the application image.

The `.dockerignore` was also cleaned up to remove a duplicate `infra` entry.

---

## Day 4 Key Takeaways

The main Terraform concepts reinforced today were:

- Terraform state keeps track of the infrastructure Terraform manages.
- A Terraform backend determines where the state is stored.
- RONIN uses S3 as a remote backend rather than relying only on local state.
- `use_lockfile = true` enables S3 state locking.
- The infrastructure is separated into Terraform modules.
- `variables.tf` defines information going into a module.
- `outputs.tf` exposes information coming out of a module.
- The root `main.tf` connects modules together.
- Module outputs can be passed into other modules as variables.
- Terraform-generated state and sensitive variable files must not be committed to Git.
- Terraform source code should be committed to Git.
- Terraform infrastructure files do not need to be included in the RONIN Docker image.

---

## Day 4 Result

Day 4 established the Terraform foundation for RONIN.

The Terraform project is now structured around modules, the relationship between variables and outputs has been established, and remote state/state locking have been prepared for the Infrastructure as Code deployment.

The remaining Terraform work will continue on Day 5.

The next stage is to complete the remaining Terraform configuration, validate and plan the infrastructure, deploy it to AWS, and verify that RONIN is working correctly through the Terraform-created environment.

After the Terraform deployment is complete, the project can move into the GitHub Actions and OIDC CI/CD stage.

TIME LOG: + 3 & 1/2 hours

# Day 5 — Terraform Infrastructure as Code (Part 2)

## Overview

Today we completed the remaining Terraform modules from yesterday, deployed the full RONIN infrastructure, and tested the completed architecture end-to-end.

---

# 1. Modules Completed Today

The core Terraform foundation had already been built yesterday, including:

- VPC
- ALB
- ECR
- IAM
- Storage

Today we completed the remaining modules needed to finish the architecture.

## ACM Module

Created and validated the HTTPS certificates required by RONIN.

Two certificates are used:

```text
ronin.humdaan.co.uk
→ CloudFront viewer certificate
→ us-east-1

origin.ronin.humdaan.co.uk
→ ALB origin certificate
→ eu-west-2
```

Both certificates use Route53 DNS validation.

This gives us:

```text
User
  ↓ HTTPS
CloudFront
  ↓ HTTPS
ALB
```

---

## ECS Module

Completed the ECS/Fargate infrastructure.

Terraform now creates:

```text
ronin-cluster
    ↓
ronin-service
    ├── Fargate Task
    └── Fargate Task
```

Configuration:

```text
Desired tasks: 2
Minimum tasks: 2
Maximum tasks: 4
CPU scaling target: 70%
Container port: 8080
Public IP: Disabled
```

The Fargate tasks run inside the private subnets.

The ECS security group only allows port `8080` from the ALB security group.

CloudWatch logging was also configured:

```text
/ecs/ronin-task
Retention: 7 days
```

---

## CloudFront Module

Added CloudFront in front of the ALB.

The public domain is:

```text
ronin.humdaan.co.uk
```

CloudFront uses:

```text
origin.ronin.humdaan.co.uk
```

as its origin, which points to the ALB.

Dynamic application traffic has caching disabled.

Static content:

```text
/static/*
```

uses CloudFront's optimised caching policy.

The request path is therefore:

```text
User
 ↓
CloudFront
 ↓ HTTPS
ALB
 ↓
Fargate
```

---

## Route53 Module

Completed the DNS records required for the application.

Terraform creates:

```text
ronin.humdaan.co.uk
→ CloudFront
```

and:

```text
origin.ronin.humdaan.co.uk
→ ALB
```

The existing `ronin.humdaan.co.uk` Route53 hosted zone remains separate and is read by Terraform as a data source rather than created by Terraform.

---

## Lambda Module

Created:

```text
ronin-weekly-summary
```

The Lambda function reads analysis information from DynamoDB and generates a weekly summary.

The report is written to:

```text
s3://ronin-reports/weekly/YYYY-MM-DD/summary.json
```

The Lambda has its own limited IAM permissions for:

```text
DynamoDB Scan
S3 PutObject
CloudWatch Logs
```

---

## EventBridge Scheduler

Added the automatic schedule for the weekly Lambda.

Schedule:

```text
Every Sunday
09:00
Europe/London
```

Flow:

```text
EventBridge Scheduler
        ↓
Lambda
        ↓
DynamoDB
        ↓
Weekly summary
        ↓
S3
```

---

# 2. Full Terraform Architecture Completed

With today's modules added to yesterday's modules, the complete application path became:

```text
Route53
   ↓
CloudFront
   ↓ HTTPS
ALB
   ↓
Target Group
   ↓
ECS Fargate
   ├── Task 1
   └── Task 2
        ↓
RONIN
   ├── DynamoDB
   └── S3
```

The scheduled reporting path is:

```text
EventBridge Scheduler
        ↓
Lambda
        ↓
DynamoDB
        ↓
S3 Weekly Report
```

---

# 3. Terraform Deployment

The completed Terraform infrastructure was deployed successfully.

We initially had to create ECR first so that the existing `ronin:v3` Docker image could be pushed before ECS attempted to start its tasks.

After the image was available, the full infrastructure was deployed.

We encountered one CloudFront issue caused by an incorrect AWS-managed `CachingDisabled` policy ID.

The correct policy was:

```text
Managed-CachingDisabled
4135ea2d-6df8-44a3-9df3-4b5a84be39ad
```

After correcting this, the Terraform deployment completed successfully.

---

# 4. ECS Tests

We checked the ECS service after deployment.

Result:

```text
Status: ACTIVE
Desired: 2
Running: 2
Pending: 0
```

This confirmed both Fargate tasks successfully started and remained running.

---

# 5. ALB Health Test

The ALB target group was checked.

Two Fargate targets were registered:

```text
10.0.11.37:8080
10.0.12.227:8080
```

Both returned:

```text
healthy
```

This confirmed:

```text
ALB
 ↓
Target Group
 ↓
Fargate :8080
 ↓
/health
```

was working correctly.

---

# 6. Public HTTPS Test

The public application was tested using:

```bash
curl -i https://ronin.humdaan.co.uk/health
```

Result:

```text
HTTP/2 200
```

Response:

```json
{"status":"ok"}
```

CloudFront headers were also returned, confirming the request was passing through CloudFront.

This verified the complete public path:

```text
ronin.humdaan.co.uk
 ↓
Route53
 ↓
CloudFront
 ↓
ALB
 ↓
Fargate
 ↓
RONIN
```

---

# 7. RONIN Analysis Test

We tested the actual application endpoint:

```bash
curl -i -X POST https://ronin.humdaan.co.uk/api/analyse
```

Result:

```text
HTTP/2 201
```

RONIN processed:

```text
20 demo resources
```

and generated:

```text
4 findings
```

The analysis completed successfully and returned:

```text
saved: true
```

---

# 8. DynamoDB Test

We checked the `ronin-analyses` DynamoDB table after running the analysis.

The generated analysis record existed with:

```text
Analysis ID: analysis-59c903fa
Resources checked: 20
Findings: 4
Status: completed
```

This confirmed:

```text
Fargate
 ↓
ECS Task Role
 ↓
DynamoDB
```

was working correctly.

---

# 9. S3 Test

We checked the `ronin-reports` S3 bucket.

The generated report existed at:

```text
analyses/analysis-59c903fa.json
```

This matched the analysis stored in DynamoDB.

This confirmed:

```text
RONIN
 ↓
S3
 ↓
Analysis JSON
```

was working correctly.

---

# 10. Lambda Test

The weekly-summary Lambda was manually invoked.

Result:

```text
StatusCode: 200
```

The Lambda returned:

```json
{
  "statusCode": 200,
  "report_key": "weekly/2026-08-31/summary.json",
  "analysis_count": 1
}
```

We then checked S3 and confirmed the weekly report existed:

```text
weekly/2026-08-31/summary.json
```

This verified:

```text
Lambda
 ↓
DynamoDB
 ↓
Generate Summary
 ↓
S3
```

---

# 11. EventBridge Test

The EventBridge Scheduler configuration was checked.

Result:

```text
State: ENABLED
Schedule: cron(0 9 ? * SUN *)
Timezone: Europe/London
Target: ronin-weekly-summary
```

This confirmed the Lambda is scheduled to run automatically every Sunday at 09:00.

---

# 12. Day 5 Result

By the end of today, all remaining Terraform modules were completed and the full infrastructure was successfully tested.

The main application flow was verified:

```text
Route53
 ↓
CloudFront
 ↓
ALB
 ↓
ECS Fargate
 ↓
RONIN
 ├── DynamoDB
 └── S3
```

The automated reporting flow was also verified:

```text
EventBridge
 ↓
Lambda
 ↓
DynamoDB
 ↓
S3
```

The full Terraform environment was then destroyed after testing and evidence was captured, so the AWS resources do not need to remain running while the next stage is developed.

TIME LOG: + 4 hours


