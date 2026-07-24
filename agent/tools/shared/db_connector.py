import boto3
import psycopg2
import psycopg2.extras
import json
import os


def get_db_connection():
    """
    Get Aurora PostgreSQL connection using credentials from Secrets Manager.
    Never hardcode credentials.
    """
    client = boto3.client("secretsmanager", region_name="us-east-1")
    secret = client.get_secret_value(SecretId="edumind/aurora/credentials")
    creds = json.loads(secret["SecretString"])

    return psycopg2.connect(
        host=os.environ["AURORA_HOST"],
        user=creds["username"],
        password=creds["password"],
        dbname="edumind",
        connect_timeout=5,
        cursor_factory=psycopg2.extras.RealDictCursor,
    )


def get_dynamodb_table():
    """Get DynamoDB sessions table."""
    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    return dynamodb.Table(os.environ["SESSIONS_TABLE"])


def get_bedrock_client():
    """Get Bedrock runtime client."""
    return boto3.client("bedrock-runtime", region_name="us-east-1")


def get_bedrock_agent_client():
    """Get Bedrock agent runtime client for Knowledge Base queries."""
    return boto3.client("bedrock-agent-runtime", region_name="us-east-1")
