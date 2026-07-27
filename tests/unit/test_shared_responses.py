"""Unit tests for shared response helpers."""

from __future__ import annotations

import json

from shared.responses import (
    bad_request,
    created,
    error,
    internal_error,
    no_content,
    not_found,
    ok,
    success,
)


class TestSuccessResponses:
    """Tests for success response helpers."""

    def test_success_200(self) -> None:
        resp = success(200, {"key": "value"})
        assert resp["statusCode"] == 200
        body = json.loads(resp["body"])
        assert body == {"key": "value"}

    def test_created(self) -> None:
        resp = created({"id": "123"})
        assert resp["statusCode"] == 201
        body = json.loads(resp["body"])
        assert body["id"] == "123"

    def test_ok(self) -> None:
        resp = ok({"items": []})
        assert resp["statusCode"] == 200

    def test_no_content(self) -> None:
        resp = no_content()
        assert resp["statusCode"] == 204
        assert resp["body"] == ""

    def test_json_content_type(self) -> None:
        resp = ok({})
        assert resp["headers"]["Content-Type"] == "application/json"


class TestErrorResponses:
    """Tests for error response helpers."""

    def test_bad_request(self) -> None:
        resp = bad_request("Invalid input")
        assert resp["statusCode"] == 400
        body = json.loads(resp["body"])
        assert body["message"] == "Invalid input"

    def test_bad_request_with_details(self) -> None:
        resp = bad_request("Invalid", details={"field": "required"})
        body = json.loads(resp["body"])
        assert body["errors"] == {"field": "required"}

    def test_not_found(self) -> None:
        resp = not_found("Item missing")
        assert resp["statusCode"] == 404

    def test_internal_error(self) -> None:
        resp = internal_error()
        assert resp["statusCode"] == 500

    def test_error_custom_status(self) -> None:
        resp = error(418, "I'm a teapot")
        assert resp["statusCode"] == 418
        body = json.loads(resp["body"])
        assert body["message"] == "I'm a teapot"
