#!/bin/bash

# InOfficeDaysTracker - Quick Test Validation Script
# Runs specific tests to validate functionality without full suite

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="InOfficeDaysTracker"
SCHEME="InOfficeDaysTracker"
PROJECT_FILE="${PROJECT_NAME}.xcodeproj"

echo -e "${PURPLE}🧪 Quick Test Validation for ${PROJECT_NAME}${NC}"
echo -e "${BLUE}=======================================${NC}"

# Function to show usage
show_usage() {
    echo -e "${YELLOW}Usage: $0 [options]${NC}"
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  --widget         Run only widget refresh tests"
    echo -e "  --serial         Run all tests serially (slower but more reliable)"
    echo -e "  --parallel       Run all tests in parallel (faster but may have conflicts)"
    echo -e "  --specific TEST  Run a specific test (e.g., testCurrentVisitPersistence)"
    echo -e "  -h, --help       Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 --widget                                    # Test widget functionality"
    echo -e "  $0 --serial                                    # Run all tests serially"
    echo -e "  $0 --specific testCurrentVisitPersistence      # Run specific test"
}

# Default: run widget tests
TEST_MODE="widget"
TEST_NAME=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --widget)
            TEST_MODE="widget"
            shift
            ;;
        --serial)
            TEST_MODE="serial"
            shift
            ;;
        --parallel)
            TEST_MODE="parallel"
            shift
            ;;
        --specific)
            TEST_MODE="specific"
            TEST_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Check if project exists
if [ ! -d "$PROJECT_FILE" ]; then
    echo -e "${RED}❌ Error: $PROJECT_FILE not found${NC}"
    exit 1
fi

case $TEST_MODE in
    widget)
        echo -e "${YELLOW}📱 Running Widget Refresh Tests...${NC}"
        xcodebuild test \
            -project "$PROJECT_FILE" \
            -scheme "$SCHEME" \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
            -only-testing:InOfficeDaysTrackerTests/WidgetRefreshTests \
            -parallel-testing-enabled NO || {
            echo -e "${RED}❌ Widget tests failed!${NC}"
            exit 1
        }
        echo -e "${GREEN}✅ Widget tests passed!${NC}"
        ;;
    
    serial)
        echo -e "${YELLOW}📱 Running All Tests (Serial Mode)...${NC}"
        echo -e "${BLUE}ℹ️  This prevents test interference but takes longer${NC}"
        xcodebuild test \
            -project "$PROJECT_FILE" \
            -scheme "$SCHEME" \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
            -parallel-testing-enabled NO || {
            echo -e "${RED}❌ Tests failed!${NC}"
            exit 1
        }
        echo -e "${GREEN}✅ All tests passed (serial execution)!${NC}"
        ;;
    
    parallel)
        echo -e "${YELLOW}📱 Running All Tests (Parallel Mode)...${NC}"
        echo -e "${YELLOW}⚠️  Warning: May have concurrency issues with UserDefaults${NC}"
        xcodebuild test \
            -project "$PROJECT_FILE" \
            -scheme "$SCHEME" \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro' || {
            echo -e "${RED}❌ Tests failed!${NC}"
            echo -e "${YELLOW}💡 Try: $0 --serial${NC}"
            exit 1
        }
        echo -e "${GREEN}✅ All tests passed (parallel execution)!${NC}"
        ;;
    
    specific)
        if [ -z "$TEST_NAME" ]; then
            echo -e "${RED}❌ Error: No test name provided${NC}"
            show_usage
            exit 1
        fi
        echo -e "${YELLOW}📱 Running Specific Test: $TEST_NAME${NC}"
        xcodebuild test \
            -project "$PROJECT_FILE" \
            -scheme "$SCHEME" \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
            -only-testing:InOfficeDaysTrackerTests/WidgetRefreshTests/$TEST_NAME || {
            echo -e "${RED}❌ Test failed: $TEST_NAME${NC}"
            exit 1
        }
        echo -e "${GREEN}✅ Test passed: $TEST_NAME${NC}"
        ;;
esac

# Get current version info
MARKETING_VERSION=$(defaults read "$(pwd)/InOfficeDaysTracker/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.7.0")
BUILD_NUMBER=$(grep -m 1 "CURRENT_PROJECT_VERSION = " InOfficeDaysTracker.xcodeproj/project.pbxproj | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/' | tr -d ' ')

echo -e "${BLUE}📊 Current Build Info:${NC}"
echo -e "  Version: ${GREEN}$MARKETING_VERSION${NC}"
echo -e "  Build: ${GREEN}$BUILD_NUMBER${NC}"

echo -e "${GREEN}🎉 Test validation complete!${NC}"
