"""Pydantic models for Item CRUD operations."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from pydantic import BaseModel, Field


class ItemCreate(BaseModel):
    """Request model for creating an item."""

    name: str = Field(..., min_length=1, max_length=255, description="Item name")
    description: str | None = Field(None, max_length=1024, description="Item description")
    price: float | None = Field(None, ge=0, description="Item price (must be non-negative)")


class ItemUpdate(BaseModel):
    """Request model for updating an item (all fields optional)."""

    name: str | None = Field(None, min_length=1, max_length=255, description="Item name")
    description: str | None = Field(None, max_length=1024, description="Item description")
    price: float | None = Field(None, ge=0, description="Item price (must be non-negative)")


class ItemResponse(BaseModel):
    """Response model for an item."""

    id: str
    name: str
    description: str | None = None
    price: float | None = None
    created_at: str
    updated_at: str


def generate_item_id() -> str:
    """Generate a unique item ID."""
    return str(uuid4())


def now_iso() -> str:
    """Return the current UTC time as an ISO 8601 string."""
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")
