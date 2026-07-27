"""Standardized API response helpers for Lambda proxy integration."""

from __future__ import annotations

import json
from decimal import Decimal
from typing import Any


class _DecimalEncoder(json.JSONEncoder):
    """JSON encoder that converts Decimal to float for proper serialization."""

    def default(self, obj: Any) -> Any:
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)


def success(status_code: int, body: Any) -> dict[str, Any]:
    """Build a successful API Gateway proxy response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(body, cls=_DecimalEncoder),
    }


def error(status_code: int, message: str, details: dict | None = None) -> dict[str, Any]:
    """Build an error API Gateway proxy response."""
    body: dict[str, Any] = {"message": message}
    if details:
        body["errors"] = details
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(body),
    }


# Convenience helpers
def created(body: Any) -> dict[str, Any]:
    return success(201, body)


def ok(body: Any) -> dict[str, Any]:
    return success(200, body)


def no_content() -> dict[str, Any]:
    return {
        "statusCode": 204,
        "headers": {"Content-Type": "application/json"},
        "body": "",
    }


def bad_request(message: str, details: dict | None = None) -> dict[str, Any]:
    return error(400, message, details)


def not_found(message: str) -> dict[str, Any]:
    return error(404, message)


def internal_error(message: str = "Internal server error") -> dict[str, Any]:
    return error(500, message)
