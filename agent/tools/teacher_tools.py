import contextvars
from strands import tool
from .shared.db_connector import get_db_connection

# contextvars, not a plain module dict — each Flask request thread gets
# its own isolated copy, so one teacher's district_id/teacher_id can
# never bleed into a concurrent request from another district.
_context = contextvars.ContextVar("teacher_context", default={})


def set_teacher_context(district_id: str, teacher_id: str):
    """Called by Flask before invoking teacher agent."""
    _context.set({
        "district_id": district_id,
        "teacher_id": teacher_id
    })


@tool
def get_class_assessments(subject: str, grade_level: int) -> str:
    """
    Get recent assessments given to this class in a subject.
    Call this before generating new assessments to avoid repetition.

    Args:
        subject: The subject area
        grade_level: The grade level
    """
    district_id = _context.get().get("district_id")

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT subject, topic, created_at
                FROM assessments
                WHERE district_id = %s
                  AND subject = %s
                  AND grade_level = %s
                ORDER BY created_at DESC
                LIMIT 10
            """, (district_id, subject, grade_level))
            rows = cur.fetchall()

        if not rows:
            return f"No prior assessments found for {subject} Grade {grade_level}."

        topics = [f"{r['topic']} ({r['created_at']})" for r in rows]
        return f"Recent assessments: {', '.join(topics)}"
    except Exception as e:
        return f"Assessment retrieval failed: {str(e)}"
    finally:
        conn.close()


@tool
def save_assessment(subject: str, grade_level: int,
                    topic: str, questions: str) -> str:
    """
    Save a generated assessment to Aurora for record keeping.
    Call this after generating assessment content.

    Args:
        subject: The subject area
        grade_level: The grade level
        topic: The topic of the assessment
        questions: The generated questions in JSON format
    """
    context = _context.get()
    district_id = context.get("district_id")
    teacher_id = context.get("teacher_id")

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO assessments
                (district_id, subject, grade_level, topic,
                 questions, created_by)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (district_id, subject, grade_level,
                  topic, questions, teacher_id))
            conn.commit()
        return f"Assessment saved: {topic} for Grade {grade_level} {subject}"
    except Exception as e:
        return f"Assessment save failed: {str(e)}"
    finally:
        conn.close()
