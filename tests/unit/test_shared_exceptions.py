"""Unit tests for shared exceptions module."""

from __future__ import annotations

from shared.exceptions import ItemNotFoundError, ValidationError


class TestItemNotFoundError:
    """Tests for ItemNotFoundError exception."""

    def test_message_contains_item_id(self) -> None:
        exc = ItemNotFoundError("abc-123")
        assert "abc-123" in str(exc)

    def test_stores_item_id(self) -> None:
        exc = ItemNotFoundError("my-id")
        assert exc.item_id == "my-id"

    def test_is_exception(self) -> None:
        exc = ItemNotFoundError("x")
        assert isinstance(exc, Exception)


class TestValidationError:
    """Tests for ValidationError exception."""

    def test_message(self) -> None:
        exc = ValidationError("bad input")
        assert exc.message == "bad input"

    def test_default_details_empty(self) -> None:
        exc = ValidationError("bad input")
        assert exc.details == {}

    def test_custom_details(self) -> None:
        details = {"field": "required"}
        exc = ValidationError("bad input", details=details)
        assert exc.details == details

    def test_str_representation(self) -> None:
        exc = ValidationError("something went wrong")
        assert str(exc) == "something went wrong"

    def test_is_exception(self) -> None:
        exc = ValidationError("x")
        assert isinstance(exc, Exception)
