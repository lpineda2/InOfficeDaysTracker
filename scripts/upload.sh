#!/bin/bash

# InOfficeDaysTracker - TestFlight Upload Automation Script
# Uploads IPA to TestFlight with automatic version management

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
TEAM_ID="5G586TFR2Y"

# Get current version info
MARKETING_VERSION=$(defaults read "$(pwd)/InOfficeDaysTracker/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.6.0")
BUILD_NUMBER=$(agvtool what-version -terse)

# Paths
BUILD_DIR="./build"
ARCHIVE_NAME="${PROJECT_NAME}-v${MARKETING_VERSION}-build${BUILD_NUMBER}"
ARCHIVE_PATH="${BUILD_DIR}/${ARCHIVE_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/testflight-export-build${BUILD_NUMBER}"
EXPORT_OPTIONS="./exportOptionsTestFlight.plist"

echo -e "${BLUE}🚀 Starting TestFlight upload for ${PROJECT_NAME}...${NC}"
echo -e "  Version: ${GREEN}${MARKETING_VERSION}${NC}"
echo -e "  Build: ${GREEN}${BUILD_NUMBER}${NC}"

# Check if archive exists
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}❌ Archive not found: $ARCHIVE_PATH${NC}"
    echo -e "${YELLOW}💡 Run ./scripts/build.sh first to create the archive${NC}"
    exit 1
fi

echo -e "${YELLOW}📤 Exporting for TestFlight...${NC}"

# Clean previous exports
rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"

# Export for App Store/TestFlight
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates \
    -quiet || {
    echo -e "${RED}❌ TestFlight export failed!${NC}"
    exit 1
}

# Find the IPA file
IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" | head -n 1)

if [ -z "$IPA_FILE" ]; then
    echo -e "${RED}❌ IPA file not found in export directory${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IPA exported for TestFlight!${NC}"

# Upload to TestFlight using altool
echo -e "${YELLOW}☁️ Uploading to TestFlight...${NC}"
echo -e "${BLUE}This may take several minutes...${NC}"

# Note: You'll need to set up an App-Specific Password or API Key
# For now, we'll use xcrun altool which will prompt for credentials
xcrun altool --upload-app \
    --type ios \
    --file "$IPA_FILE" \
    --username "luispineda.me@gmail.com" \
    --password "@keychain:ALT_PASSWORD" \
    --verbose || {
    echo -e "${RED}❌ Upload failed!${NC}"
    echo -e "${YELLOW}💡 Make sure you have set up App-Specific Password in Keychain${NC}"
    echo -e "${YELLOW}💡 Or configure API Key authentication${NC}"
    exit 1
}

echo -e "${GREEN}🎉 Upload successful!${NC}"
echo -e "${BLUE}📱 Build ${BUILD_NUMBER} uploaded to TestFlight${NC}"
echo -e "${YELLOW}⏱️  Processing may take 5-15 minutes on Apple's servers${NC}"
echo -e "${BLUE}🔗 Check App Store Connect for status updates${NC}"