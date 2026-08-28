# RONIN Infrastructure – Design Reasoning

RONIN is deployed using a simple but resilient AWS architecture. Each component has been chosen for a specific purpose rather than adding services unnecessarily.

## Amazon Route 53

Route 53 provides DNS for RONIN's custom domain and directs users towards the internet-facing Application Load Balancer.

This gives the application a proper, memorable domain rather than requiring users to access an AWS-generated address.

## AWS Certificate Manager (ACM)

ACM provides the TLS certificate used by the Application Load Balancer for HTTPS.

This allows RONIN to securely accept encrypted HTTPS traffic on port 443 without managing certificates inside the application container.

## Custom VPC

RONIN runs inside its own custom VPC rather than relying on the AWS default VPC.

This gives us explicit control over the application's network, including its IP ranges, subnets, routing and security.

## Two Availability Zones

The infrastructure spans two Availability Zones in the `eu-west-2` region.

This prevents the application architecture from depending entirely on a single Availability Zone and allows RONIN's workloads to be distributed for greater resilience.

## Two Public Subnets

A public subnet is created in each Availability Zone.

They provide networking for the internet-facing ALB and the Fargate deployment while allowing the architecture to operate across multiple Availability Zones.

## Internet Gateway

An Internet Gateway provides internet connectivity to the VPC.

The public subnets have a route to the Internet Gateway, which is what makes them public.

## Public Route Table

The public route table controls routing for the two public subnets and contains a default route (`0.0.0.0/0`) towards the Internet Gateway.

This provides a clear and controlled route between resources in the public subnets and the internet.

## Application Load Balancer (ALB)

The ALB provides the public entry point for RONIN and distributes incoming requests between healthy Fargate tasks.

It also handles HTTPS using the ACM certificate and redirects HTTP traffic on port 80 to HTTPS on port 443.

## ALB Security Group

The ALB Security Group allows inbound HTTP/HTTPS traffic on ports 80 and 443 from the internet.

Port 80 is required so the ALB can accept an HTTP request and redirect the user's browser to HTTPS.

## Target Group

The ALB Target Group contains the IP addresses of the running Fargate tasks and performs health checks against RONIN's `/health` endpoint.

The ALB therefore only forwards application traffic to tasks that are considered healthy.

## Amazon ECS

Amazon ECS manages RONIN's container workload.

It provides the orchestration layer responsible for maintaining the application's desired state rather than requiring containers to be managed manually.

## ECS Service

The ECS Service maintains a desired count of **two RONIN tasks**.

Using two tasks provides redundancy: if one task fails, the other healthy task can continue receiving traffic while ECS replaces the failed task.

## AWS Fargate

Fargate provides the compute required to run the RONIN containers without us managing EC2 instances.

Each Fargate task receives its own network interface and private IP address, which can be registered directly with the ALB Target Group.

## Two Fargate Tasks

RONIN runs with a minimum desired count of two Fargate tasks, with the architecture designed to distribute them across the two configured Availability Zones.

This provides better availability than relying on a single running container and allows the ALB to distribute traffic between healthy RONIN tasks.

## ECS Task Definition

The Task Definition describes how a RONIN task should run, including its ECR image, container port, CPU, memory and other runtime configuration.

This provides a repeatable definition that ECS can use whenever it needs to start or replace a task.

## ECS Security Group

The ECS Security Group allows RONIN's port 80 traffic only from the ALB Security Group.

This prevents users on the internet from directly accessing the Fargate tasks and ensures application traffic enters through the load balancer.

## Amazon ECR

Amazon ECR provides the private container registry used to store the RONIN Docker image.

ECS/Fargate can securely retrieve the versioned RONIN image from ECR whenever a new task needs to be started.

## IAM Roles

IAM roles provide ECS/Fargate with only the AWS permissions required to perform operations such as retrieving the private image from ECR and sending application logs.

This avoids storing AWS credentials inside the application and follows the principle of least privilege.

## Amazon CloudWatch Logs

RONIN's container logs are sent to CloudWatch Logs.

This provides centralised application logging and allows the running containers to be monitored and troubleshooted without directly accessing them.

---

# Services Purposefully Left Out

The architecture has intentionally been kept focused on RONIN's actual requirements rather than adding AWS services simply to make the infrastructure more complex.

**NAT Gateway** was not included because the current public-subnet Fargate architecture does not require one. Avoiding it also removes unnecessary infrastructure and cost.

**Private subnets** were not used for the initial assignment architecture. A more security-sensitive production deployment could place ECS tasks in private subnets with appropriate outbound connectivity, but this would introduce additional networking complexity beyond the requirements of this deployment.

**RDS/DynamoDB** were not included because the current RONIN demo does not require persistent application database storage.

**S3** was not included because RONIN does not currently require object storage.

**CloudFront** was not included because the ALB already provides an appropriate entry point for this lightweight application and a CDN is unnecessary for the expected demo workload.

**AWS WAF** was not included because adding a web application firewall would provide limited value for the scope of this pre-beta demonstration.

**NAT Gateway, VPC endpoints and other advanced networking services** can be introduced in a more production-focused architecture if RONIN's security, scale or connectivity requirements increase.

The overall design therefore prioritises **containerisation, redundancy, health checking, HTTPS, controlled network access, managed compute and clear infrastructure boundaries without introducing services that RONIN does not currently need.**