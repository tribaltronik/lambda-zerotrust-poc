"""Unit tests for the get_item handler."""

from __future__ import annotations

import json
from decimal import Decimal
from typing import Any
from unittest.mock import MagicMock

import boto3

TABLE_NAME = "lambda-zerotrust-poc-items"


def _insert_item(item_id: str = "test-id", name: str = "Test Item") -> None:
    """Insert a test item directly into DynamoDB."""
    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    table = dynamodb.Table(TABLE_NAME)
    table.put_item(
        Item={
            "PK": f"ITEM#{item_id}",
            "SK": "METADATA",
            "id": item_id,
            "name": name,
            "description": "A test item",
            "price": Decimal("9.99"),
            "created_at": "2025-01-01T00:00:00Z",
            "updated_at": "2025-01-01T00:00:00Z",
        }
    )


class TestGetItemHandler:
    """Tests for GET /items/{id} handler."""

    def test_get_existing_item(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.get_item import lambda_handler

        _insert_item("abc-123", "My Item")

        event = api_event(
            http_method="GET", path="/items/abc-123", path_parameters={"id": "abc-123"}
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["id"] == "abc-123"
        assert body["name"] == "My Item"
        assert body["description"] == "A test item"
        assert body["price"] == 9.99

    def test_get_nonexistent_item(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.get_item import lambda_handler

        event = api_event(
            http_method="GET", path="/items/does-not-exist", path_parameters={"id": "does-not-exist"}
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 404
        body = json.loads(response["body"])
        assert "not found" in body["message"].lower()

    def test_get_item_missing_id(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.get_item import lambda_handler

        event = api_event(http_method="GET", path="/items/", path_parameters={})
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 404

    def test_get_item_returns_json_content_type(
        self, api_event: Any, lambda_context: MagicMock
    ) -> None:
        from handlers.get_item import lambda_handler

        _insert_item("xyz-789")
        event = api_event(
            http_method="GET", path="/items/xyz-789", path_parameters={"id": "xyz-789"}
        )
        response = lambda_handler(event, lambda_context)

        assert response["headers"]["Content-Type"] == "application/json"
