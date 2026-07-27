"""POST /items — Create a new item."""

from __future__ import annotations

import json
from typing import Any

from pydantic import ValidationError as PydanticValidationError

from shared.config import logger, metrics, tracer
from shared.db import create_item
from shared.exceptions import ValidationError
from shared.models import ItemCreate
from shared.responses import bad_request, created, internal_error


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Handle POST /items requests."""
    try:
        body = _parse_body(event)
        item = _validate(body)
        record = create_item(item)

        metrics.add_metric(name="ItemCreated", unit="Count", value=1)
        return created(record)

    except (ValidationError, PydanticValidationError) as exc:
        return _handle_validation_error(exc)
    except Exception:  # noqa: BLE001 — last-resort safety net for Lambda
        logger.exception("Unexpected error creating item")
        return internal_error("Failed to create item")


def _parse_body(event: dict[str, Any]) -> dict[str, Any]:
    """Extract and parse the JSON request body."""
    raw_body = event.get("body")
    if raw_body is None:
        raise ValidationError("Request body is required")
    try:
        return json.loads(raw_body) if isinstance(raw_body, str) else raw_body
    except json.JSONDecodeError as exc:
        raise ValidationError("Invalid JSON in request body") from exc


def _validate(body: dict[str, Any]) -> ItemCreate:
    """Validate the request body against the ItemCreate model."""
    try:
        return ItemCreate(**body)
    except PydanticValidationError as exc:
        raise ValidationError("Validation failed", details=exc.errors()) from exc


def _handle_validation_error(exc: Exception) -> dict[str, Any]:
    """Convert validation errors to a 400 response."""
    if isinstance(exc, ValidationError):
        return bad_request(exc.message, exc.details)
    if isinstance(exc, PydanticValidationError):
        return bad_request("Validation failed", details=exc.errors())
    return bad_request(str(exc))
