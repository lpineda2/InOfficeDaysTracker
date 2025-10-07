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

# Get current version info (now validated as synchronized)
MARKETING_VERSION=$(defaults read "$(pwd)/InOfficeDaysTracker/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.7.0")
BUILD_NUMBER=$(grep -m 1 "CURRENT_PROJECT_VERSION = " InOfficeDaysTracker.xcodeproj/project.pbxproj | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/' | tr -d ' ')

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

echo -e "${YELLOW}📤 Exporting and uploading to TestFlight...${NC}"
echo -e "${BLUE}This may take several minutes...${NC}"

# Clean previous exports
rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"

# Export and upload to TestFlight in one step
# The exportOptionsTestFlight.plist has destination=upload, so this automatically uploads
if xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates \
    -quiet; then
    
    echo -e "${GREEN}🎉 Upload successful!${NC}"
    echo -e "${BLUE}📱 Build ${BUILD_NUMBER} uploaded to TestFlight${NC}"
    echo -e "${YELLOW}⏱️  Processing may take 5-15 minutes on Apple's servers${NC}"
    echo -e "${BLUE}🔗 Check App Store Connect for status updates${NC}"
    
    # Check if IPA file was created (optional - mainly for logging)
    IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" | head -n 1)
    if [ -n "$IPA_FILE" ]; then
        echo -e "${BLUE}📱 IPA Location: $IPA_FILE${NC}"
    fi
    
else
    echo -e "${RED}❌ Upload failed! Check the logs above.${NC}"
    echo -e "${YELLOW}💡 Make sure you have set up App-Specific Password in Keychain${NC}"
    echo -e "${YELLOW}💡 Or configure API Key authentication${NC}"
    exit 1
fi