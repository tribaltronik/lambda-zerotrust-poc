"""DynamoDB access layer for Items table.

Single-table design:
  PK: ITEM#<uuid>
  SK: METADATA

All access patterns go through this module.
"""

from __future__ import annotations

import os
from decimal import Decimal
from typing import Any

import boto3
from mypy_boto3_dynamodb.service_resource import DynamoDBServiceResource, Table

from shared.config import tracer
from shared.exceptions import ItemNotFoundError
from shared.models import ItemCreate, ItemUpdate, generate_item_id, now_iso


def get_table() -> Table:
    """Return the DynamoDB Table resource using the configured table name."""
    table_name = os.environ["DYNAMODB_TABLE_NAME"]
    resource: DynamoDBServiceResource = boto3.resource("dynamodb")
    return resource.Table(table_name)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _pk(item_id: str) -> str:
    return f"ITEM#{item_id}"


SK_VALUE = "METADATA"


def _to_decimal(value: Any) -> Any:
    """Convert float values to Decimal for DynamoDB compatibility.

    DynamoDB does not support Python float types — only Decimal.
    Recursively handles nested structures (lists, dicts).
    """
    if isinstance(value, float):
        return Decimal(str(value))
    if isinstance(value, dict):
        return {k: _to_decimal(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_to_decimal(item) for item in value]
    return value


# ---------------------------------------------------------------------------
# CRUD operations
# ---------------------------------------------------------------------------

@tracer.capture_method
def create_item(item: ItemCreate) -> dict[str, Any]:
    """Insert a new item into DynamoDB and return the stored record."""
    table = get_table()
    item_id = generate_item_id()
    now = now_iso()

    record: dict[str, Any] = {
        "PK": _pk(item_id),
        "SK": SK_VALUE,
        "id": item_id,
        "name": item.name,
        "created_at": now,
        "updated_at": now,
    }
    if item.description is not None:
        record["description"] = item.description
    if item.price is not None:
        record["price"] = _to_decimal(item.price)

    table.put_item(Item=record)
    return record


@tracer.capture_method
def get_item(item_id: str) -> dict[str, Any]:
    """Retrieve a single item by ID. Raises ItemNotFoundError if missing."""
    table = get_table()
    response = table.get_item(Key={"PK": _pk(item_id), "SK": SK_VALUE})
    item = response.get("Item")
    if item is None:
        raise ItemNotFoundError(item_id)
    return item


@tracer.capture_method
def list_items() -> list[dict[str, Any]]:
    """Scan the table and return all items."""
    table = get_table()
    response = table.scan()
    return response.get("Items", [])


@tracer.capture_method
def update_item(item_id: str, updates: ItemUpdate) -> dict[str, Any]:
    """Apply partial updates to an item. Raises ItemNotFoundError if missing."""
    table = get_table()

    # Build the update expression dynamically from non-None fields
    update_fields: dict[str, Any] = {}
    if updates.name is not None:
        update_fields["name"] = updates.name
    if updates.description is not None:
        update_fields["description"] = updates.description
    if updates.price is not None:
        update_fields["price"] = _to_decimal(updates.price)

    if not update_fields:
        # Nothing to update — just return the existing item
        return get_item(item_id)

    update_fields["updated_at"] = now_iso()

    update_expr_parts: list[str] = []
    expr_attr_values: dict[str, Any] = {}
    expr_attr_names: dict[str, str] = {}

    for i, (key, value) in enumerate(update_fields.items()):
        placeholder_value = f":val{i}"
        placeholder_name = f"#attr{i}"
        update_expr_parts.append(f"{placeholder_name} = {placeholder_value}")
        expr_attr_values[placeholder_value] = value
        expr_attr_names[placeholder_name] = key

    update_expression = "SET " + ", ".join(update_expr_parts)

    try:
        response = table.update_item(
            Key={"PK": _pk(item_id), "SK": SK_VALUE},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expr_attr_values,
            ExpressionAttributeNames=expr_attr_names,
            ConditionExpression=attribute_exists("PK"),
            ReturnValues="ALL_NEW",
        )
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        raise ItemNotFoundError(item_id)

    return response["Attributes"]


@tracer.capture_method
def delete_item(item_id: str) -> None:
    """Delete an item by ID. Raises ItemNotFoundError if missing."""
    table = get_table()
    try:
        table.delete_item(
            Key={"PK": _pk(item_id), "SK": SK_VALUE},
            ConditionExpression=attribute_exists("PK"),
        )
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        raise ItemNotFoundError(item_id)


def attribute_exists(attribute_name: str) -> Any:
    """DynamoDB ConditionExpression helper: attribute_exists(#name)."""
    from boto3.dynamodb.conditions import Attr

    return Attr(attribute_name).exists()
