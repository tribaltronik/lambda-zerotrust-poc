"""Unit tests for the create_item handler."""

from __future__ import annotations

import json
from typing import Any
from unittest.mock import MagicMock


class TestCreateItemHandler:
    """Tests for POST /items handler."""

    def test_create_item_success(
        self, api_event: Any, sample_item: dict[str, Any], lambda_context: MagicMock
    ) -> None:
        from handlers.create_item import lambda_handler

        event = api_event(http_method="POST", path="/items", body=sample_item)
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 201
        body = json.loads(response["body"])
        assert body["name"] == sample_item["name"]
        assert body["description"] == sample_item["description"]
        assert body["price"] == 29.99
        assert "id" in body
        assert "created_at" in body
        assert "updated_at" in body
        # PK/SK should be in DynamoDB format
        assert body["PK"].startswith("ITEM#")
        assert body["SK"] == "METADATA"

    def test_create_item_minimal(
        self, api_event: Any, minimal_item: dict[str, Any], lambda_context: MagicMock
    ) -> None:
        from handlers.create_item import lambda_handler

        event = api_event(http_method="POST", path="/items", body=minimal_item)
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 201
        body = json.loads(response["body"])
        assert body["name"] == minimal_item["name"]
        assert "description" not in body
        assert "price" not in body

    def test_create_item_missing_name(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.create_item import lambda_handler

        event = api_event(http_method="POST", path="/items", body={"description": "no name"})
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 400
        body = json.loads(response["body"])
        assert "message" in body

    def test_create_item_empty_name(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.create_item import lambda_handler

        event = api_event(http_method="POST", path="/items", body={"name": ""})
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 400

    def test_create_item_negative_price(
        self, api_event: Any, lambda_context: MagicMock
    ) -> None:
        from handlers.create_item import lambda_handler

        event = api_event(
            http_method="POST",
            path="/items",
            body={"name": "Bad Price", "price": -10},
        )
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 400

    def test_create_item_invalid_json(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.create_item import lambda_handler

        event = api_event(http_method="POST", path="/items")
        event["body"] = "not-json"
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 400

    def test_create_item_no_body(self, api_event: Any, lambda_context: MagicMock) -> None:
        from handlers.create_item import lambda_handler

        event = api_event(http_method="POST", path="/items")
        # build_event does not add body key when body=None; ensure it's absent
        event.pop("body", None)
        response = lambda_handler(event, lambda_context)

        assert response["statusCode"] == 400

    def test_create_item_returns_json_content_type(
        self, api_event: Any, sample_item: dict[str, Any], lambda_context: MagicMock
    ) -> None:
        from handlers.create_item import lambda_handler

        event = api_event(http_method="POST", path="/items", body=sample_item)
        response = lambda_handler(event, lambda_context)

        assert response["headers"]["Content-Type"] == "application/json"
