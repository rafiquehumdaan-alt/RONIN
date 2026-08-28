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

All work done on this document prior to this message was completed on 27/08/2026 12:26pm. Going to take a short break and get back to it later. 



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



All work done on this document prior to this message was completed on 27/08/2026 15:33pm. That's all for today will continue tomorrow.  