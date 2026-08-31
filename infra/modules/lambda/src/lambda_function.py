import json
import os
from datetime import datetime, timezone

import boto3


dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")

TABLE_NAME = os.environ["DYNAMODB_TABLE"]
BUCKET_NAME = os.environ["REPORTS_BUCKET"]


def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)

    response = table.scan()
    analyses = response.get("Items", [])

    generated_at = datetime.now(timezone.utc)
    report_key = f"weekly/{generated_at:%Y-%m-%d}/summary.json"

    report = {
        "generated_at": generated_at.isoformat(),
        "analysis_count": len(analyses),
        "analyses": analyses,
    }

    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=report_key,
        Body=json.dumps(report, default=str),
        ContentType="application/json",
    )

    return {
        "statusCode": 200,
        "report_key": report_key,
        "analysis_count": len(analyses),
    }