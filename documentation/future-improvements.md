# Future improvements

## 1. Add private endpoints for ECR and CloudWatch Logs

Fargate tasks currently use NAT for image pulls and log delivery. Add interface endpoints for the ECR API, the ECR Docker registry and CloudWatch Logs. Bring back the S3 gateway endpoint so tasks can download the image layers ECR stores in S3. This would give image pulls and log delivery a private path through the VPC.

## 2. Add saved analyses and a weekly summary

Add a Saved Analyses page. Store the analysis date, finding count and report key in DynamoDB so the app can query for recent runs. Store the full JSON report in S3 and fetch it when someone opens a saved analysis.

Once there is saved history, use EventBridge Scheduler to invoke Lambda once a week. Lambda would read that week's records, calculate how many analyses ran and how many findings they produced, and write the totals to S3. The app could display those totals on the Saved Analyses page.