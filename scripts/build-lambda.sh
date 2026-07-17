#!/usr/bin/env bash
set -euo pipefail

# Build Lambda deployment packages with dependencies
# Usage: ./scripts/build-lambda.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/.build/lambdas"
SRC_HANDLERS="$PROJECT_ROOT/src/handlers"
SRC_SHARED="$PROJECT_ROOT/src/shared"
REQUIREMENTS="$PROJECT_ROOT/requirements-lambda.txt"
DEPS_DIR="$BUILD_DIR/_deps"

echo "Building Lambda packages..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DEPS_DIR"

echo "  Installing shared dependencies..."
pip install -q -r "$REQUIREMENTS" -t "$DEPS_DIR" 2>/dev/null

HANDLERS=("list_items" "get_item" "create_item" "update_item" "delete_item")

for handler in "${HANDLERS[@]}"; do
    FUNC_DIR="$BUILD_DIR/$handler"
    mkdir -p "$FUNC_DIR"

    echo "  Packaging $handler..."
    cp -r "$DEPS_DIR"/* "$FUNC_DIR/" 2>/dev/null
    cp "$SRC_HANDLERS/${handler}.py" "$FUNC_DIR/"
    cp "$SRC_HANDLERS/__init__.py" "$FUNC_DIR/" 2>/dev/null || true

    if [ -d "$SRC_SHARED" ]; then
        mkdir -p "$FUNC_DIR/shared"
        cp "$SRC_SHARED"/*.py "$FUNC_DIR/shared/" 2>/dev/null || true
        touch "$FUNC_DIR/shared/__init__.py"
    fi

    cd "$FUNC_DIR"
    zip -qr "$BUILD_DIR/${handler}.zip" .
    cd "$PROJECT_ROOT"

    echo "  ✓ ${handler}.zip ($(du -h "$BUILD_DIR/${handler}.zip" | cut -f1))"
done

rm -rf "$DEPS_DIR"
echo ""
echo "All Lambda packages built in $BUILD_DIR/"
ls -lh "$BUILD_DIR/"*.zip
