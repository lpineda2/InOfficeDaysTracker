#!/bin/bash

# InOfficeDaysTracker - Pre-commit Hook
# Runs SwiftLint and Unit Tests before allowing a commit

set -e

echo "🔍 Running Pre-commit checks..."

# 1. SwiftLint
if which swiftlint >/dev/null; then
    echo "🧹 Running SwiftLint..."
    swiftlint
else
    echo "⚠️ SwiftLint not installed, skipping. (brew install swiftlint)"
fi

# 2. Run Tests (Fast mode - you might want to selective run tests here to be faster)
# For now, we'll run the full suite which takes ~30s
echo "🧪 Running Tests..."
./scripts/test.sh

echo "✅ Pre-commit checks passed!"
