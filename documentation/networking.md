# Networking

RONIN runs in a `10.0.0.0/16` VPC in `eu-west-2`. It uses two Availability Zones, each with one public subnet and one private subnet.

| Availability Zone | Public subnet | Private subnet |
| --- | --- | --- |
| eu-west-2a | 10.0.1.0/24 | 10.0.11.0/24 |
| eu-west-2b | 10.0.2.0/24 | 10.0.12.0/24 |

## Incoming traffic

Cloudflare delegates `ronin.humdaan.co.uk` to Route 53. The public hostname resolves to CloudFront, and `origin.ronin.humdaan.co.uk` resolves to the Application Load Balancer.

The browser connects to CloudFront over HTTPS. CloudFront can serve cached files under `/static/*`. Dynamic requests go to the ALB over HTTPS. The ALB forwards requests to healthy Fargate task IPs over HTTP on port `8080` and uses `/health` to check the targets.

The ALB spans both public subnets. The Fargate tasks run in the private subnets without public IP addresses.

## Outbound traffic

The public subnets have a route to the internet gateway. Each private subnet has a default route through the NAT gateway in the same Availability Zone. Tasks use this outbound path for ECR image pulls and CloudWatch Logs. Incoming app requests reach the tasks through the ALB.