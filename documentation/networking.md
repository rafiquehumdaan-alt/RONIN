# Networking

RONIN runs in the AWS London region (eu-west-2). The VPC uses 10.0.0.0/16 and spans two Availability Zones. Each zone has one public subnet for the load balancer and NAT gateway, and one private subnet for Fargate tasks.

| Availability Zone | Public subnet | Private subnet |
| --- | --- | --- |
| eu-west-2a | 10.0.1.0/24 | 10.0.11.0/24 |
| eu-west-2b | 10.0.2.0/24 | 10.0.12.0/24 |

## DNS and incoming traffic

Cloudflare manages the parent domain and delegates ronin.humdaan.co.uk to Route 53 using NS records. In Route 53, ronin.humdaan.co.uk points to CloudFront and origin.ronin.humdaan.co.uk points to the Application Load Balancer.

1. The browser connects to CloudFront. CloudFront redirects HTTP requests to HTTPS.
2. CloudFront uses HTTPS on port 443 to reach the ALB. Caching is disabled for the main page and API requests. Files under /static/ have a separate caching rule.
3. The ALB forwards requests to Fargate task IPs over HTTP on port 8080.

The ALB sits in both public subnets. The tasks run in the private subnets without public IP addresses. Their security group accepts traffic on port 8080 from the ALB security group.

## Load balancer health checks

The target group checks /health on each task every 30 seconds and expects HTTP 200 within five seconds. The healthy threshold is two successful checks and the unhealthy threshold is three failed checks.

The load balancer checks each task directly. The application workflow also checks /health through the public hostname after a release, so it tests the route a visitor uses.

## Outbound traffic

The public subnets have a default route to the internet gateway. Each private subnet has a default route to the NAT gateway in the same Availability Zone. The tasks use this path to pull images from ECR, download the image layers and send logs to CloudWatch.

I used one NAT gateway per zone so both private subnets have their own outbound path. That adds a second NAT gateway to the running cost, but avoids having both zones depend on the same gateway.

[View the AWS architecture diagram](architecture/architecture-diagram-V4.png)