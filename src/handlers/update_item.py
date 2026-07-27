"""PUT /items/{id} — Update an existing item."""

from __future__ import annotations

import json
from typing import Any

from pydantic import ValidationError as PydanticValidationError

from shared.config import logger, metrics, tracer
from shared.db import update_item
from shared.exceptions import ItemNotFoundError, ValidationError
from shared.models import ItemUpdate
from shared.responses import bad_request, internal_error, not_found, ok


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Handle PUT /items/{id} requests."""
    try:
        item_id = _extract_item_id(event)
        body = _parse_body(event)
        updates = _validate(body)
        record = update_item(item_id, updates)

        metrics.add_metric(name="ItemUpdated", unit="Count", value=1)
        return ok(record)

    except ItemNotFoundError as exc:
        return not_found(str(exc))
    except (ValidationError, PydanticValidationError) as exc:
        return _handle_validation_error(exc)
    except Exception:  # noqa: BLE001 — last-resort safety net for Lambda
        logger.exception("Unexpected error updating item")
        return internal_error("Failed to update item")


def _extract_item_id(event: dict[str, Any]) -> str:
    """Extract the item ID from path parameters."""
    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")
    if not item_id:
        raise ValidationError("Item ID is required in path")
    return item_id


def _parse_body(event: dict[str, Any]) -> dict[str, Any]:
    """Extract and parse the JSON request body."""
    raw_body = event.get("body")
    if raw_body is None:
        raise ValidationError("Request body is required")
    try:
        return json.loads(raw_body) if isinstance(raw_body, str) else raw_body
    except json.JSONDecodeError as exc:
        raise ValidationError("Invalid JSON in request body") from exc


def _validate(body: dict[str, Any]) -> ItemUpdate:
    """Validate the request body against the ItemUpdate model."""
    try:
        return ItemUpdate(**body)
    except PydanticValidationError as exc:
        raise ValidationError("Validation failed", details=exc.errors()) from exc


def _handle_validation_error(exc: Exception) -> dict[str, Any]:
    """Convert validation errors to a 400 response."""
    if isinstance(exc, ValidationError):
        return bad_request(exc.message, exc.details)
    if isinstance(exc, PydanticValidationError):
        return bad_request("Validation failed", details=exc.errors())
    return bad_request(str(exc))
