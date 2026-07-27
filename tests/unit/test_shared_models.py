"""Unit tests for shared Pydantic models."""

from __future__ import annotations

import pytest
from pydantic import ValidationError as PydanticValidationError

from shared.models import ItemCreate, ItemUpdate, generate_item_id, now_iso


class TestItemCreate:
    """Tests for the ItemCreate model."""

    def test_valid_item(self) -> None:
        item = ItemCreate(name="Test", description="Desc", price=10.0)
        assert item.name == "Test"
        assert item.description == "Desc"
        assert item.price == 10.0

    def test_minimal_item(self) -> None:
        item = ItemCreate(name="Test")
        assert item.name == "Test"
        assert item.description is None
        assert item.price is None

    def test_empty_name_rejected(self) -> None:
        with pytest.raises(PydanticValidationError):
            ItemCreate(name="")

    def test_long_name_rejected(self) -> None:
        with pytest.raises(PydanticValidationError):
            ItemCreate(name="x" * 256)

    def test_negative_price_rejected(self) -> None:
        with pytest.raises(PydanticValidationError):
            ItemCreate(name="Test", price=-1)

    def test_zero_price_accepted(self) -> None:
        item = ItemCreate(name="Free", price=0)
        assert item.price == 0


class TestItemUpdate:
    """Tests for the ItemUpdate model."""

    def test_all_none(self) -> None:
        update = ItemUpdate()
        assert update.name is None
        assert update.description is None
        assert update.price is None

    def test_partial_update(self) -> None:
        update = ItemUpdate(name="New Name")
        assert update.name == "New Name"
        assert update.description is None

    def test_empty_name_rejected(self) -> None:
        with pytest.raises(PydanticValidationError):
            ItemUpdate(name="")

    def test_negative_price_rejected(self) -> None:
        with pytest.raises(PydanticValidationError):
            ItemUpdate(price=-5)


class TestHelpers:
    """Tests for helper functions."""

    def test_generate_item_id_returns_string(self) -> None:
        item_id = generate_item_id()
        assert isinstance(item_id, str)
        assert len(item_id) == 36  # UUID format

    def test_generate_item_id_unique(self) -> None:
        ids = {generate_item_id() for _ in range(100)}
        assert len(ids) == 100

    def test_now_iso_format(self) -> None:
        ts = now_iso()
        assert ts.endswith("Z")
        assert "T" in ts
