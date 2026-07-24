from strands import Agent, tool
from strands.models import BedrockModel
from .student_agent import student_agent
from .teacher_agent import teacher_agent
from .admin_agent import admin_agent

bedrock_model = BedrockModel(
    model_id="us.anthropic.claude-sonnet-4-6",
    region_name="us-east-1",
    temperature=0.1,
)


@tool
def consult_student_agent(query: str) -> str:
    """
    Delegate to the Student Tutor Agent.
    Use when role is student or request involves learning,
    curriculum questions, homework help, or academic tutoring.

    Args:
        query: The student's question or request
    """
    result = student_agent(query)
    return str(result)


@tool
def consult_teacher_agent(query: str) -> str:
    """
    Delegate to the Teacher Content Agent.
    Use when role is teacher or request involves quiz generation,
    lesson planning, assessment creation, or curriculum content.

    Args:
        query: The teacher's request
    """
    result = teacher_agent(query)
    return str(result)


@tool
def consult_admin_agent(query: str) -> str:
    """
    Delegate to the Admin Operations Agent.
    Use when role is administrator or request involves student
    performance, at-risk identification, or school-wide insights.

    Args:
        query: The admin's request
    """
    result = admin_agent(query)
    return str(result)


ORCHESTRATOR_SYSTEM_PROMPT = """
You are the EduMind orchestrator. You receive all requests and
delegate to the right specialist agent.

Routing rules — follow these exactly:
- Role is student → always use consult_student_agent
- Role is teacher → always use consult_teacher_agent
- Role is administrator → always use consult_admin_agent

You never answer questions yourself.
You only route to the correct specialist.
You pass the full user message to the specialist unchanged.
"""

lead_agent = Agent(
    model=bedrock_model,
    system_prompt=ORCHESTRATOR_SYSTEM_PROMPT,
    tools=[
        consult_student_agent,
        consult_teacher_agent,
        consult_admin_agent,
    ]
)
