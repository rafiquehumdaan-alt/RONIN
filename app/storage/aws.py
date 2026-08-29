import json
import os
import uuid
from datetime import datetime, timezone

import boto3


AWS_REGION = os.getenv("AWS_REGION", "eu-west-2")
DYNAMODB_TABLE = os.getenv("RONIN_DYNAMODB_TABLE", "ronin-analyses")
REPORTS_BUCKET = os.getenv("RONIN_REPORTS_BUCKET", "ronin-reports")


def save_analysis(resources, findings):
    analysis_id = f"analysis-{uuid.uuid4().hex[:8]}"
    created_at = datetime.now(timezone.utc).isoformat()

    record = {
        "analysis_id": analysis_id,
        "created_at": created_at,
        "resources_checked": len(resources),
        "finding_count": len(findings),
        "status": "completed",
    }

    dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
    table = dynamodb.Table(DYNAMODB_TABLE)
    table.put_item(Item=record)

    report = {
        **record,
        "findings": findings,
    }

    s3 = boto3.client("s3", region_name=AWS_REGION)
    s3.put_object(
        Bucket=REPORTS_BUCKET,
        Key=f"analyses/{analysis_id}.json",
        Body=json.dumps(report, indent=2).encode("utf-8"),
        ContentType="application/json",
    )

    return record
