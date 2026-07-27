"""Unit tests for the delete_item handler."""

from __future__ import annotations

from typing import Any
from unittest.mock import MagicMock

import boto3

TABLE_NAME = "lambda-zerotrust-poc-items"


def _insert_item(item_id: str = "test-id", name: str = "Delete Me") -> None:
    """Insert a test item directly into DynamoDB."""
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
        }
    )


def _item_exists(item_id: str) -> bool:
    """Check if an item exists in DynamoDB."""
    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    table = dynamodb.Table(TABLE_NAME)
    response = table.get_item(Key={"PK": f"ITEM#{item_id}", "SK": "METADATA"})
    return "Item" in response


class TestDeleteItemHandler:
    """Tests for DELETE /items/{id} handler."""

    def test_delete_existing_item(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.delete_item import lambda_handler

        _insert_item("del-1")
        assert _item_exists("del-1")

        event = api_event(
            http_method="DELETE", path="/items/del-1", path_parameters={"id": "del-1"}
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 204
        assert not _item_exists("del-1")

    def test_delete_nonexistent_item(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.delete_item import lambda_handler

        event = api_event(
            http_method="DELETE",
            path="/items/no-such-id",
            path_parameters={"id": "no-such-id"},
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 404

    def test_delete_missing_id(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.delete_item import lambda_handler

        event = api_event(http_method="DELETE", path="/items/", path_parameters={})
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 404

    def test_delete_idempotent(self, api_event: Any, lambda_context: MagicMock) -> None:
        """Deleting the same item twice should return 404 on the second call."""
        from handlers.delete_item import lambda_handler

        _insert_item("del-2")

        event = api_event(
            http_method="DELETE", path="/items/del-2", path_parameters={"id": "del-2"}
        )
        response1 = lambda_handler(event, lambda_context)
        assert response1["statusCode"] == 204

        response2 = lambda_handler(event, lambda_context)
        assert response2["statusCode"] == 404
