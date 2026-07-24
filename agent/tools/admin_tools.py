import contextvars
from strands import tool
from .shared.db_connector import get_db_connection

# contextvars, not a plain module dict — each Flask request thread gets
# its own isolated copy, so one admin's district_id/admin_id can never
# bleed into a concurrent request from another district.
_context = contextvars.ContextVar("admin_context", default={})


def set_admin_context(district_id: str, admin_id: str):
    """Called by Flask before invoking admin agent."""
    _context.set({
        "district_id": district_id,
        "admin_id": admin_id
    })


@tool
def get_grade_trends(subject: str, weeks: int = 4) -> str:
    """
    Get grade trends across all students in this school for a subject.
    Returns aggregated data only — no individual student details.
    Call this to understand overall academic performance.

    Args:
        subject: The subject to analyse
        weeks: How many weeks back to look (default 4)
    """
    district_id = _context.get().get("district_id")

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    subject,
                    COUNT(*) as total_assessments,
                    AVG(score) as avg_score,
                    MIN(score) as min_score,
                    MAX(score) as max_score,
                    SUM(CASE WHEN score < 60 THEN 1 ELSE 0 END) as failing_count
                FROM grades
                WHERE district_id = %s
                  AND subject = %s
                  AND assessment_date >= NOW() - INTERVAL '1 week' * %s
                GROUP BY subject
            """, (district_id, subject, weeks))
            row = cur.fetchone()

        if not row:
            return f"No grade data found for {subject} in last {weeks} weeks."

        return (
            f"Subject: {subject} | "
            f"Avg Score: {row['avg_score']:.1f}% | "
            f"Failing (<60%): {row['failing_count']} students | "
            f"Range: {row['min_score']}% - {row['max_score']}%"
        )
    except Exception as e:
        return f"Grade trend analysis failed: {str(e)}"
    finally:
        conn.close()


@tool
def get_at_risk_students(subject: str, threshold: int = 60) -> str:
    """
    Identify students at risk of failing in a subject.
    Returns count and grade ranges only — not individual names.
    For FERPA compliance individual details require explicit drill down.

    Args:
        subject: The subject to check
        threshold: Score below which student is considered at risk (default 60)
    """
    district_id = _context.get().get("district_id")

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    COUNT(DISTINCT student_id) as at_risk_count,
                    AVG(score) as avg_score,
                    grade_level
                FROM grades
                WHERE district_id = %s
                  AND subject = %s
                  AND score < %s
                  AND assessment_date >= NOW() - INTERVAL '4 weeks'
                GROUP BY grade_level
                ORDER BY grade_level
            """, (district_id, subject, threshold))
            rows = cur.fetchall()

        if not rows:
            return f"No at-risk students found in {subject}."

        summary = []
        for row in rows:
            summary.append(
                f"Grade {row['grade_level']}: "
                f"{row['at_risk_count']} students at risk "
                f"(avg {row['avg_score']:.1f}%)"
            )
        return "\n".join(summary)
    except Exception as e:
        return f"At-risk analysis failed: {str(e)}"
    finally:
        conn.close()


@tool
def generate_intervention_report(subject: str) -> str:
    """
    Generate a summary intervention report for a subject.
    Combines grade trends and at-risk data into actionable insights.
    Call this when admin needs a complete picture of a subject area.

    Args:
        subject: The subject to report on
    """
    district_id = _context.get().get("district_id")

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    grade_level,
                    COUNT(DISTINCT student_id) as total_students,
                    AVG(score) as avg_score,
                    SUM(CASE WHEN score < 60 THEN 1 ELSE 0 END) as at_risk,
                    SUM(CASE WHEN score >= 90 THEN 1 ELSE 0 END) as excelling
                FROM grades
                WHERE district_id = %s
                  AND subject = %s
                  AND assessment_date >= NOW() - INTERVAL '4 weeks'
                GROUP BY grade_level
                ORDER BY grade_level
            """, (district_id, subject))
            rows = cur.fetchall()

        if not rows:
            return f"Insufficient data for {subject} intervention report."

        report_lines = [f"Intervention Report — {subject}"]
        report_lines.append("=" * 40)

        for row in rows:
            risk_pct = (row['at_risk'] / row['total_students'] * 100
                       if row['total_students'] > 0 else 0)
            urgency = "HIGH" if risk_pct > 30 else "MEDIUM" if risk_pct > 15 else "LOW"

            report_lines.append(
                f"Grade {row['grade_level']}: "
                f"{row['total_students']} students | "
                f"Avg: {row['avg_score']:.1f}% | "
                f"At Risk: {row['at_risk']} ({risk_pct:.0f}%) | "
                f"Urgency: {urgency}"
            )

        return "\n".join(report_lines)
    except Exception as e:
        return f"Report generation failed: {str(e)}"
    finally:
        conn.close()
