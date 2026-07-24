import contextvars
from strands import tool
from .shared.db_connector import get_db_connection, get_dynamodb_table
from datetime import datetime, timedelta

# contextvars, not a plain module dict — each Flask request thread gets
# its own isolated copy, so one student's district_id/student_id can
# never bleed into a concurrent request from another district.
_context = contextvars.ContextVar("student_context", default={})


def set_student_context(district_id: str, student_id: str):
    """Called by Flask before invoking student agent."""
    _context.set({
        "district_id": district_id,
        "student_id": student_id
    })


@tool
def get_student_progress(topic: str) -> str:
    """
    Get this student's prior progress on a specific topic from DynamoDB.
    Call this to understand what the student already knows before teaching.

    Args:
        topic: The curriculum topic to check progress for
    """
    context = _context.get()
    district_id = context.get("district_id")
    student_id = context.get("student_id")

    table = get_dynamodb_table()
    try:
        response = table.get_item(
            Key={
                "pk": f"TENANT#{district_id}#STUDENT#{student_id}",
                "sk": f"PROGRESS#{topic}"
            }
        )
        item = response.get("Item")
        if not item:
            return f"No prior progress found for {topic}. First time covering this."
        return (
            f"Topic: {topic} | "
            f"Last covered: {item.get('last_covered')} | "
            f"Understood: {item.get('understood')} | "
            f"Sessions: {item.get('session_count', 1)}"
        )
    except Exception as e:
        return f"Progress check failed: {str(e)}"


@tool
def get_student_grades(subject: str) -> str:
    """
    Get this student's recent grades in a subject from Aurora.
    Call this to calibrate explanation difficulty to student's level.

    Args:
        subject: The subject to retrieve grades for
    """
    context = _context.get()
    district_id = context.get("district_id")
    student_id = context.get("student_id")

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT subject, score, assessment_date
                FROM grades
                WHERE student_id = %s
                  AND district_id = %s
                  AND subject = %s
                ORDER BY assessment_date DESC
                LIMIT 5
            """, (student_id, district_id, subject))
            rows = cur.fetchall()

        if not rows:
            return f"No grades found for {subject}."

        grades = [f"{r['assessment_date']}: {r['score']}%" for r in rows]
        avg = sum(r['score'] for r in rows) / len(rows)
        return f"Recent {subject} grades: {', '.join(grades)} | Average: {avg:.1f}%"
    except Exception as e:
        return f"Grade retrieval failed: {str(e)}"
    finally:
        conn.close()


@tool
def save_session_progress(topic: str, understood: bool) -> str:
    """
    Save what was covered in this tutoring session to DynamoDB.
    Always call this at the end of the session.

    Args:
        topic: The topic that was covered
        understood: Whether the student showed understanding
    """
    context = _context.get()
    district_id = context.get("district_id")
    student_id = context.get("student_id")

    table = get_dynamodb_table()
    try:
        table.put_item(Item={
            "pk": f"TENANT#{district_id}#STUDENT#{student_id}",
            "sk": f"PROGRESS#{topic}",
            "topic": topic,
            "understood": understood,
            "last_covered": datetime.utcnow().isoformat(),
            "district_id": district_id,
            "expires_at": int(
                (datetime.utcnow() + timedelta(days=365)).timestamp()
            )
        })
        return f"Progress saved: {topic} — understood: {understood}"
    except Exception as e:
        return f"Progress save failed: {str(e)}"
