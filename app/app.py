import os
import json
import time
import logging

import requests
from flask import Flask, request, jsonify
from jose import jwt, jwk
from jose.utils import base64url_decode

app = Flask(__name__)
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# Imported lazily behind a try/except, not at module scope like everything
# above: every agent/tools module uses Strands' @tool decorator, so all of
# these pull in the full Strands dependency tree, and a failure there
# (missing package, bad version) must not take the whole process down.
# Previously it did — a single failed import here crashed Flask before it
# could even bind to a port, and systemd's Restart=always turned that into
# an infinite crash loop with no informative response for either the ALB
# health check or a caller.
try:
    from agent.orchestrator import lead_agent
    from agent.tools.student_tools import set_student_context
    from agent.tools.teacher_tools import set_teacher_context
    from agent.tools.admin_tools import set_admin_context
    from agent.tools.shared.curriculum_tools import set_curriculum_context
except Exception as e:
    lead_agent = None
    set_student_context = set_teacher_context = set_admin_context = set_curriculum_context = None
    logger.error(f"agent package failed to import, agent routes will 503: {str(e)}")

AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
USER_POOL_ID = os.environ["COGNITO_USER_POOL_ID"]
APP_CLIENT_ID = os.environ["COGNITO_APP_CLIENT_ID"]
ISSUER = f"https://cognito-idp.{AWS_REGION}.amazonaws.com/{USER_POOL_ID}"
JWKS_URL = f"{ISSUER}/.well-known/jwks.json"
JWKS_TTL_SECONDS = 3600

_jwks_cache = {"keys": None, "fetched_at": 0}


def _get_jwks(force_refresh: bool = False) -> list:
    now = time.time()
    if force_refresh or _jwks_cache["keys"] is None or now - _jwks_cache["fetched_at"] > JWKS_TTL_SECONDS:
        response = requests.get(JWKS_URL, timeout=5)
        response.raise_for_status()
        _jwks_cache["keys"] = response.json()["keys"]
        _jwks_cache["fetched_at"] = now
    return _jwks_cache["keys"]


def get_claims_from_token(token: str) -> dict:
    """
    Verify a Cognito ID token's signature against the user pool's JWKS,
    then check issuer, audience, token_use and expiry before returning
    its claims. Raises ValueError on any verification failure.

    district_id and role are only ever trusted after this check passes —
    an unverified decode would let anyone forge those claims and read
    another district's data.
    """
    headers = jwt.get_unverified_header(token)
    kid = headers.get("kid")
    if kid is None:
        raise ValueError("Token header missing kid")

    keys = _get_jwks()
    key_data = next((k for k in keys if k["kid"] == kid), None)
    if key_data is None:
        # Key may have rotated — refresh once and retry before giving up.
        keys = _get_jwks(force_refresh=True)
        key_data = next((k for k in keys if k["kid"] == kid), None)
        if key_data is None:
            raise ValueError("Signing key not found in JWKS")

    public_key = jwk.construct(key_data)
    message, encoded_sig = token.rsplit(".", 1)
    decoded_sig = base64url_decode(encoded_sig.encode("utf-8"))
    if not public_key.verify(message.encode("utf-8"), decoded_sig):
        raise ValueError("Signature verification failed")

    claims = jwt.get_unverified_claims(token)

    if claims.get("exp", 0) < time.time():
        raise ValueError("Token expired")
    if claims.get("iss") != ISSUER:
        raise ValueError("Invalid issuer")
    if claims.get("token_use") != "id":
        raise ValueError("Expected an ID token")
    if claims.get("aud") != APP_CLIENT_ID:
        raise ValueError("Invalid audience")

    return {
        "district_id": claims.get("custom:district_id", "unknown"),
        "role": claims.get("custom:role", "unknown"),
        "user_id": claims.get("sub", "unknown")
    }


@app.route("/health", methods=["GET"])
def health():
    if lead_agent is None:
        return jsonify({
            "status": "degraded",
            "service": "EduMind AI",
            "reason": "agent.orchestrator failed to import"
        }), 503
    return jsonify({
        "status": "ok",
        "service": "EduMind AI",
        "phase": "2 — multi-agent orchestration active"
    })


@app.route("/chat", methods=["POST"])
def chat():
    if lead_agent is None:
        return jsonify({"error": "Agent temporarily unavailable"}), 503

    try:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "Missing authorization token"}), 401

        token = auth_header.replace("Bearer ", "")
        try:
            claims = get_claims_from_token(token)
        except ValueError as e:
            logger.warning(f"Token verification failed: {str(e)}")
            return jsonify({"error": "Invalid or expired token"}), 401

        district_id = claims["district_id"]
        role = claims["role"]
        user_id = claims["user_id"]

        if district_id == "unknown":
            return jsonify({"error": "Invalid district"}), 403

        body = request.get_json()
        if not body or "message" not in body:
            return jsonify({"error": "message field required"}), 400

        user_message = body["message"]

        # Set context for tools based on role.
        # Tools read context from here — never from user input.
        set_curriculum_context(district_id)
        if role == "student":
            set_student_context(district_id, user_id)
        elif role == "teacher":
            set_teacher_context(district_id, user_id)
        elif role == "administrator":
            set_admin_context(district_id, user_id)
        else:
            return jsonify({"error": "Unrecognized role"}), 403

        # Log to CloudWatch for FERPA audit
        logger.info(json.dumps({
            "event": "agent_invocation",
            "district_id": district_id,
            "role": role,
            "user_id": user_id,
            "message_length": len(user_message)
        }))

        # Route through orchestrator
        result = lead_agent(
            f"User role: {role}. Request: {user_message}"
        )

        return jsonify({
            "response": str(result),
            "district": district_id,
            "role": role
        })

    except Exception as e:
        logger.error(f"Agent invocation failed: {str(e)}")
        return jsonify({"error": "Agent temporarily unavailable"}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
