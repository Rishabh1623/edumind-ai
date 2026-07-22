import boto3
import os
import json

client = boto3.client("bedrock-agent")


def handler(event, context):
    response = client.start_ingestion_job(
        knowledgeBaseId=os.environ["KNOWLEDGE_BASE_ID"],
        dataSourceId=os.environ["DATA_SOURCE_ID"],
    )
    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "ingestionJobId": response["ingestionJob"]["ingestionJobId"],
                "status": response["ingestionJob"]["status"],
            }
        ),
    }
