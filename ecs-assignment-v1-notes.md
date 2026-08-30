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

The goal of Day 4 was to begin rebuilding the manually created RONIN AWS infrastructure using Terraform.

The ClickOps deployment from Day 3 proved that the architecture worked correctly. After capturing evidence, the manually created resources were destroyed.

The next stage was to reproduce that infrastructure using Infrastructure as Code rather than manually rebuilding everything through the AWS Console.

The main objectives were:

- Structure the Terraform project correctly
- Use Terraform modules instead of one large configuration
- Understand Terraform state
- Configure a remote Terraform backend
- Use Amazon S3 for remote state
- Enable Terraform state locking
- Understand `main.tf`
- Understand `variables.tf`
- Understand `outputs.tf`
- Understand how modules communicate
- Prepare the infrastructure for automated deployment later through GitHub Actions

---

# 1. What Is Infrastructure as Code?

Infrastructure as Code, or IaC, means defining infrastructure using configuration files rather than manually creating resources through the AWS Console.

Instead of manually creating resources such as:

- VPCs
- Subnets
- Route tables
- NAT Gateways
- Security groups
- Load balancers
- ECS services
- IAM roles
- DynamoDB tables
- S3 buckets

Terraform configuration describes what infrastructure should exist.

Terraform can then communicate with AWS and create those resources.

This makes the infrastructure:

- Repeatable
- Version controlled
- Easier to review
- Easier to reproduce
- Easier to destroy
- Suitable for CI/CD automation

If the RONIN infrastructure needs to be recreated later, the same Terraform configuration can be used instead of manually rebuilding everything through ClickOps.

---

# 2. Terraform Configuration

Terraform uses `.tf` configuration files to describe infrastructure.

For example:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

This tells Terraform that an AWS VPC should exist with the specified CIDR range.

The Terraform configuration represents the infrastructure that I want Terraform to manage.

Terraform can then compare the configuration against the infrastructure it already manages and determine what changes are required.

---

# 3. Terraform State

Terraform needs to keep track of the infrastructure that it manages.

It does this using **Terraform state**.

By default, Terraform can store this information in a file called:

```text
terraform.tfstate
```

Terraform state acts as Terraform's persistent record of the infrastructure it manages.

For example, the Terraform configuration may contain a resource called:

```text
aws_vpc.main
```

After Terraform creates the VPC, AWS may assign the real resource an ID such as:

```text
vpc-0123456789
```

Terraform state records the relationship between:

```text
aws_vpc.main
```

and:

```text
vpc-0123456789
```

Terraform can therefore remember that this particular AWS VPC belongs to the `aws_vpc.main` resource in the Terraform configuration.

---

# 4. Configuration, State and Real Infrastructure

There are three related but different things to understand.

## Terraform Configuration

The `.tf` files describe what infrastructure I want Terraform to manage.

For example:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

## Terraform State

Terraform state stores Terraform's persistent knowledge about the resources it manages.

For example:

```text
aws_vpc.main → vpc-0123456789
```

## Real Infrastructure

This is what actually exists inside AWS.

Terraform uses the configuration, its state and information retrieved through the AWS provider to determine what changes are required.

This allows Terraform to determine whether resources need to be:

- Created
- Modified
- Replaced
- Destroyed
- Left unchanged

---

# 5. Terraform Plan

The command:

```bash
terraform plan
```

allows Terraform to calculate what infrastructure changes would be required.

Terraform may display actions such as:

```text
+ create
~ update
- destroy
```

A Terraform plan does not normally perform the infrastructure changes.

It allows the proposed changes to be reviewed first.

This is useful because it gives me the opportunity to check what Terraform intends to do before AWS resources are modified.

---

# 6. Terraform Apply

The command:

```bash
terraform apply
```

performs the infrastructure changes proposed by Terraform.

For example, Terraform may:

- Create a VPC
- Create subnets
- Create an ALB
- Create ECS resources
- Modify an existing resource
- Destroy a resource that is no longer required

After the operation succeeds, Terraform updates its state to reflect the infrastructure it manages.

Terraform therefore does not simply execute every resource from scratch each time.

It understands what it already manages and calculates the changes required.

---

# 7. Terraform Backend

A Terraform **backend** determines where and how Terraform stores and accesses its state.

By default, Terraform can use a local backend.

This means the Terraform state exists on the computer where Terraform is being executed.

For example:

```text
infra/
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfstate
```

In this example, the Terraform state is tied to the local machine.

---

# 8. Problems With Local Terraform State

Local state is acceptable for basic learning, but it creates problems for larger projects and teams.

If the state exists only on one engineer's computer:

- Other engineers do not automatically have the same state
- CI/CD does not automatically have access to the state
- Losing the local state file could create infrastructure management problems
- Multiple copies of the state could exist
- The infrastructure becomes unnecessarily dependent on one workstation

RONIN will eventually use GitHub Actions to run Terraform.

Therefore, keeping the important Terraform state only on my local computer would not be suitable.

---

# 9. Remote Terraform Backend

A **remote backend** means Terraform state is stored remotely rather than only on the local machine.

For RONIN, Amazon S3 is used for remote Terraform state.

Instead of relying only on:

```text
./terraform.tfstate
```

the Terraform state is stored centrally inside an S3 bucket.

This means authorised Terraform processes can access the same state.

For example:

- Terraform running from my computer
- Terraform running from GitHub Actions
- Another authorised engineer

can all work against the same central Terraform state.

---

# 10. Why S3 Is Used

Amazon S3 provides durable remote object storage.

A Terraform state file is data that needs to be stored reliably and accessed by Terraform.

A dedicated S3 bucket can therefore be used to store the Terraform state.

Terraform can retrieve the state before performing operations and update it after successful infrastructure changes.

The state bucket is infrastructure used by Terraform itself rather than application storage used by RONIN.

---

# 11. S3 Backend Configuration

A Terraform S3 backend configuration can look similar to:

```hcl
terraform {
  backend "s3" {
    bucket       = "terraform-state-bucket"
    key          = "ronin/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}
```

Each value has a particular purpose.

---

# 12. Backend Bucket

The following setting:

```hcl
bucket = "terraform-state-bucket"
```

tells Terraform which S3 bucket should contain the Terraform state.

The actual S3 bucket name must be globally unique.

This bucket is specifically used to store Terraform's state rather than RONIN application reports.

---

# 13. Backend Key

The following setting:

```hcl
key = "ronin/terraform.tfstate"
```

specifies where the Terraform state should be stored inside the S3 bucket.

For example, the state object could exist at:

```text
ronin/terraform.tfstate
```

inside the backend bucket.

---

# 14. Backend Region

The following setting:

```hcl
region = "eu-west-2"
```

tells Terraform which AWS region contains the S3 backend bucket.

RONIN primarily uses the London AWS region:

```text
eu-west-2
```

---

# 15. Terraform State Locking

Remote state introduces another potential problem.

Two engineers, or an engineer and a CI/CD pipeline, could attempt to modify the same infrastructure at approximately the same time.

For example, one engineer could run:

```bash
terraform apply
```

while another Terraform process is also attempting to change the same infrastructure.

This could result in conflicting operations.

Terraform state locking helps prevent this.

When a Terraform operation obtains the state lock, another conflicting operation cannot safely modify that same state until the first operation finishes and releases the lock.

---

# 16. S3 State Locking

RONIN uses native S3 state locking.

This is enabled using:

```hcl
use_lockfile = true
```

In simple terms, this tells the S3 backend to use a lock file to coordinate Terraform operations.

If one Terraform process has obtained the state lock, another conflicting Terraform process must wait until the lock is released.

This becomes particularly important when Terraform can be executed from both:

- My local computer
- GitHub Actions

State locking therefore helps protect the shared Terraform state from conflicting operations.

---

# 17. Why Remote State and Locking Matter for CI/CD

Later in the project, GitHub Actions will run Terraform automatically.

Terraform will therefore no longer run exclusively from my local development environment.

Both my local Terraform installation and GitHub Actions need to understand the same infrastructure.

Using an S3 remote backend provides the shared state.

State locking helps ensure that conflicting Terraform operations do not attempt to modify the shared state simultaneously.

Remote state and locking are therefore important foundations for the later CI/CD implementation.

They are also mandatory requirements of the assignment.

---

# 18. Terraform Modules

The RONIN Terraform configuration is structured using **modules**.

A Terraform module is a collection of Terraform configuration responsible for a particular part of the infrastructure.

Instead of placing every AWS resource inside one very large `main.tf`, the infrastructure can be separated into logical components.

Examples include modules responsible for:

- VPC networking
- Application Load Balancer
- ECS
- IAM
- ECR
- Storage
- Lambda
- EventBridge
- ACM
- DNS
- CloudFront

This makes the Terraform configuration easier to understand, maintain and reuse.

---

# 19. Root Module

The main Terraform directory is known as the **root module**.

The root module acts as the main orchestration layer.

It calls the child modules and connects them together.

For example:

```hcl
module "vpc" {
  source = "./modules/vpc"
}
```

This tells Terraform to load a child module from:

```text
./modules/vpc
```

The root module can then take information produced by the VPC module and pass that information into another module.

---

# 20. Child Modules

The modules inside the `modules/` directory are child modules.

A simplified structure could look like:

```text
infra/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
├── backend.tf
└── modules/
    ├── vpc/
    ├── alb/
    ├── ecs/
    ├── iam/
    ├── storage/
    ├── lambda/
    └── cloudfront/
```

Each module focuses on a particular responsibility.

For example:

- VPC module manages networking
- ALB module manages load balancing
- ECS module manages container deployment
- Storage module manages DynamoDB and S3
- Lambda module manages scheduled background processing

This creates a clear separation of responsibilities.

---

# 21. Typical Files Inside a Module

A Terraform module commonly contains:

```text
main.tf
variables.tf
outputs.tf
```

These files have different responsibilities.

A useful mental model is:

```text
variables.tf = information going IN

main.tf = work/resources created

outputs.tf = information coming OUT
```

---

# 22. main.tf

Inside a child module, `main.tf` normally contains the resources that the module creates.

For example, the VPC module may contain:

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}
```

This creates an AWS VPC.

Inside the root module, `main.tf` is primarily responsible for calling and connecting the child modules.

For example:

```hcl
module "vpc" {
  source = "./modules/vpc"
}
```

and:

```hcl
module "alb" {
  source = "./modules/alb"

  vpc_id = module.vpc.vpc_id
}
```

---

# 23. variables.tf

`variables.tf` defines information that a module expects to receive from outside.

For example:

```hcl
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}
```

This means the module expects an input called:

```text
vpc_id
```

Inside the module, that value can be accessed using:

```hcl
var.vpc_id
```

Variables are therefore **inputs into a module**.

The easiest way to remember this is:

```text
Variables = IN
```

---

# 24. outputs.tf

`outputs.tf` defines information that a module deliberately makes available outside itself.

For example, the VPC module may create:

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}
```

After AWS creates the VPC, it assigns the VPC an ID.

Terraform can access that ID using:

```hcl
aws_vpc.main.id
```

The VPC module can expose that value using:

```hcl
output "vpc_id" {
  description = "ID of the RONIN VPC"
  value       = aws_vpc.main.id
}
```

Outputs are therefore **information coming out of a module**.

The easiest way to remember this is:

```text
Outputs = OUT
```

---

# 25. Understanding `aws_vpc.main.id`

Consider:

```hcl
value = aws_vpc.main.id
```

This can be broken down into three parts.

```text
aws_vpc
```

refers to the Terraform AWS VPC resource type.

```text
main
```

is the Terraform name given to that particular resource.

```text
id
```

asks Terraform for the ID attribute of that resource.

If AWS created:

```text
vpc-0123456789
```

then:

```hcl
aws_vpc.main.id
```

would evaluate to that VPC ID.

---

# 26. Understanding the Output Name

Consider:

```hcl
output "vpc_id" {
  description = "ID of the RONIN VPC"
  value       = aws_vpc.main.id
}
```

The name:

```text
vpc_id
```

is simply the name chosen for the output.

It is not automatically linked to AWS.

The following line determines what the output actually contains:

```hcl
value = aws_vpc.main.id
```

If:

```hcl
aws_vpc.main.id
```

evaluates to:

```text
vpc-0123456789
```

then the module exposes that value under the output name:

```text
vpc_id
```

Conceptually:

```text
vpc_id = vpc-0123456789
```

---

# 27. Why Outputs Are Needed

A module may create resources that other modules need information about.

For example, the VPC module creates:

- VPC
- Public subnets
- Private subnets

The ALB module needs to know:

- Which VPC it belongs to
- Which public subnets it should use

Instead of making the ALB module depend directly on the internal implementation of the VPC module, the VPC module exposes the required information through outputs.

This creates a clean boundary between the modules.

---

# 28. Passing Information Between Modules

A key Terraform pattern learned during Day 4 was:

1. A module creates a resource.
2. AWS assigns information to that resource.
3. The module exposes required information using an output.
4. The root module accesses that output.
5. The root module passes the value into another module.
6. The receiving module accepts it through a variable.

This allows separate Terraform modules to work together without tightly coupling their internal configurations.

---

# 29. VPC to ALB Example

The VPC module contains:

```hcl
output "vpc_id" {
  description = "ID of the RONIN VPC"
  value       = aws_vpc.main.id
}
```

The root `main.tf` contains:

```hcl
module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}
```

The important line is:

```hcl
vpc_id = module.vpc.vpc_id
```

---

# 30. Understanding `module.vpc.vpc_id`

The expression:

```hcl
module.vpc.vpc_id
```

can be broken down into three parts.

```text
module
```

means the value is coming from a Terraform module.

```text
vpc
```

refers to the module called `vpc`.

```text
vpc_id
```

refers to the output called `vpc_id` exposed by that module.

Therefore:

```hcl
module.vpc.vpc_id
```

means:

> Get the `vpc_id` output from the VPC module.

If the VPC module created:

```text
vpc-0123456789
```

then:

```hcl
module.vpc.vpc_id
```

will provide that value to the root module.

---

# 31. Understanding the Full ALB Assignment

Consider:

```hcl
vpc_id = module.vpc.vpc_id
```

The right-hand side:

```hcl
module.vpc.vpc_id
```

gets the VPC ID from the VPC module.

The left-hand side:

```hcl
vpc_id =
```

passes that value into the ALB module's `vpc_id` input.

The ALB module defines the input using something similar to:

```hcl
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}
```

The ALB module can then use the value internally with:

```hcl
var.vpc_id
```

If the actual VPC ID was:

```text
vpc-0123456789
```

then conceptually the ALB module receives:

```text
vpc_id = vpc-0123456789
```

---

# 32. Public Subnet IDs Example

The same process is used for:

```hcl
public_subnet_ids = module.vpc.public_subnet_ids
```

The VPC module creates the public subnets.

Its `outputs.tf` can expose their IDs:

```hcl
output "public_subnet_ids" {
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}
```

The root module accesses the output using:

```hcl
module.vpc.public_subnet_ids
```

and passes the result into the ALB module.

The ALB therefore knows which public subnets it should use without hardcoding the subnet IDs.

---

# 33. Module Communication

An important lesson from Day 4 was that modules should not need to directly reach into each other's internal implementation.

Instead, modules communicate through clearly defined inputs and outputs.

For example:

The VPC module creates networking resources.

The VPC module exposes:

- VPC ID
- Public subnet IDs
- Private subnet IDs

The root module receives those outputs.

The root module then passes the required values into:

- ALB module
- ECS module
- Other modules that need networking information

The root module therefore acts as the connection point between the child modules.

---

# 34. Module Mental Model

A useful way to understand a Terraform module is to compare it to a function.

A function receives inputs, performs work and can return outputs.

A Terraform module works similarly.

For example, a VPC module may receive inputs such as:

- VPC CIDR
- Subnet CIDRs
- Availability Zones

It creates resources such as:

- VPC
- Public subnets
- Private subnets
- Route tables
- NAT Gateways

It can then return outputs such as:

- VPC ID
- Public subnet IDs
- Private subnet IDs

Other modules can use those outputs as their own inputs.

---

# 35. Terraform Dependency Awareness

Passing outputs from one module into another also tells Terraform that a dependency exists.

For example:

```hcl
vpc_id = module.vpc.vpc_id
```

shows Terraform that the ALB module requires information produced by the VPC module.

Terraform can therefore understand that the required VPC resource must exist before resources that depend on its ID can be fully created.

Terraform uses these references to construct a dependency graph and determine an appropriate resource creation order.

---

# 36. Why Modules Are Better Than One Huge main.tf

It would technically be possible to place the entire RONIN infrastructure inside one enormous `main.tf`.

However, this would become difficult to:

- Read
- Navigate
- Troubleshoot
- Maintain
- Reuse
- Explain

Using modules provides:

- Separation of responsibilities
- Cleaner configuration
- Easier troubleshooting
- Reusability
- Clear dependencies
- Better project organisation

This is particularly important for RONIN because the final architecture contains many different AWS services.

The assignment also specifically requires Terraform modules rather than one giant Terraform file.

---

# 37. Existing Route 53 Hosted Zone

During the ClickOps teardown, the Route 53 hosted zone for:

```text
ronin.humdaan.co.uk
```

was deliberately preserved.

The hosted zone already has AWS Route 53 nameservers assigned to it.

The parent domain:

```text
humdaan.co.uk
```

is managed through Cloudflare.

Cloudflare contains NS delegation records that delegate:

```text
ronin.humdaan.co.uk
```

to the nameservers assigned to the existing Route 53 hosted zone.

Deleting and recreating the hosted zone could generate a different set of Route 53 nameservers.

The Cloudflare delegation would then point to the old nameservers and DNS would stop working correctly.

The Terraform configuration therefore needs to account for this existing DNS infrastructure rather than blindly creating another hosted zone.

---

# 38. Terraform and Existing Infrastructure

Terraform does not automatically manage every AWS resource that already exists inside an AWS account.

Terraform primarily manages infrastructure represented by its configuration and state.

Existing resources can sometimes be:

- Referenced using Terraform data sources
- Brought under Terraform management using Terraform import

This distinction is important for RONIN because the Route 53 hosted zone already exists and was intentionally preserved.

The Terraform implementation needs to handle this resource carefully rather than unnecessarily destroying and recreating it.

---

# 39. Planned Terraform Infrastructure

The Terraform implementation will ultimately recreate the architecture previously proven through ClickOps.

This includes:

- Custom VPC
- Two public subnets
- Two private application subnets
- Internet Gateway
- NAT Gateways
- Elastic IPs
- Public route table
- Private route tables
- S3 Gateway Endpoint
- DynamoDB Gateway Endpoint
- Security groups
- ECR
- IAM roles and policies
- CloudWatch Logs
- Application Load Balancer
- Target group
- HTTP listener
- HTTPS listener
- ECS cluster
- ECS task definition
- ECS Fargate service
- ECS Service Auto Scaling
- DynamoDB
- S3
- Lambda
- EventBridge Scheduler
- ACM certificates
- Route 53 application records
- CloudFront

The purpose is not to invent a new architecture.

Terraform will reproduce the architecture that was already manually deployed, tested and proven during the ClickOps stage.

---

# 40. ECR and ECS Deployment Dependency

There is an important dependency between ECR and ECS.

Terraform can create the ECR repository.

However, ECS requires a valid RONIN container image to exist inside ECR before the Fargate application can successfully start.

Therefore, the deployment needs to account for the order of operations.

The planned process is:

1. Terraform creates foundational infrastructure and ECR.
2. The RONIN Docker image is built.
3. The image is pushed into ECR.
4. Terraform deploys ECS using the available image.
5. Later, GitHub Actions automates the image build and push process.

This avoids attempting to launch Fargate tasks using an image that does not yet exist.

---

# 41. Terraform Formatting

Terraform provides:

```bash
terraform fmt
```

This automatically formats Terraform configuration into Terraform's standard formatting style.

This improves consistency and readability.

It is useful both locally and later inside CI/CD.

---

# 42. Terraform Validation

Terraform provides:

```bash
terraform validate
```

This checks whether the Terraform configuration is syntactically valid and internally consistent.

It can identify configuration problems before infrastructure is deployed.

Validation should be performed before applying infrastructure changes.

---

# 43. Terraform Planning

Before deploying infrastructure, Terraform can generate a plan using:

```bash
terraform plan
```

The plan should be reviewed carefully.

It shows which resources Terraform intends to:

- Create
- Modify
- Replace
- Destroy

This provides an important safety step before infrastructure changes are made.

---

# 44. Terraform Apply

Once the plan has been reviewed, infrastructure can be deployed using:

```bash
terraform apply
```

Terraform performs the required AWS changes.

After a successful deployment, Terraform updates the remote state stored in S3.

The resulting infrastructure can then be tested in the same way as the original ClickOps deployment.

---

# 45. Terraform Destroy

Terraform can remove infrastructure it manages using:

```bash
terraform destroy
```

Terraform uses its configuration and state to determine which managed resources should be removed.

The destroy plan should be reviewed before confirming the operation.

This provides a much more consistent teardown process than manually finding and deleting every resource through the AWS Console.

---

# 46. Relationship to CI/CD

The Terraform work prepares RONIN for the CI/CD stage.

Eventually, GitHub Actions will run Terraform against the same remote S3 state.

GitHub Actions will also automate the RONIN application deployment.

The planned automation includes:

- Terraform formatting
- Terraform validation
- Terraform planning
- Terraform deployment
- Terraform destroy
- Docker image build
- Docker image tagging
- ECR image push
- ECS deployment
- Post-deployment health checking

AWS authentication will use GitHub OIDC rather than permanent AWS access keys stored as GitHub secrets.

---

# 47. Why GitHub Actions Needs the Remote State

When Terraform runs from GitHub Actions, it is running on a GitHub-hosted runner rather than my local computer.

That runner does not automatically have my local:

```text
terraform.tfstate
```

Using S3 solves this problem.

Both my local Terraform environment and GitHub Actions can access the same remote state.

This ensures that Terraform understands the same RONIN infrastructure regardless of where Terraform is being executed.

State locking then protects that shared state from conflicting operations.

---

# 48. Key Terraform Concepts Learned

## Resource

A Terraform block representing infrastructure Terraform creates or manages.

Example:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

## Variable

An input into a Terraform configuration or module.

Example:

```hcl
variable "vpc_id" {
  type = string
}
```

Referenced using:

```hcl
var.vpc_id
```

## Output

Information deliberately exposed by a Terraform module.

Example:

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}
```

## Module

A collection of Terraform configuration responsible for a particular part of the infrastructure.

## Root Module

The main Terraform configuration that calls and connects the child modules.

## Child Module

A module called by another Terraform module.

## State

Terraform's persistent record of the infrastructure it manages and the mapping between Terraform resource addresses and real infrastructure.

## Backend

Determines where and how Terraform stores and accesses its state.

## Remote Backend

Stores Terraform state remotely rather than only on the local machine.

RONIN uses Amazon S3.

## State Locking

Helps protect shared Terraform state from conflicting concurrent operations.

RONIN uses native S3 locking with:

```hcl
use_lockfile = true
```

---

# 49. Most Important Module Pattern

One of the most important Terraform concepts learned during Day 4 was:

```text
Variables go INTO modules.

Outputs come OUT of modules.

The root module connects them together.
```

For example, the VPC module creates the VPC.

It exposes:

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}
```

The root module accesses:

```hcl
module.vpc.vpc_id
```

The root module then passes it into the ALB module:

```hcl
module "alb" {
  source = "./modules/alb"

  vpc_id = module.vpc.vpc_id
}
```

The ALB module receives the value through:

```hcl
variable "vpc_id" {
  type = string
}
```

The ALB module can then use:

```hcl
var.vpc_id
```

This is the basic pattern used to connect separate Terraform modules together.

---

# 50. Day 4 Key Lessons

The most important lessons from Day 4 were:

- Terraform configuration describes the infrastructure Terraform should manage.
- Terraform state records Terraform's knowledge of the infrastructure it manages.
- Terraform state maps Terraform resources to real AWS resources.
- A backend determines where Terraform state is stored and accessed.
- Local state exists on the local machine.
- Remote state is stored centrally.
- RONIN uses Amazon S3 as the remote backend.
- State locking protects shared state from conflicting operations.
- Native S3 locking is enabled using `use_lockfile = true`.
- Terraform modules separate infrastructure into logical components.
- The root module connects the child modules.
- `variables.tf` defines module inputs.
- `outputs.tf` defines module outputs.
- `main.tf` contains resources or connects modules depending on where it is used.
- Outputs allow information created by one module to be used elsewhere.
- The root module can pass one module's output into another module's variable.
- Terraform references also help Terraform understand dependencies between resources and modules.
- Existing infrastructure such as the delegated Route 53 hosted zone must be handled carefully.
- Remote state is particularly important because GitHub Actions will later run Terraform.

---

# Day 4 Result

By the end of Day 4, the Terraform stage of the RONIN project had established the structure and understanding required to recreate the previously tested ClickOps infrastructure as Infrastructure as Code.

The work covered:

- Infrastructure as Code
- Terraform configuration
- Terraform state
- Terraform plan and apply
- Terraform backends
- Local state
- Remote state
- Amazon S3 remote backend
- Terraform state locking
- Native S3 lock files
- Modular Terraform
- Root modules
- Child modules
- `main.tf`
- `variables.tf`
- `outputs.tf`
- Module inputs
- Module outputs
- Passing values between modules
- Terraform dependency awareness
- Existing Route 53 infrastructure
- ECR/ECS deployment dependencies
- Terraform formatting
- Terraform validation
- Terraform planning
- Preparation for GitHub Actions CI/CD

The key mental model from Day 4 is:

**Terraform state is Terraform's memory of the infrastructure it manages.**

**The backend determines where that state lives.**

**A remote S3 backend allows that state to be shared centrally.**

**State locking protects the shared state from conflicting Terraform operations.**

**Variables go into modules, outputs come out of modules, and the root module connects those values together.**

The next stage is to complete and deploy the Terraform-managed RONIN infrastructure, verify the application through the custom HTTPS domain, and then automate the deployment using GitHub Actions and AWS OIDC.

TIME LOG: + 3 & 1/2 hours