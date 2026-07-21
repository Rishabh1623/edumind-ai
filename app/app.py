import base64
import json
import logging
import time

from flask import Flask, request, jsonify

app = Flask(__name__)

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)
logger = logging.getLogger("edumind")


def decode_jwt_claims(token):
    """Decode the payload of a Cognito JWT without verifying the signature.

    Phase 1 placeholder only: signature verification against the Cognito
    JWKS endpoint must be added before this handles real traffic.
    """
    payload_segment = token.split(".")[1]
    padding = "=" * (-len(payload_segment) % 4)
    decoded = base64.urlsafe_b64decode(payload_segment + padding)
    return json.loads(decoded)


def get_tenant_context():
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None, None
    token = auth_header[len("Bearer "):]
    try:
        claims = decode_jwt_claims(token)
    except (IndexError, ValueError):
        return None, None
    return claims.get("custom:district_id"), claims.get("custom:role")


@app.before_request
def log_request():
    request.start_time = time.time()


@app.after_request
def log_response(response):
    district_id, role = get_tenant_context()
    logger.info(
        json.dumps(
            {
                "method": request.method,
                "path": request.path,
                "status": response.status_code,
                "district_id": district_id,
                "role": role,
                "duration_ms": round((time.time() - request.start_time) * 1000, 2),
            }
        )
    )
    return response


@app.route("/health", methods=["GET"])
def health():
    return jsonify(status="ok"), 200


def tenant_confirmation_response():
    district_id, role = get_tenant_context()
    if district_id is None:
        return jsonify(error="missing or invalid Authorization token"), 401
    return jsonify(district_id=district_id, role=role), 200


@app.route("/student/chat", methods=["POST"])
def student_chat():
    return tenant_confirmation_response()


@app.route("/teacher/content", methods=["POST"])
def teacher_content():
    return tenant_confirmation_response()


@app.route("/admin/report", methods=["POST"])
def admin_report():
    return tenant_confirmation_response()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
