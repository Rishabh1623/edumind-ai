#!/bin/bash
set -eu -o pipefail
exec > >(tee /var/log/edumind-user-data.log) 2>&1

dnf update -y
dnf install -y python3 python3-pip unzip

mkdir -p /app
echo "${app_py_base64}" | base64 -d > /app/app.py

# agent/ ships as a separate zip in S3 (too large to inline into user
# data — see modules/application/main.tf) and is unpacked into
# /app/agent so `from agent.orchestrator import lead_agent` in
# /app/app.py resolves via /app on sys.path.
mkdir -p /app/agent
aws s3 cp "s3://${deploy_bucket}/${agent_package_key}" /tmp/agent_package.zip
unzip -o /tmp/agent_package.zip -d /app/agent

# psycopg2-binary/python-jose/requests are required by the real Phase 2
# app (Aurora is PostgreSQL, and the app verifies Cognito JWTs against
# the pool's JWKS); strands-agents install is best-effort so a transient
# failure there doesn't block the app from starting.
pip3 install flask boto3 psycopg2-binary "python-jose[cryptography]" requests
pip3 install strands-agents || echo "strands-agents install failed, continuing without it"

cat > /etc/systemd/system/edumind-app.service <<'UNIT'
[Unit]
Description=EduMind Flask application
After=network.target

[Service]
ExecStart=/usr/bin/python3 /app/app.py
Restart=always
User=root
WorkingDirectory=/app
Environment=AWS_REGION=${aws_region}
Environment=AURORA_HOST=${aurora_host}
Environment=SESSIONS_TABLE=${sessions_table}
Environment=COGNITO_USER_POOL_ID=${cognito_user_pool_id}
Environment=COGNITO_APP_CLIENT_ID=${cognito_app_client_id}
StandardOutput=append:/var/log/edumind-app.log
StandardError=append:/var/log/edumind-app.log

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now edumind-app.service

# Best-effort only: the CloudWatch agent shipping logs must not block the
# app itself from running if this package or config step fails.
if dnf install -y amazon-cloudwatch-agent; then
  mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
  cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/edumind-app.log",
            "log_group_name": "/edumind/application",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CWCONFIG

  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json || true
else
  echo "amazon-cloudwatch-agent package unavailable, skipping agent setup"
fi
