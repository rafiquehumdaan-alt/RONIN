# RONIN Request Lifecycle

This document follows a request from a user's browser to a RONIN container running on ECS Fargate.

## Request path

```text
User
  → Cloudflare DNS delegation
  → Route 53 DNS
  → CloudFront
  → Route 53 origin DNS
  → Application Load Balancer
  → ECS Fargate task on port 8080
```

Cloudflare and Route 53 provide DNS answers. The web request does not pass through their DNS servers.

## 1. The browser resolves the domain

The user opens `https://ronin.humdaan.co.uk`.

Cloudflare manages the parent domain, `humdaan.co.uk`. Four NS records in Cloudflare delegate the `ronin.humdaan.co.uk` subdomain to its Route 53 public hosted zone.

Route 53 returns an alias A record pointing `ronin.humdaan.co.uk` to the CloudFront distribution. An alias is used because CloudFront does not have one fixed IP address for Terraform to store.

## 2. The browser connects to CloudFront

The browser connects to a nearby CloudFront edge location over HTTPS. CloudFront presents the ACM certificate for `ronin.humdaan.co.uk`, which is stored in `us-east-1` as required by CloudFront.

CloudFront redirects HTTP visitors to HTTPS. It can cache requests for `/static/*`, while dynamic pages and API requests are forwarded to the origin.

## 3. CloudFront finds the origin

CloudFront's origin is `origin.ronin.humdaan.co.uk`. Route 53 has a second alias A record that points this name to the internet-facing ALB in `eu-west-2`.

CloudFront starts a new HTTPS connection to the ALB. The ALB presents a separate ACM certificate for `origin.ronin.humdaan.co.uk`, stored in `eu-west-2`.

The two encrypted connections are therefore:

```text
Browser  ── HTTPS ──> CloudFront
CloudFront ── HTTPS ──> ALB
```

## 4. The ALB selects a healthy task

The ALB runs across the two public subnets and accepts HTTPS traffic on port 443. Its target group contains the private IP addresses of the running Fargate tasks.

The ALB regularly requests `/health` on port 8080 and only sends user traffic to healthy targets. It chooses a healthy task and forwards the request to that task over HTTP on port 8080.

## 5. The request reaches Fargate

The Fargate task runs in one of the two private application subnets and has no public IP address. Its security group accepts port 8080 only when the source is the ALB security group.

This means an internet user cannot connect directly to a RONIN container. Public requests must pass through CloudFront and the ALB.

The Gunicorn server inside the container receives the request on port 8080 and passes it to the Flask application. RONIN creates the response and returns it through the same application path:

```text
Fargate task → ALB → CloudFront → User
```

## Important distinction

The NAT gateways are not part of this incoming request path. They allow tasks in private subnets to start outbound connections when required. S3 and DynamoDB gateway endpoints provide private routes to those AWS services.

## DNS records involved

| Location | Record | Purpose |
|---|---|---|
| Cloudflare | NS records | Delegate the RONIN subdomain to Route 53 |
| Route 53 | Alias A: `ronin.humdaan.co.uk` | Direct users to CloudFront |
| Route 53 | Alias A: `origin.ronin.humdaan.co.uk` | Direct CloudFront to the ALB |
| Route 53 | ACM validation CNAME records | Prove control of both certificate names |

In one sentence: Cloudflare delegates DNS to Route 53, Route 53 directs the user to CloudFront, CloudFront securely contacts the ALB, and the ALB forwards the request to a healthy private Fargate task on port 8080.
