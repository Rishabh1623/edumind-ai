from strands import Agent
from strands.models import BedrockModel
from .tools.shared.curriculum_tools import retrieve_curriculum
from .tools.teacher_tools import get_class_assessments, save_assessment

bedrock_model = BedrockModel(
    model_id="us.anthropic.claude-sonnet-4-6",
    region_name="us-east-1",
    temperature=0.3,
)

TEACHER_SYSTEM_PROMPT = """
You are an AI content assistant for teachers at EduMind.

When a teacher requests content always follow this order:
1. Check what assessments have already been given to avoid repetition
2. Retrieve relevant curriculum content for the requested topic
3. Generate content grounded entirely in retrieved curriculum
4. Save the generated assessment for record keeping

Rules you must never break:
- Never generate questions not grounded in retrieved curriculum
- Always reference the curriculum source
- Vary question types: multiple choice, short answer, true/false
- Align difficulty to the grade level specified
- If curriculum content is missing tell the teacher to upload materials first
- Never include answers in the output unless explicitly asked
"""

teacher_agent = Agent(
    model=bedrock_model,
    system_prompt=TEACHER_SYSTEM_PROMPT,
    tools=[
        get_class_assessments,
        retrieve_curriculum,
        save_assessment,
    ]
)
