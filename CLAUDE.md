# EduMind AI — Project Context for Claude Code

## What this project is
AI-powered EdTech platform on AWS. Three-tier architecture with
Strands AI agents on top. FERPA-compliant multi-tenant SaaS for
K-12 and higher education districts.

## Architecture
- Presentation tier: React frontend on EC2 behind ALB
- Application tier: EC2 Auto Scaling Group behind ALB (Flask/FastAPI)
- Database tier: RDS Aurora PostgreSQL + DynamoDB + S3 + OpenSearch
- AI layer: Strands agents backed by Claude Sonnet 4.6 via Bedrock

## AWS Account details
- Region: us-east-1
- Account: 955510722779
- Working model ID: us.anthropic.claude-sonnet-4-6

## Tech stack
- Infrastructure: Terraform (modular structure)
- Backend: Python 3.14, Flask
- AI Framework: Strands Agents v1.48.0
- Database: Aurora PostgreSQL, DynamoDB
- Search: OpenSearch Serverless
- Identity: Cognito with custom:district_id attribute
- Compliance: FERPA — tenant isolation, KMS per district, CloudTrail

## Terraform module structure
modules/
├── networking/     # VPC, subnets, NAT, security groups
├── identity/       # Cognito user pool, groups, app client
├── presentation/   # S3, CloudFront for frontend
├── application/    # EC2 ASG, ALB, IAM roles, Launch Template
├── database/       # RDS Aurora, DynamoDB, Secrets Manager
├── storage/        # S3 curriculum bucket, KMS keys per district
├── search/         # OpenSearch Serverless collection
└── observability/  # CloudWatch, CloudTrail, alarms, dashboard

## FERPA compliance requirements (non-negotiable)
- Every DynamoDB key includes district_id
- Every RDS query filters by district_id
- KMS key per district for encryption isolation
- CloudTrail enabled for all API calls
- No student PII passed to Bedrock model

## Current phase
PHASE 1 — Infrastructure only. No AI code yet.
Goal: entire AWS infrastructure deployed via Terraform.
Placeholder Flask app returns JSON response confirming
district_id from Cognito JWT. No Strands agent yet.

## Phase 2 (after infrastructure works)
Add Strands agent inside Flask app.
Three agents: student tutor, teacher content, admin operations.
RAG with OpenSearch. AgentCore Memory. Bedrock Guardrails.

## Naming conventions
- Resources: edumind-{resource}-{env} e.g. edumind-vpc-prod
- Tags on every resource: Project=EduMind, Environment=prod, Owner=Rishabh1623
- Terraform variables: snake_case
- Python: snake_case

## What NOT to do
- Do not hardcode AWS credentials anywhere
- Do not put real values in terraform.tfvars (gitignored)
- Do not use root account
- Do not skip tags on any resource
- Do not create public RDS or OpenSearch endpoints
