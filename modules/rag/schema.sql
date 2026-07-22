-- Run this manually on Aurora after first deploy.
-- Must be applied BEFORE the aws_bedrockagent_knowledge_base resource is
-- created — Bedrock validates the RDS backend (extension + table) at
-- knowledge-base creation time, so an empty database will fail
-- CreateKnowledgeBase outright.

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Curriculum embeddings table
-- district_id on every row = FERPA tenant isolation at DB level
-- One district never sees another district's curriculum vectors
--
-- embedding is vector(1024), not 1536: amazon.titan-embed-text-v2:0 (the
-- model wired up in modules/rag/main.tf) outputs 1024 dimensions by
-- default (256/512/1024 are the only valid choices) — 1536 is the older
-- Titan v1 / OpenAI ada-002 convention and would make every ingestion job
-- fail with a vector dimension mismatch.
CREATE TABLE IF NOT EXISTS curriculum_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    district_id VARCHAR(50) NOT NULL,
    subject VARCHAR(100),
    grade_level INT,
    content TEXT NOT NULL,
    embedding vector(1024),
    metadata JSONB,
    source_file VARCHAR(500),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index for fast district-scoped queries
CREATE INDEX IF NOT EXISTS idx_curriculum_district
ON curriculum_embeddings(district_id);

-- HNSW index for cosine similarity search — required as HNSW specifically,
-- not IVFFlat: CreateKnowledgeBase rejected an IVFFlat index on this column
-- live with "embedding column must be indexed ... USING hnsw (...)".
CREATE INDEX IF NOT EXISTS idx_curriculum_vector
ON curriculum_embeddings
USING hnsw (embedding vector_cosine_ops);

-- Required by Bedrock Knowledge Base for RDS storage: CreateKnowledgeBase
-- rejects the storage configuration unless the text field has a full-text
-- GIN index (confirmed live — this was the exact error message returned).
CREATE INDEX IF NOT EXISTS idx_curriculum_content_fts
ON curriculum_embeddings
USING gin (to_tsvector('simple', content));
