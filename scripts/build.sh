#!/bin/bash

# InOfficeDaysTracker - Build and Archive Automation Script
# Creates production archive and exports IPA for TestFlight

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

# Validate version synchronization before building
echo -e "${YELLOW}🔍 Pre-build version validation...${NC}"
./scripts/update_version.sh --validate || {
    echo -e "${RED}❌ Version mismatch detected! Fix with: ./scripts/update_version.sh --validate${NC}"
    echo -e "${YELLOW}💡 This prevents ITMS-90473 CFBundleShortVersionString mismatch errors${NC}"
    exit 1
}

# Get current version info (now validated as synchronized)
MARKETING_VERSION=$(defaults read "$(pwd)/InOfficeDaysTracker/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.6.0")
BUILD_NUMBER=$(grep -m 1 "CURRENT_PROJECT_VERSION = " InOfficeDaysTracker.xcodeproj/project.pbxproj | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/' | tr -d ' ')

# Paths
BUILD_DIR="./build"
ARCHIVE_NAME="${PROJECT_NAME}-v${MARKETING_VERSION}-build${BUILD_NUMBER}"
ARCHIVE_PATH="${BUILD_DIR}/${ARCHIVE_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export-build${BUILD_NUMBER}"
EXPORT_OPTIONS="./exportOptions.plist"

echo -e "${BLUE}🔨 Starting build process for ${PROJECT_NAME}...${NC}"
echo -e "  Version: ${GREEN}${MARKETING_VERSION}${NC}"
echo -e "  Build: ${GREEN}${BUILD_NUMBER}${NC}"

# Set environment variables to prevent physical device interference during build
export XCODE_DISABLE_DEVICE_DISCOVERY=YES
export SIMULATOR_ONLY=YES

# Create build directory
mkdir -p "$BUILD_DIR"

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
xcodebuild clean \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -quiet

# Create archive
echo -e "${YELLOW}📦 Creating archive...${NC}"
# Disable device discovery at the environment level
SKIP_INSTALL=NO \
ENABLE_BITCODE=NO \
xcodebuild archive \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -skipUnavailableActions \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -quiet || {
    echo -e "${RED}❌ Archive creation failed!${NC}"
    exit 1
}

echo -e "${GREEN}✅ Archive created successfully!${NC}"

# Verify archive exists
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}❌ Archive not found at $ARCHIVE_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}📤 Exporting IPA...${NC}"

# Export IPA
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates \
    -quiet || {
    echo -e "${RED}❌ IPA export failed!${NC}"
    exit 1
}

# Find the IPA file
IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" | head -n 1)

if [ -z "$IPA_FILE" ]; then
    echo -e "${RED}❌ IPA file not found in export directory${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IPA exported successfully!${NC}"
echo -e "${BLUE}📱 IPA Location: ${GREEN}$IPA_FILE${NC}"

# Show file size
IPA_SIZE=$(ls -lh "$IPA_FILE" | awk '{print $5}')
echo -e "${BLUE}📊 IPA Size: ${GREEN}$IPA_SIZE${NC}"

echo -e "${GREEN}🎉 Build process complete!${NC}"
echo -e "${BLUE}📁 Archive: ${GREEN}$ARCHIVE_PATH${NC}"
echo -e "${BLUE}📱 IPA: ${GREEN}$IPA_FILE${NC}"