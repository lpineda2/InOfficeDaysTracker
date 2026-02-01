#!/bin/bash

# InOfficeDaysTracker - Test Automation Script
# Runs unit tests and validates the build before deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="InOfficeDaysTracker"
SCHEME="InOfficeDaysTracker"
PROJECT_FILE="${PROJECT_NAME}.xcodeproj"

echo -e "${BLUE}🧪 Starting automated testing for ${PROJECT_NAME}...${NC}"

# Check if project exists
if [ ! -d "$PROJECT_FILE" ]; then
    echo -e "${RED}❌ Error: $PROJECT_FILE not found${NC}"
    exit 1
fi

echo -e "${YELLOW}📱 Running unit tests (serial execution for reliability)...${NC}"

# Run tests with serial execution to prevent concurrency issues
# Allow overriding the simulator destination via SIM_DEST env var to avoid
# ambiguous-destination warnings. Defaults to iPhone 16 / iOS 18.6.
SIM_DEST="${SIM_DEST:-platform=iOS Simulator,OS=18.6,name=iPhone 16}"

echo -e "${BLUE}🎯 Running tests on simulator only: ${SIM_DEST}${NC}"

# Set environment variables to prevent physical device interference
export SIMULATOR_ONLY=YES
export XCODE_DISABLE_DEVICE_DISCOVERY=YES

# -parallel-testing-enabled NO ensures tests don't interfere with shared UserDefaults
# -destination-timeout 60 prevents hanging on device connection attempts
# -derivedDataPath ensures clean isolated test environment
# -skipUnavailableActions prevents attempting to use unavailable/locked devices
xcodebuild test \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -destination "$SIM_DEST" \
    -destination-timeout 60 \
    -parallel-testing-enabled NO \
    -derivedDataPath "./DerivedData" \
    -skipUnavailableActions \
    -quiet 2>/dev/null || {
    echo -e "${RED}❌ Tests failed!${NC}"
    echo -e "${YELLOW}💡 Tip: Run individual tests with:${NC}"
    echo -e "   xcodebuild test -scheme $SCHEME -only-testing:InOfficeDaysTrackerTests/WidgetRefreshTests"
    exit 1
}

echo -e "${GREEN}✅ All tests passed!${NC}"

echo -e "${YELLOW}🔨 Validating build for release...${NC}"

# Test build for release configuration
xcodebuild build \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -quiet || {
    echo -e "${RED}❌ Release build failed!${NC}"
    exit 1
}

echo -e "${GREEN}✅ Release build validation successful!${NC}"

# Get current version info
MARKETING_VERSION=$(defaults read "$(pwd)/InOfficeDaysTracker/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.6.0")
BUILD_NUMBER=$(agvtool what-version -terse)

echo -e "${BLUE}📊 Build Info:${NC}"
echo -e "  Marketing Version: ${GREEN}$MARKETING_VERSION${NC}"
echo -e "  Build Number: ${GREEN}$BUILD_NUMBER${NC}"

echo -e "${GREEN}🎉 Testing complete! Ready for archive and deployment.${NC}"