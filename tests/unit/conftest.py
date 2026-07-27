"""Shared test fixtures for unit tests.

Sets up moto mock for DynamoDB and provides helper factories
for generating test events and sample items.
"""

from __future__ import annotations

import json
from collections.abc import Generator
from typing import Any
from unittest.mock import MagicMock

import boto3
import pytest
from moto import mock_aws

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

TABLE_NAME = "lambda-zerotrust-poc-items"
AWS_REGION = "us-east-1"
AWS_ACCOUNT_ID = "000000000000"


# ---------------------------------------------------------------------------
# Moto DynamoDB fixture
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def _aws_env(monkeypatch: pytest.MonkeyPatch) -> Generator[None]:
    """Set AWS env vars and start moto mock for every test."""
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SECURITY_TOKEN", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")
    monkeypatch.setenv("AWS_DEFAULT_REGION", AWS_REGION)
    monkeypatch.setenv("DYNAMODB_TABLE_NAME", TABLE_NAME)
    monkeypatch.setenv("POWERTOOLS_SERVICE_NAME", "test-service")
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("POWERTOOLS_METRICS_NAMESPACE", "TestNamespace")

    with mock_aws():
        # Create the table
        dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
        dynamodb.create_table(
            TableName=TABLE_NAME,
            KeySchema=[
                {"AttributeName": "PK", "KeyType": "HASH"},
                {"AttributeName": "SK", "KeyType": "RANGE"},
            ],
            AttributeDefinitions=[
                {"AttributeName": "PK", "AttributeType": "S"},
                {"AttributeName": "SK", "AttributeType": "S"},
            ],
            BillingMode="PAY_PER_REQUEST",
        )
        yield


# ---------------------------------------------------------------------------
# Mock Lambda context
# ---------------------------------------------------------------------------

@pytest.fixture
def lambda_context() -> MagicMock:
    """Return a mock Lambda context object that satisfies Powertools."""
    context = MagicMock()
    context.function_name = "test-function"
    context.memory_limit_in_mb = "128"
    context.invoked_function_arn = (
        f"arn:aws:lambda:{AWS_REGION}:{AWS_ACCOUNT_ID}:function:test-function"
    )
    context.aws_request_id = "test-request-id-000"
    context.log_group_name = "/aws/lambda/test-function"
    context.log_stream_name = "2025/01/01/[$LATEST]abcdef"
    context.function_version = "$LATEST"
    context.client_context = None
    context.identity = None
    return context


# ---------------------------------------------------------------------------
# Sample item factory
# ---------------------------------------------------------------------------

@pytest.fixture
def sample_item() -> dict[str, Any]:
    """Return a valid item payload for POST /items."""
    return {
        "name": "Test Item",
        "description": "A test item description",
        "price": 29.99,
    }


@pytest.fixture
def minimal_item() -> dict[str, Any]:
    """Return a minimal valid item payload (only required fields)."""
    return {"name": "Minimal Item"}


# ---------------------------------------------------------------------------
# API Gateway event builders
# ---------------------------------------------------------------------------

def build_event(
    *,
    http_method: str,
    path: str,
    path_parameters: dict[str, str] | None = None,
    body: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Build a simulated API Gateway REST API event."""
    event: dict[str, Any] = {
        "httpMethod": http_method,
        "path": path,
        "headers": {
            "Content-Type": "application/json",
            "Authorization": "Bearer fake-jwt-token",
        },
        "requestContext": {
            "requestId": "test-request-id",
            "stage": "dev",
            "httpMethod": http_method,
            "path": path,
            "identity": {"sourceIp": "127.0.0.1"},
            "authorizer": {
                "claims": {
                    "sub": "test-user-id",
                    "email": "test@example.com",
                },
            },
        },
    }
    if path_parameters:
        event["pathParameters"] = path_parameters
    if body is not None:
        event["body"] = json.dumps(body)
    return event


@pytest.fixture
def api_event() -> Any:
    """Factory fixture — returns a function to build API events."""
    return build_event
