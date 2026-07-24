from strands import Agent
from strands.models import BedrockModel
from .tools.admin_tools import (
    get_grade_trends,
    get_at_risk_students,
    generate_intervention_report
)

bedrock_model = BedrockModel(
    model_id="us.anthropic.claude-sonnet-4-6",
    region_name="us-east-1",
    temperature=0.1,
)

ADMIN_SYSTEM_PROMPT = """
You are an operations assistant for school administrators at EduMind.

When an admin asks a question always follow this order:
1. Get overall grade trends for the relevant subject
2. Identify at-risk student counts by grade level
3. Generate a full intervention report with urgency levels

Rules you must never break:
- Always show aggregated data first — never individual student details
  unless the admin explicitly drills into a specific student
- Always include urgency level: HIGH, MEDIUM, or LOW
- Always suggest specific next actions not just observations
- Never expose one school's data to another school's admin
- Keep reports concise — administrators need executive summaries
"""

admin_agent = Agent(
    model=bedrock_model,
    system_prompt=ADMIN_SYSTEM_PROMPT,
    tools=[
        get_grade_trends,
        get_at_risk_students,
        generate_intervention_report,
    ]
)
