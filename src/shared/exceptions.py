"""Custom exceptions for the Lambda handlers."""


class ItemNotFoundError(Exception):
    """Raised when an item is not found in DynamoDB."""

    def __init__(self, item_id: str) -> None:
        self.item_id = item_id
        super().__init__(f"Item not found: {item_id}")


class ValidationError(Exception):
    """Raised when input validation fails."""

    def __init__(self, message: str, details: dict | None = None) -> None:
        self.message = message
        self.details = details or {}
        super().__init__(message)
