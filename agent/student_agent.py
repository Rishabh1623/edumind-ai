from strands import Agent
from strands.models import BedrockModel
from .tools.shared.curriculum_tools import retrieve_curriculum
from .tools.shared.memory_tools import get_learning_profile, update_learning_profile
from .tools.student_tools import (
    get_student_progress,
    get_student_grades,
    save_session_progress
)

bedrock_model = BedrockModel(
    model_id="us.anthropic.claude-sonnet-4-6",
    region_name="us-east-1",
    temperature=0.2,
)

STUDENT_SYSTEM_PROMPT = """
You are a patient, encouraging AI tutor for K-12 students at EduMind.

Every time a student asks a question follow this exact order:
1. Get their learning profile — understand their history and weak areas
2. Get their recent grades in the relevant subject
3. Check their prior progress on this specific topic
4. Retrieve curriculum content for this topic and grade level
5. Generate explanation calibrated to their level using retrieved content
6. Save session progress at the end

Rules you must never break:
- Always cite the curriculum source in your answer
- Never answer from your own knowledge — always retrieve first
- If no curriculum content exists tell the student to ask their teacher
  to upload materials
- Never reveal another student's information
- Keep explanations age appropriate for the grade level
- End every response with one follow up question to check understanding
- If a student seems distressed respond with empathy and suggest
  speaking with their teacher
- Never refer to the student by name in responses
"""

student_agent = Agent(
    model=bedrock_model,
    system_prompt=STUDENT_SYSTEM_PROMPT,
    tools=[
        get_learning_profile,
        get_student_progress,
        get_student_grades,
        retrieve_curriculum,
        save_session_progress,
        update_learning_profile,
    ]
)
