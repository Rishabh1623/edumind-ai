#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y python3 python3-pip amazon-cloudwatch-agent

mkdir -p /app
echo "${app_py_base64}" | base64 -d > /app/app.py

pip3 install flask boto3 pymysql strands-agents

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
  -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
