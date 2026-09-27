"""Accept only gateway-authorized AI requests; initialize enabled services only after validation."""

import base64
import json
import logging
import os
from dataclasses import dataclass
from collections.abc import Callable
from contextlib import ExitStack
from datetime import UTC, datetime

from .contracts import MAX_REQUEST_BYTES, Request, parse_json
from .errors import Code, ComposeError
from .service import CompositionService

log = logging.getLogger(__name__)


class Unauthorized(Exception):
    pass


@dataclass(frozen=True)
class Authentication:
    issuer: str
    client_id: str
    approved_subject: str

    def __post_init__(self):
        if not all(value.strip() for value in (self.issuer, self.client_id, self.approved_subject)):
            raise ValueError("Cognito configuration is required")

    def authenticate(self, event: dict, now: datetime) -> str:
        # Gateway verifies JWT signatures. Never use request headers/body as a source of identity.
        claims = event
        for key in ("requestContext", "authorizer", "jwt", "claims"):
            claims = claims.get(key) if isinstance(claims, dict) else None
        if not isinstance(claims, dict):
            raise Unauthorized()
        expires = str(claims.get("exp", ""))
        scopes = claims.get("scope", "")
        if (event.get("version") != "2.0" or claims.get("iss") != self.issuer
                or claims.get("client_id") != self.client_id or claims.get("sub") != self.approved_subject
                or claims.get("token_use") != "access" or not expires.isascii() or not expires.isdigit()
                or int(expires) <= int(now.timestamp()) or not isinstance(scopes, str)
                or "reports/write" not in scopes.split(" ")):
            raise Unauthorized()
        return self.approved_subject


def response(status: int, body: dict) -> dict:
    return {"statusCode": status, "headers": {"content-type": "application/json", "cache-control": "no-store"},
            "isBase64Encoded": False, "body": json.dumps(body, allow_nan=False)}


def failure(code: Code) -> dict:
    statuses = {Code.INVALID_INPUT: 400, Code.DAILY_QUOTA: 429, Code.BUDGET_EXHAUSTED: 429,
                Code.RATE_LIMITED: 429, Code.PENDING: 409, Code.MISMATCH: 409, Code.EXPIRED: 410,
                Code.TIMEOUT: 504, Code.INVALID_OUTPUT: 502, Code.DISABLED: 503, Code.UNAVAILABLE: 503}
    return response(statuses[code], {"code": code.value})


def request_bytes(event: dict) -> bytes:
    body = event.get("body")
    encoded = event.get("isBase64Encoded", False)
    if not isinstance(body, str) or type(encoded) is not bool or len(body) > MAX_REQUEST_BYTES * 2:
        raise ValueError("Invalid body")
    data = base64.b64decode(body, validate=True) if encoded else body.encode("utf-8")
    if len(data) > MAX_REQUEST_BYTES:
        raise ValueError("Body too large")
    return data


class ComposeHandler:
    def __init__(self, authentication: Authentication, service: CompositionService | None = None,
                 service_factory: Callable[[], CompositionService] | None = None):
        self.authentication = authentication
        self.service = service
        self.service_factory = service_factory

    def handle(self, event: dict, now: datetime) -> dict:
        try:
            if not isinstance(event, dict):
                return failure(Code.INVALID_INPUT)
            subject = self.authentication.authenticate(event, now)
            if event.get("routeKey") != "POST /ai/compose":
                return response(404, {"code": "NOT_FOUND"})
            try:
                request = parse_json(Request, request_bytes(event))
            except (ValueError, TypeError, RecursionError):
                return failure(Code.INVALID_INPUT)
            service = self.service
            if service is None and self.service_factory is not None:
                service = self.service_factory()
            if service is None:
                return failure(Code.DISABLED)
            result = service.compose(subject, request)
            return response(200, result.model_dump(mode="json", by_alias=True))
        except Unauthorized:
            return response(401, {"code": "UNAUTHENTICATED"})
        except ComposeError as error:
            return failure(error.code)
        except Exception:
            # Exceptions may contain input or credentials. Never log their messages or tracebacks.
            log.error("AI composition storage or configuration failure")
            return failure(Code.UNAVAILABLE)


def lambda_handler(event, context):
    """Default to disabled; require valid runtime pricing before loading the secret."""
    try:
        authentication = Authentication(os.environ.get("COGNITO_ISSUER", ""), os.environ.get("COGNITO_CLIENT_ID", ""),
                                        os.environ.get("APPROVED_SUBJECT", ""))
        from .runtime import build_service
        with ExitStack() as resources:
            return ComposeHandler(authentication, service_factory=lambda: build_service(os.environ, resources)).handle(
                event, datetime.now(UTC))
    except Exception:
        return failure(Code.UNAVAILABLE)
