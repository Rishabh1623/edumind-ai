-- Run this manually on Aurora (same as modules/rag/schema.sql — applying
-- it via Terraform isn't expressible since these tables are reached
-- through the RDS Data API / a direct connection, outside Terraform's
-- graph). Required before agent/tools/student_tools.py,
-- agent/tools/teacher_tools.py or agent/tools/admin_tools.py can run —
-- they query these tables directly.

-- Student grades.
-- district_id on every row = FERPA tenant isolation at DB level.
-- Every query in student_tools.py/admin_tools.py filters by district_id
-- first, so it leads every composite index below.
CREATE TABLE IF NOT EXISTS grades (
    id SERIAL PRIMARY KEY,
    district_id VARCHAR(50) NOT NULL,
    student_id VARCHAR(100) NOT NULL,
    subject VARCHAR(100) NOT NULL,
    grade_level INT NOT NULL,
    score NUMERIC(5, 2) NOT NULL,
    assessment_date TIMESTAMP NOT NULL DEFAULT NOW()
);

-- get_student_grades: district_id + student_id + subject, most recent first
CREATE INDEX IF NOT EXISTS idx_grades_district_student_subject
ON grades (district_id, student_id, subject, assessment_date DESC);

-- get_grade_trends / get_at_risk_students / generate_intervention_report:
-- district_id + subject, filtered by a recent date window
CREATE INDEX IF NOT EXISTS idx_grades_district_subject_date
ON grades (district_id, subject, assessment_date);

-- Teacher-generated assessments.
CREATE TABLE IF NOT EXISTS assessments (
    id SERIAL PRIMARY KEY,
    district_id VARCHAR(50) NOT NULL,
    subject VARCHAR(100) NOT NULL,
    grade_level INT NOT NULL,
    topic VARCHAR(255) NOT NULL,
    -- Generated questions, stored as the JSON-formatted string
    -- save_assessment() in agent/tools/teacher_tools.py already produces —
    -- TEXT rather than JSONB so no implicit cast is needed on insert.
    questions TEXT NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- get_class_assessments: district_id + subject + grade_level, most recent first
CREATE INDEX IF NOT EXISTS idx_assessments_district_subject_grade
ON assessments (district_id, subject, grade_level, created_at DESC);
