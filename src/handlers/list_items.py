"""GET /items — List all items."""

from __future__ import annotations

from typing import Any

from shared.config import logger, metrics, tracer
from shared.db import list_items
from shared.responses import internal_error, ok


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Handle GET /items requests."""
    try:
        items = list_items()

        metrics.add_metric(name="ItemsListed", unit="Count", value=1)
        return ok({"items": items, "count": len(items)})

    except Exception:  # noqa: BLE001 — last-resort safety net for Lambda
        logger.exception("Unexpected error listing items")
        return internal_error("Failed to list items")
