"""Unit tests for the update_item handler."""

from __future__ import annotations

import json
from decimal import Decimal
from typing import Any
from unittest.mock import MagicMock

import boto3

TABLE_NAME = "lambda-zerotrust-poc-items"


def _insert_item(item_id: str = "test-id", name: str = "Original Name") -> None:
    """Insert a test item directly into DynamoDB."""
    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    table = dynamodb.Table(TABLE_NAME)
    table.put_item(
        Item={
            "PK": f"ITEM#{item_id}",
            "SK": "METADATA",
            "id": item_id,
            "name": name,
            "description": "Original description",
            "price": Decimal("10.0"),
            "created_at": "2025-01-01T00:00:00Z",
            "updated_at": "2025-01-01T00:00:00Z",
        }
    )


class TestUpdateItemHandler:
    """Tests for PUT /items/{id} handler."""

    def test_update_name(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.update_item import lambda_handler

        _insert_item("upd-1", "Old Name")

        event = api_event(
            http_method="PUT",
            path="/items/upd-1",
            path_parameters={"id": "upd-1"},
            body={"name": "New Name"},
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["name"] == "New Name"
        assert body["description"] == "Original description"

    def test_update_price(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.update_item import lambda_handler

        _insert_item("upd-2")

        event = api_event(
            http_method="PUT",
            path="/items/upd-2",
            path_parameters={"id": "upd-2"},
            body={"price": 99.99},
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["price"] == 99.99
        assert body["name"] == "Original Name"

    def test_update_multiple_fields(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.update_item import lambda_handler

        _insert_item("upd-3")

        event = api_event(
            http_method="PUT",
            path="/items/upd-3",
            path_parameters={"id": "upd-3"},
            body={"name": "Updated", "price": 5.0, "description": "New desc"},
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["name"] == "Updated"
        assert body["price"] == 5.0
        assert body["description"] == "New desc"

    def test_update_nonexistent_item(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.update_item import lambda_handler

        event = api_event(
            http_method="PUT",
            path="/items/no-such-id",
            path_parameters={"id": "no-such-id"},
            body={"name": "X"},
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 404

    def test_update_empty_body_returns_existing(
        self, api_event: Any, lambda_context: MagicMock
    ) -> None:
        from handlers.update_item import lambda_handler

        _insert_item("upd-4", "Keep Me")

        event = api_event(
            http_method="PUT",
            path="/items/upd-4",
            path_parameters={"id": "upd-4"},
            body={},
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["name"] == "Keep Me"

    def test_update_invalid_price(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.update_item import lambda_handler

        _insert_item("upd-5")

        event = api_event(
            http_method="PUT",
            path="/items/upd-5",
            path_parameters={"id": "upd-5"},
            body={"price": -5},
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 400

    def test_update_missing_id(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.update_item import lambda_handler

        event = api_event(
            http_method="PUT", path="/items/", path_parameters={}, body={"name": "X"}
        )
        response = lambda_handler(event, lambda_context)

        # Should return 400 (validation error) since path param is missing
        assert response["statusCode"] == 400

    def test_update_returns_json_content_type(
        self, api_event: Any, lambda_context: MagicMock
    ) -> None:
        from handlers.update_item import lambda_handler

        _insert_item("upd-6")
        event = api_event(
            http_method="PUT",
            path="/items/upd-6",
            path_parameters={"id": "upd-6"},
            body={"name": "CT"},
        )
        response = lambda_handler(event, lambda_context)

        assert response["headers"]["Content-Type"] == "application/json"
