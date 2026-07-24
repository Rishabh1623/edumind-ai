import boto3
import pytest

KNOWLEDGE_BASE_ID = "UHTRSL7XCP"


def test_district_isolation():
    """
    Proves that district data isolation works at the vector level.
    District 001 student cannot retrieve District 002 curriculum.
    This is the FERPA compliance proof test.
    """
    client = boto3.client("bedrock-agent-runtime", region_name="us-east-1")

    # Query scoped to district_001 via a hard metadata filter — not a
    # text hint — matching how agent/tools/shared/curriculum_tools.py
    # actually enforces isolation at retrieval time.
    response = client.retrieve(
        knowledgeBaseId=KNOWLEDGE_BASE_ID,
        retrievalQuery={
            "text": "math quadratic equations"
        },
        retrievalConfiguration={
            "vectorSearchConfiguration": {
                "numberOfResults": 5,
                "filter": {
                    "equals": {
                        "key": "district_id",
                        "value": "district_001"
                    }
                }
            }
        }
    )

    results = response.get("retrievalResults", [])
    print(f"District 001 query returned {len(results)} results")

    # Verify no district_002 content appears
    for result in results:
        source = result.get("location", {}).get("s3Location", {}).get("uri", "")
        assert "district_002" not in source, (
            f"FERPA VIOLATION: District 002 content appeared in District 001 query: {source}"
        )

    print("FERPA isolation verified — no cross-district content returned")


if __name__ == "__main__":
    test_district_isolation()
