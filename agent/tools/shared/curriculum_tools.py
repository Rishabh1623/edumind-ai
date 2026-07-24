import contextvars
from strands import tool
from .db_connector import get_bedrock_agent_client

KNOWLEDGE_BASE_ID = "UHTRSL7XCP"

# contextvars, not a plain module dict — each Flask request thread gets
# its own isolated copy, so one district's context can never bleed into
# a concurrent request from another district.
_context = contextvars.ContextVar("curriculum_context", default={})


def set_curriculum_context(district_id: str):
    """Called by Flask before invoking any agent that may retrieve curriculum."""
    _context.set({"district_id": district_id})


@tool
def retrieve_curriculum(query: str, subject: str, grade_level: int) -> str:
    """
    Retrieve relevant curriculum content using RAG from Bedrock
    Knowledge Base. Always call this before answering any
    subject matter question. Content is scoped to the caller's
    district only — FERPA compliant.

    Args:
        query: The question or topic to search for
        subject: Subject area e.g. math, science, history
        grade_level: Student grade level 1 through 12
    """
    client = get_bedrock_agent_client()

    # district_id comes only from server-side request context (set from
    # the verified JWT), never from a tool argument — a tool argument
    # would let the model (or a crafted prompt) request another
    # district's curriculum.
    district_id = _context.get().get("district_id")
    if not district_id:
        return "Unable to retrieve curriculum: no district context set for this request."

    try:
        response = client.retrieve(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            retrievalQuery={
                "text": f"subject:{subject} grade:{grade_level} {query}"
            },
            retrievalConfiguration={
                "vectorSearchConfiguration": {
                    "numberOfResults": 5,
                    "overrideSearchType": "HYBRID",
                    "filter": {
                        "equals": {
                            "key": "district_id",
                            "value": district_id,
                        }
                    },
                }
            },
        )

        results = response.get("retrievalResults", [])

        if not results:
            return (
                "No curriculum content found for this topic. "
                "Ask your teacher to upload the relevant materials."
            )

        formatted = []
        for i, result in enumerate(results, 1):
            content = result["content"]["text"]
            score = result.get("score", 0)
            location = result.get("location", {})
            source = location.get("s3Location", {}).get("uri", "curriculum")

            formatted.append(
                f"[Source {i}: {source} | Relevance: {score:.2f}]\n{content}"
            )

        return "\n\n".join(formatted)

    except Exception as e:
        return f"Curriculum retrieval failed: {str(e)}"
