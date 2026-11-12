# CI/CD overview

RONIN uses two GitHub Actions workflows. The Terraform workflow manages the infrastructure, and the Application workflow builds and deploys the Flask container.

## Terraform workflow

Changes to the Terraform files or workflow trigger checks on pushes to `main` and pull requests targeting `main`. The checks job verifies formatting, initialises providers without connecting to the state backend, validates the main Terraform configuration, runs TFLint recursively and scans the configuration with Checkov.

Manual runs also go through the checks job before running `plan`, `apply` or `destroy`. Formatting, validation and TFLint failures block the manual operation. Checkov findings are advisory.

After the checks pass, the manual job assumes the AWS role through GitHub OIDC and initialises the S3 backend. `plan` prints the proposed changes. `apply` and `destroy` each create and apply a saved plan in the same run.

## Application workflow

Pushes to `main`, pull requests targeting `main` and manual `scan-only` runs can run the checks job. It builds the Docker image, starts a container to check `/health` and scans the image with Trivy. Trivy reports high and critical findings without blocking deployment.

A manual `deploy` from `main` runs a separate job. It builds, smoke-tests and scans the image on the same runner that pushes it to ECR. The tested image is already available to Docker on that runner, so there is no artifact to transfer between jobs.

The deploy job uses GitHub OIDC to assume the AWS role and logs in to ECR. The workflow calls `push-image-to-ecr.sh` to push the tested image with a run-specific tag and `latest`. It then calls `deploy-ecs.sh` to start a new ECS rollout, wait for the service to stabilise, verify that the running tasks use the image digest from this run and check the public `/health` endpoint. On the first successful deployment, the script sets the autoscaling minimum to two tasks.

Manual Terraform runs and application deployments share a concurrency group so they do not run against the environment at the same time.

## Deployment order

1. Apply `terraform/bootstrap` locally to create the S3 state bucket and the GitHub OIDC role.
2. Run the Terraform workflow with `apply` to create the main infrastructure.
3. Run the Application workflow from `main` with `deploy` to push the image and start the ECS service.