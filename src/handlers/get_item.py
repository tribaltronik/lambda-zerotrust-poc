"""GET /items/{id} — Get a single item."""

from __future__ import annotations

from typing import Any

from shared.config import logger, metrics, tracer
from shared.db import get_item
from shared.exceptions import ItemNotFoundError, ValidationError
from shared.responses import internal_error, not_found, ok


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Handle GET /items/{id} requests."""
    try:
        item_id = _extract_item_id(event)
        item = get_item(item_id)

        metrics.add_metric(name="ItemRetrieved", unit="Count", value=1)
        return ok(item)

    except ItemNotFoundError as exc:
        return not_found(str(exc))
    except ValidationError as exc:
        return not_found(str(exc))
    except Exception:  # noqa: BLE001 — last-resort safety net for Lambda
        logger.exception("Unexpected error getting item")
        return internal_error("Failed to get item")


def _extract_item_id(event: dict[str, Any]) -> str:
    """Extract the item ID from path parameters."""
    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")
    if not item_id:
        raise ValidationError("Item ID is required in path")
    return item_id
