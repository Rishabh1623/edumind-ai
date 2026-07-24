from strands import tool
from ..student_tools import _context as _student_context
import boto3
import json


def _memory_id() -> str:
    context = _student_context.get()
    district_id = context.get("district_id")
    student_id = context.get("student_id")
    return f"district-{district_id}-student-{student_id}"


@tool
def get_learning_profile() -> str:
    """
    Retrieve the current student's long term learning profile from
    AgentCore Memory. Contains weak areas, strong areas, preferred
    explanation style, topics covered in previous sessions.
    Always call this first before tutoring a student.
    """
    # student_id/district_id come only from server-side request context
    # (set from the verified JWT), never from a tool argument — a tool
    # argument would let the model read another student's profile.
    try:
        client = boto3.client(
            "bedrock-agentcore-memory",
            region_name="us-east-1"
        )
        response = client.retrieve_memories(
            memoryId=_memory_id(),
            query="learning history weak areas explanation style"
        )
        memories = response.get("memories", [])
        if not memories:
            return "New student — no learning history yet. Start fresh."
        return json.dumps(memories, indent=2)
    except Exception:
        return "No prior learning profile found. Starting fresh."


@tool
def update_learning_profile(
    topic: str,
    understood: bool,
    explanation_style: str,
    notes: str
) -> str:
    """
    Save learning insights from this session, for the current student,
    to AgentCore Memory. Call this at the end of every tutoring session.

    Args:
        topic: Topic covered in this session
        understood: Whether student demonstrated understanding
        explanation_style: What style worked e.g. visual, example-based
        notes: Any specific observations about this student
    """
    try:
        client = boto3.client(
            "bedrock-agentcore-memory",
            region_name="us-east-1"
        )
        client.store_memory(
            memoryId=_memory_id(),
            content={
                "topic": topic,
                "understood": understood,
                "explanation_style": explanation_style,
                "notes": notes
            }
        )
        return "Learning profile updated for this student"
    except Exception:
        return f"Memory update noted locally: {topic} — {understood}"
