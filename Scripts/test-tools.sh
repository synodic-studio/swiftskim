#!/bin/bash
# Test script for swiftskim
# Validates that all tools are working correctly

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$PROJECT_ROOT/.build/release"

echo "🧪 Testing swiftskim"
echo ""

# Check if tools exist
echo "📋 Checking executables..."
MISSING_TOOLS=()

if [ ! -f "$TOOLS_DIR/swiftformat-smart" ]; then
    MISSING_TOOLS+=("swiftformat-smart")
fi

if [ ! -f "$TOOLS_DIR/swiftlint-smart" ]; then
    MISSING_TOOLS+=("swiftlint-smart")
fi

if [ ! -f "$TOOLS_DIR/swiftskim" ]; then
    MISSING_TOOLS+=("swiftskim")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo ""
    echo "🚨 Test Error: ExecutablesNotFound"
    echo "Problem: Missing executables: ${MISSING_TOOLS[*]}"
    echo "Context: Expected in $TOOLS_DIR"
    echo "Fix: Run './Scripts/build-all.sh' to build all tools"
    echo ""
    exit 1
fi

echo "✅ All executables found"
echo ""

# Test each tool's --help
echo "🔍 Testing tool help messages..."

echo "  Testing swiftformat-smart --help..."
if "$TOOLS_DIR/swiftformat-smart" --help > /dev/null 2>&1; then
    echo "  ✅ swiftformat-smart"
else
    echo "  ❌ swiftformat-smart --help failed"
    exit 1
fi

echo "  Testing swiftlint-smart --help..."
if "$TOOLS_DIR/swiftlint-smart" --help > /dev/null 2>&1; then
    echo "  ✅ swiftlint-smart"
else
    echo "  ❌ swiftlint-smart --help failed"
    exit 1
fi

echo "  Testing swiftskim --help..."
if "$TOOLS_DIR/swiftskim" --help > /dev/null 2>&1; then
    echo "  ✅ swiftskim"
else
    echo "  ❌ swiftskim --help failed"
    exit 1
fi

echo ""

# Check for required commands
echo "🔧 Checking required commands..."

REQUIRED_COMMANDS=("swiftformat" "swiftlint" "swift")
MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        MISSING_COMMANDS+=("$cmd")
    else
        echo "  ✅ $cmd"
    fi
done

if [ ${#MISSING_COMMANDS[@]} -ne 0 ]; then
    echo ""
    echo "⚠️  Warning: Missing commands: ${MISSING_COMMANDS[*]}"
    echo "Install missing commands:"
    for cmd in "${MISSING_COMMANDS[@]}"; do
        echo "  brew install $cmd"
    done
    echo ""
else
    echo ""
fi

# Check configs
echo "📝 Checking shared configurations..."

CONFIG_DIR="$PROJECT_ROOT/Configs"
if [ -f "$CONFIG_DIR/shared-swiftformat.yml" ]; then
    echo "  ✅ shared-swiftformat.yml"
else
    echo "  ❌ shared-swiftformat.yml not found"
    exit 1
fi

if [ -f "$CONFIG_DIR/shared-swiftlint.yml" ]; then
    echo "  ✅ shared-swiftlint.yml"
else
    echo "  ❌ shared-swiftlint.yml not found"
    exit 1
fi

echo ""

# Warnings are failures. A wrapper that merely prints a warning but exits zero
# lets quality debt pass every caller that correctly trusts the process status.
echo "🚦 Checking strict SwiftLint warning handling..."
STRICT_FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$STRICT_FIXTURE_DIR"' EXIT
cat > "$STRICT_FIXTURE_DIR/.swiftlint.yml" <<'EOF'
opt_in_rules:
  - empty_string
EOF
cat > "$STRICT_FIXTURE_DIR/Warning.swift" <<'EOF'
let value = ""
if value == "" {
    print(value)
}
EOF
if (cd "$STRICT_FIXTURE_DIR" && "$TOOLS_DIR/swiftlint-smart" Warning.swift >/dev/null 2>&1); then
    echo "  ❌ swiftlint-smart accepted a warning"
    exit 1
fi
echo "  ✅ swiftlint-smart rejects warnings"
echo ""

# Check custom rule engine
echo "🔍 Checking custom rule engine..."
RULE_ENGINE="$PROJECT_ROOT/.build/release/swiftskim-engine"

if [ -f "$RULE_ENGINE" ]; then
    echo "  ✅ Custom rule engine built"
else
    echo "  ⚠️  Custom rule engine not built (will auto-build on first use)"
fi

echo ""
echo "🎉 All tests passed!"
echo ""
echo "Tools are ready to use:"
echo "  • swiftformat-smart"
echo "  • swiftlint-smart"
echo "  • swiftskim"
echo ""
