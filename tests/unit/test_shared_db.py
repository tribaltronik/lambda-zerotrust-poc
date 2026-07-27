"""Unit tests for shared DynamoDB access layer."""

from __future__ import annotations

import os

import pytest

from shared.db import create_item, delete_item, get_item, list_items, update_item
from shared.exceptions import ItemNotFoundError
from shared.models import ItemCreate, ItemUpdate

os.environ.setdefault("DYNAMODB_TABLE_NAME", "lambda-zerotrust-poc-items")


class TestCreateItem:
    """Tests for the create_item DB function."""

    def test_creates_and_returns_record(self) -> None:
        from decimal import Decimal

        item = ItemCreate(name="Widget", description="A widget", price=4.99)
        record = create_item(item)

        assert record["name"] == "Widget"
        assert record["description"] == "A widget"
        assert record["price"] == Decimal("4.99")
        assert record["PK"].startswith("ITEM#")
        assert record["SK"] == "METADATA"
        assert "created_at" in record
        assert "updated_at" in record

    def test_creates_minimal_record(self) -> None:
        item = ItemCreate(name="Bare")
        record = create_item(item)

        assert record["name"] == "Bare"
        assert "description" not in record
        assert "price" not in record


class TestGetItem:
    """Tests for the get_item DB function."""

    def test_get_existing(self) -> None:
        created = create_item(ItemCreate(name="Fetch Me"))
        item_id = created["id"]
        fetched = get_item(item_id)

        assert fetched["id"] == item_id
        assert fetched["name"] == "Fetch Me"

    def test_get_nonexistent_raises(self) -> None:
        with pytest.raises(ItemNotFoundError):
            get_item("nonexistent-id")


class TestListItems:
    """Tests for the list_items DB function."""

    def test_empty_table(self) -> None:
        items = list_items()
        assert items == []

    def test_returns_all_items(self) -> None:
        create_item(ItemCreate(name="A"))
        create_item(ItemCreate(name="B"))

        items = list_items()
        assert len(items) == 2


class TestUpdateItem:
    """Tests for the update_item DB function."""

    def test_update_name(self) -> None:
        created = create_item(ItemCreate(name="Old"))
        item_id = created["id"]
        updated = update_item(item_id, ItemUpdate(name="New"))

        assert updated["name"] == "New"

    def test_update_nonexistent_raises(self) -> None:
        with pytest.raises(ItemNotFoundError):
            update_item("no-such-id", ItemUpdate(name="X"))

    def test_update_empty_returns_unchanged(self) -> None:
        created = create_item(ItemCreate(name="Keep"))
        item_id = created["id"]
        updated = update_item(item_id, ItemUpdate())

        assert updated["name"] == "Keep"


class TestDeleteItem:
    """Tests for the delete_item DB function."""

    def test_delete_existing(self) -> None:
        created = create_item(ItemCreate(name="Gone"))
        item_id = created["id"]

        delete_item(item_id)

        with pytest.raises(ItemNotFoundError):
            get_item(item_id)

    def test_delete_nonexistent_raises(self) -> None:
        with pytest.raises(ItemNotFoundError):
            delete_item("nonexistent-id")
