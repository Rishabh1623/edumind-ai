#!/bin/bash
set -eu -o pipefail
exec > >(tee /var/log/edumind-user-data.log) 2>&1

dnf update -y
dnf install -y python3 python3-pip

mkdir -p /app
echo "${app_py_base64}" | base64 -d > /app/app.py

# flask/boto3/pymysql are required by the placeholder app; strands-agents is
# only pre-staged for Phase 2 and is not imported yet, so its install must
# not be allowed to block the app from starting.
pip3 install flask boto3 pymysql
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
