"""Unit tests for the list_items handler."""

from __future__ import annotations

import json
from typing import Any
from unittest.mock import MagicMock
from uuid import uuid4

import boto3

TABLE_NAME = "lambda-zerotrust-poc-items"


def _insert_item(name: str = "Test Item", **extra: Any) -> str:
    """Insert a test item directly into DynamoDB. Returns the generated item_id."""
    item_id = str(uuid4())
    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    table = dynamodb.Table(TABLE_NAME)
    table.put_item(
        Item={
            "PK": f"ITEM#{item_id}",
            "SK": "METADATA",
            "id": item_id,
            "name": name,
            "created_at": "2025-01-01T00:00:00Z",
            "updated_at": "2025-01-01T00:00:00Z",
            **extra,
        }
    )
    return item_id


class TestListItemsHandler:
    """Tests for GET /items handler."""

    def test_list_empty(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.list_items import lambda_handler

        event = api_event(http_method="GET", path="/items")
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["items"] == []
        assert body["count"] == 0

    def test_list_with_items(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.list_items import lambda_handler

        _insert_item("Item A")
        _insert_item("Item B")

        event = api_event(http_method="GET", path="/items")
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["count"] == 2
        names = {item["name"] for item in body["items"]}
        assert names == {"Item A", "Item B"}

    def test_list_returns_json_content_type(
        self, api_event: Any, lambda_context: MagicMock
    ) -> None:
        from handlers.list_items import lambda_handler

        event = api_event(http_method="GET", path="/items")
        response = lambda_handler(event, lambda_context)

        assert response["headers"]["Content-Type"] == "application/json"
