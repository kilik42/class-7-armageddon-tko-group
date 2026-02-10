#!/bin/bash
set -euo pipefail

# (Optional) log user-data output for debugging
exec > >(tee -a /var/log/user-data.log | logger -t user-data ) 2>&1

dnf update -y
dnf install -y python3 python3-pip

# -----------------------------
# AUTO-DETECT REGION 
# -----------------------------
REGION="$(python3 - <<'PY'
import urllib.request

# IMDSv2 token
token_req = urllib.request.Request(
    "http://169.254.169.254/latest/api/token",
    method="PUT",
    headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},
)
token = urllib.request.urlopen(token_req, timeout=2).read().decode()

# AZ -> region (us-west-2a -> us-west-2)
az_req = urllib.request.Request(
    "http://169.254.169.254/latest/meta-data/placement/availability-zone",
    headers={"X-aws-ec2-metadata-token": token},
)
az = urllib.request.urlopen(az_req, timeout=2).read().decode()
print(az[:-1])
PY
)"
export AWS_REGION="$REGION"
export AWS_DEFAULT_REGION="$REGION"

# --- App + venv so boto3/pymysql are guaranteed for the service ---
mkdir -p /opt/rdsapp
python3 -m venv /opt/rdsapp/venv
/opt/rdsapp/venv/bin/pip install --upgrade pip
/opt/rdsapp/venv/bin/pip install --upgrade pip setuptools wheel
/opt/rdsapp/venv/bin/pip install flask boto3 pymysql cryptography


cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import time
from datetime import datetime, timezone

import boto3
import pymysql
from flask import Flask, request

# -----------------------------
# JSON LOGGING (emit JSON logs)
# -----------------------------
def jlog(**fields):
    fields["ts"] = datetime.now(timezone.utc).isoformat()
    print(json.dumps(fields, default=str), flush=True)

# Use detected region from env; if not present, let boto3 decide
REGION = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION")
SECRET_ID = os.environ.get("SECRET_ID", "lab/rds/mysql")

secrets = boto3.client("secretsmanager", region_name=REGION) if REGION else boto3.client("secretsmanager")

def get_db_creds():
    resp = secrets.get_secret_value(SecretId=SECRET_ID)
    return json.loads(resp["SecretString"])

def get_conn():
    c = get_db_creds()
    return pymysql.connect(
        host=c["host"],
        user=c["username"],
        password=c["password"],
        port=int(c.get("port", 3306)),
        database=c.get("dbname", "labdb"),
        autocommit=True,
        connect_timeout=5
    )

app = Flask(__name__)

@app.before_request
def _start_timer():
    request._start = time.time()

@app.after_request
def _log_response(resp):
    dur_ms = int((time.time() - getattr(request, "_start", time.time())) * 1000)
    jlog(
        level="INFO",
        method=request.method,
        path=request.path,
        status=resp.status_code,
        client_ip=(request.headers.get("X-Forwarded-For", "").split(",")[0].strip() or request.remote_addr),
        duration_ms=dur_ms
    )
    return resp

from werkzeug.exceptions import HTTPException

@app.errorhandler(HTTPException)
def handle_http_exception(e):
    # Logs 404/403/etc without a traceback
    jlog(
        level="WARN",
        method=request.method,
        path=request.path,
        status=e.code,
        client_ip=(request.headers.get("X-Forwarded-For", "").split(",")[0].strip() or request.remote_addr),
        error_type=type(e).__name__,
        message=e.description
    )
    return e  # returns correct HTTP response

@app.errorhandler(Exception)
def handle_exception(e):
    # Logs unexpected errors as 500 without dumping a traceback
    jlog(
        level="ERROR",
        method=getattr(request, "method", None),
        path=getattr(request, "path", None),
        status=500,
        client_ip=(request.headers.get("X-Forwarded-For", "").split(",")[0].strip() or getattr(request, "remote_addr", None)),
        error_type=type(e).__name__,
        message=str(e)
    )
    return "Internal Server Error", 500

@app.route("/")
def home():
    return """
    <h2>EC2 → RDS Notes App</h2>
    <p>GET /init</p>
    <p>POST /add?note=hello</p>
    <p>GET /list</p>
    """

@app.route("/init")
def init_db():
    c = get_db_creds()
    conn = pymysql.connect(
        host=c["host"],
        user=c["username"],
        password=c["password"],
        port=int(c.get("port", 3306)),
        autocommit=True,
        connect_timeout=5
    )
    cur = conn.cursor()
    cur.execute("CREATE DATABASE IF NOT EXISTS labdb;")
    cur.execute("USE labdb;")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS notes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            note VARCHAR(255) NOT NULL
        );
    """)
    cur.close()
    conn.close()
    return "Initialized labdb + notes table."

@app.route("/add", methods=["POST", "GET"])
def add_note():
    note = request.args.get("note", "").strip()
    if not note:
        return "Missing note param. Try: /add?note=hello", 400
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("INSERT INTO notes(note) VALUES(%s);", (note,))
    cur.close()
    conn.close()
    return f"Inserted note: {note}"

@app.route("/list")
def list_notes():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    out = "<h3>Notes</h3><ul>"
    for r in rows:
        out += f"<li>{r[0]}: {r[1]}</li>"
    out += "</ul>"
    return out

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

# Put env vars in a file systemd can read (so region matches automatically)
cat >/etc/rdsapp.env <<EOF
SECRET_ID=lab/rds/mysql
AWS_REGION=${AWS_REGION}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
EOF
chmod 600 /etc/rdsapp.env

# --- systemd service (NAME MUST BE rdsapp) ---
cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
EnvironmentFile=/etc/rdsapp.env
ExecStart=/opt/rdsapp/venv/bin/python /opt/rdsapp/app.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp

#############################################
# CloudWatch Logs: ship /var/log/rdsapp.log to log group rds-app
#############################################

touch /var/log/rdsapp.log
chmod 644 /var/log/rdsapp.log

mkdir -p /etc/systemd/system/rdsapp.service.d
cat >/etc/systemd/system/rdsapp.service.d/override.conf <<'EOF'
[Service]
StandardOutput=append:/var/log/rdsapp.log
StandardError=append:/var/log/rdsapp.log
EOF

systemctl daemon-reload
systemctl restart rdsapp

dnf install -y amazon-cloudwatch-agent || true

if [ ! -f /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
  python3 - <<'PY'
import urllib.request
url = "https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm"
dst = "/tmp/amazon-cloudwatch-agent.rpm"
urllib.request.urlretrieve(url, dst)
print("Downloaded", dst)
PY
  rpm -Uvh /tmp/amazon-cloudwatch-agent.rpm
fi

mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'JSON'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/rdsapp.log",
            "log_group_name": "rds-app",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
JSON

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

echo "CW_STREAM_TEST $(date -Is) cloudwatch agent configured in ${AWS_REGION}" >> /var/log/rdsapp.log
