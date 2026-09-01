# RONIN Infrastructure – Design Reasoning

RONIN is deployed using a resilient, multi-AZ AWS architecture designed to demonstrate practical networking, security, container orchestration, scalability, storage, serverless processing, monitoring and infrastructure automation.

Each AWS service has a defined purpose within the architecture rather than being included purely for additional complexity.

---

## Amazon Route 53

Route 53 provides DNS for RONIN's custom domain and points the application domain towards the CloudFront distribution.

This provides a proper application domain rather than requiring users to access an AWS-generated address.

## Amazon CloudFront

CloudFront provides the public edge/CDN layer in front of the RONIN application.

CloudFront can cache appropriate static content such as CSS, JavaScript and images closer to users, while dynamic application and API requests are forwarded towards the Application Load Balancer.

Caching will only be used where appropriate rather than caching dynamic RONIN responses unnecessarily.

## AWS Certificate Manager (ACM)

ACM provides the TLS certificates required for HTTPS.

Certificates are associated with the appropriate HTTPS endpoints, allowing RONIN to securely accept encrypted traffic without certificates having to be stored or managed inside the application containers.

## Custom VPC

RONIN runs inside a custom VPC using the CIDR range:

`10.0.0.0/16`

Using a custom VPC gives explicit control over subnetting, routing, internet access and security rather than relying on the AWS default VPC.

## Two Availability Zones

The architecture spans two Availability Zones within `eu-west-2`.

Distributing the infrastructure across multiple AZs reduces dependency on a single Availability Zone and provides the foundation for a highly available application.

## Public Subnets

Each Availability Zone contains a public subnet:

- Public Subnet A – `10.0.1.0/24`
- Public Subnet B – `10.0.2.0/24`

The public subnets provide networking for internet-facing infrastructure such as the Application Load Balancer and NAT Gateways.

They have a route to the Internet Gateway and therefore form the public networking tier of the architecture.

## Private Application Subnets

Each Availability Zone also contains a private application subnet:

- Private App Subnet A – `10.0.11.0/24`
- Private App Subnet B – `10.0.12.0/24`

The RONIN Fargate tasks run within these private subnets and are not assigned public IP addresses.

This provides stronger network isolation and ensures application traffic reaches RONIN through the controlled load-balancing infrastructure rather than directly accessing the containers.

## Internet Gateway

An Internet Gateway provides internet connectivity for the VPC's public networking tier.

The public subnets contain a default route towards the Internet Gateway, which allows resources such as the internet-facing ALB and NAT Gateways to provide their required connectivity.

## Public Route Table

The public route table is associated with the public subnets and contains a default route:

`0.0.0.0/0 → Internet Gateway`

This provides the public subnets with their route towards the internet.

## Private Route Tables

The private application subnets do not have a direct route to the Internet Gateway.

Each private subnet instead uses the NAT Gateway located in its corresponding Availability Zone for required outbound internet connectivity.

The planned routes are therefore:

`Private Subnet A → NAT Gateway A`

`Private Subnet B → NAT Gateway B`

## NAT Gateways

A NAT Gateway is placed in each public subnet and associated with an Elastic IP address.

The NAT Gateways allow resources in the private application subnets to initiate required outbound connections without giving the Fargate tasks public IP addresses or allowing internet hosts to initiate connections directly to them.

Using one NAT Gateway per AZ also avoids making both private application subnets dependent on a single NAT Gateway or Availability Zone.

## Application Load Balancer (ALB)

The internet-facing Application Load Balancer provides the entry point to the ECS application tier and acts as the application origin behind CloudFront.

It distributes incoming dynamic application requests between healthy RONIN Fargate tasks.

HTTPS is supported using ACM, while HTTP traffic can be redirected to HTTPS.

The ALB therefore provides load balancing, health-aware routing and secure access to the containerised application tier.

## ALB Security Group

The ALB Security Group controls network access to the load balancer.

It permits the required HTTP/HTTPS traffic while the ECS application tier remains protected by its own Security Group.

This provides a controlled network boundary before traffic reaches the private RONIN containers.

## Target Group

The ALB Target Group uses IP targets representing the private IP addresses of the running Fargate tasks.

It performs health checks against:

`/health`

on RONIN's application port `80`.

The ALB only forwards application requests to targets considered healthy by the Target Group.

## Amazon ECS

Amazon ECS provides container orchestration for RONIN.

ECS manages the desired application state, task lifecycle and integration between the running Fargate tasks and the load balancer.

This avoids having to manually start, monitor and replace individual containers.

## ECS Service

The ECS Service manages the running RONIN tasks and maintains the required number of containers.

The service maintains a minimum of two tasks so that the application does not depend on a single running container.

If a task fails, ECS can launch a replacement to return the service to its desired state.

## AWS Fargate

AWS Fargate provides the compute required to run the RONIN containers without requiring EC2 instances to be provisioned or managed directly.

Each task receives its own network interface and private IP address within one of the private application subnets.

These private IP addresses are registered with the ALB Target Group.

## Two Fargate Tasks

RONIN maintains at least two running Fargate tasks across the multi-AZ application architecture.

The service is configured across private subnets in two Availability Zones so ECS can distribute the workload across the available infrastructure.

This provides redundancy so that if one task becomes unhealthy, the ALB can continue sending traffic to another healthy task while ECS replaces the failed task.

## ECS Service Auto Scaling

The ECS Service is designed with a minimum capacity of two tasks and the ability to scale horizontally when required.

The planned configuration is:

- Minimum tasks: `2`
- Desired tasks: `2`
- Maximum tasks: `4`

This allows RONIN to maintain redundancy while also demonstrating automatic horizontal scaling when application demand increases.

## ECS Task Definition

The ECS Task Definition describes how each RONIN task should run.

It defines configuration including:

- ECR container image
- CPU
- Memory
- Container port
- Logging configuration
- IAM roles

This provides ECS with a repeatable definition that can be used whenever a RONIN task needs to be started or replaced.

## ECS Security Group

The ECS Security Group allows inbound RONIN application traffic on port `80` only from the ALB Security Group.

Internet users therefore cannot directly access the Fargate tasks.

Combining private subnets with restrictive Security Group rules provides defence in depth for the application tier.

## Amazon ECR

Amazon ECR provides the private container registry used to store versioned RONIN Docker images.

ECS/Fargate retrieves the required RONIN image from ECR whenever a new task needs to be started.

This allows the same container artefact that was built and tested to be deployed consistently.

## Amazon DynamoDB

DynamoDB provides RONIN's persistent structured application and analysis data.

When RONIN performs an analysis, the Fargate application can store information such as:

- Analysis ID
- Analysis date
- Resources checked
- Findings
- Severity
- Analysis status
- Recommendations

RONIN can then query this structured data to provide application features such as analysis history and previous findings.

DynamoDB therefore acts as RONIN's application database rather than as storage for downloadable report files.

## Amazon S3

Amazon S3 provides object storage for generated RONIN report files.

When RONIN needs to produce a downloadable or retainable report, the generated report object can be stored in the RONIN S3 report bucket.

This gives S3 a clearly different responsibility from DynamoDB:

`DynamoDB = structured application and analysis data`

`S3 = generated report files`

Some information may naturally appear in both, but the two services serve different purposes.

S3 will also store the weekly summary reports generated by the scheduled Lambda function.

## Amazon EventBridge

Amazon EventBridge provides the schedule for RONIN's automated weekly reporting process.

A scheduled EventBridge rule will invoke the weekly reporting Lambda function at the configured time.

This means the continuously running Fargate application does not need to contain its own scheduling logic or determine when the weekly background job should run.

EventBridge therefore controls **when** the scheduled job starts.

## AWS Lambda

AWS Lambda provides serverless compute for RONIN's scheduled weekly reporting job.

When invoked by EventBridge, the Lambda function reads the relevant week's structured analysis data from DynamoDB.

It then creates a weekly summary containing information such as:

- Number of analyses performed
- Number of resources checked
- Total findings
- Findings by severity
- Common optimisation findings

The generated weekly summary is then stored as a report file in Amazon S3.

The scheduled workflow is therefore:

`EventBridge → Lambda → DynamoDB (read) → S3 (write report)`

Lambda does not replace ECS/Fargate as RONIN's main compute platform.

Fargate remains responsible for the continuously available web application and user-driven operations, while Lambda performs a short scheduled background job independently of the web application.

This demonstrates both long-running containerised compute and scheduled serverless compute within the same application architecture.

## VPC Endpoints

VPC endpoints provide private connectivity between resources inside the VPC and supported AWS services.

Gateway endpoints will be used for S3 and DynamoDB so relevant Fargate traffic can reach these services without travelling through a NAT Gateway or across the public internet.

This provides a more controlled network path and demonstrates private AWS service connectivity.

Other outbound connectivity required by the private Fargate environment can continue to use the NAT Gateways where appropriate.

## IAM Execution Role

The ECS Task Execution Role provides ECS/Fargate with the permissions required to start RONIN tasks, including operations such as retrieving the private container image from ECR and publishing configured container logs.

This separates infrastructure-level task startup permissions from permissions required by the RONIN application itself.

## IAM Task Role

The ECS Task Role provides the RONIN application with the AWS permissions it genuinely requires at runtime.

For example, RONIN can receive specific permissions to read/write its DynamoDB application data and read/write the required S3 report objects.

This allows the application to access AWS services without storing AWS access keys inside the container.

Permissions will be restricted to the required RONIN resources following the principle of least privilege.

## Lambda Execution Role

The weekly reporting Lambda function receives its own IAM Execution Role.

The role provides only the permissions required for the scheduled reporting job, including reading the required RONIN analysis data from DynamoDB, writing the generated weekly report to the designated S3 bucket and publishing logs where required.

This keeps Lambda's permissions separate from the permissions assigned to the ECS application.

## Amazon CloudWatch

CloudWatch provides centralised observability for the RONIN infrastructure.

RONIN container and Lambda logs can be sent to CloudWatch Logs.

AWS metrics can also be used to monitor components such as:

- ECS CPU utilisation
- ECS memory utilisation
- ALB request count
- ALB target response time
- Healthy/unhealthy targets
- Lambda invocations
- Lambda errors

This allows the application and supporting infrastructure to be monitored and troubleshooted without directly accessing the containers.

## CloudWatch Alarms

CloudWatch Alarms provide automated monitoring for important application and infrastructure conditions.

Relevant alarms can monitor conditions such as:

- Unhealthy ALB targets
- High ECS CPU utilisation
- High ECS memory utilisation
- Lambda execution errors

This provides proactive monitoring rather than relying entirely on manual checks.

---

# Overall Application Flow

The main RONIN web request flow is:

`User → Route 53 → CloudFront → ALB → Target Group → ECS Fargate → RONIN`

Route 53 provides DNS resolution, CloudFront provides the edge/CDN layer, the ALB distributes dynamic application requests, and ECS/Fargate runs the containerised RONIN application within private subnets.

RONIN's main persistent data flow is:

`RONIN/Fargate → DynamoDB`

DynamoDB stores the structured analysis and application data that RONIN needs to query and display.

Generated report files use:

`RONIN/Fargate → S3`

S3 provides object storage for downloadable or retainable report files rather than acting as RONIN's primary application database.

The scheduled weekly reporting workflow is:

`EventBridge → Lambda → DynamoDB → S3`

EventBridge invokes Lambda on the configured schedule. Lambda reads the week's analysis data from DynamoDB, generates a weekly summary and stores the resulting report file in S3.

This gives each major component a distinct responsibility:

`Fargate = continuously running RONIN web application`

`DynamoDB = structured application and analysis data`

`S3 = generated report files`

`EventBridge = scheduled trigger`

`Lambda = scheduled weekly report processing`

---

# Services Purposefully Left Out

The architecture is designed to demonstrate a broad range of AWS and DevOps skills while ensuring that each major component has a clear technical purpose.

**Amazon RDS** was not included because RONIN does not currently require a relational database. DynamoDB provides suitable persistent structured storage for the application's analysis data.

**Amazon ElastiCache** was not included because RONIN does not currently have a distributed caching or session-storage requirement that would justify introducing Redis or Memcached.

**EC2 application servers** were not included because ECS Fargate provides the required container compute without requiring the underlying servers to be provisioned or administered directly.

**AWS Secrets Manager** was not included because the current RONIN implementation does not have an application secret that justifies introducing a dedicated secrets-management service.

**AWS Systems Manager / Parameter Store** was not included because the current application does not require external parameter or server-management functionality.

**AWS WAF** was considered but is not currently required for the project. It could later be associated with CloudFront if RONIN required additional web application filtering and protection.

The architecture therefore demonstrates a broad range of AWS and DevOps skills while keeping each component defensible.

The final design focuses on **custom networking, CIDR planning, public and private subnets, NAT, multi-AZ redundancy, containerisation, ECR, ECS/Fargate, load balancing, health checking, HTTPS, CloudFront edge delivery, IAM least privilege, VPC endpoints, DynamoDB structured data, S3 object storage, EventBridge scheduling, Lambda serverless processing, CloudWatch monitoring, auto scaling, Terraform, remote state and CI/CD with OIDC.**