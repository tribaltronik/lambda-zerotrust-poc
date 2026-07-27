"""DELETE /items/{id} — Delete an item."""

from __future__ import annotations

from typing import Any

from shared.config import logger, metrics, tracer
from shared.db import delete_item
from shared.exceptions import ItemNotFoundError, ValidationError
from shared.responses import internal_error, no_content, not_found


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Handle DELETE /items/{id} requests."""
    try:
        item_id = _extract_item_id(event)
        delete_item(item_id)

        metrics.add_metric(name="ItemDeleted", unit="Count", value=1)
        return no_content()

    except ItemNotFoundError as exc:
        return not_found(str(exc))
    except ValidationError as exc:
        return not_found(str(exc))
    except Exception:  # noqa: BLE001 — last-resort safety net for Lambda
        logger.exception("Unexpected error deleting item")
        return internal_error("Failed to delete item")


def _extract_item_id(event: dict[str, Any]) -> str:
    """Extract the item ID from path parameters."""
    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")
    if not item_id:
        raise ValidationError("Item ID is required in path")
    return item_id
