#!/bin/bash

# InOfficeDaysTracker - Version Update Script
# Ensures version synchronization across all targets to prevent ITMS-90473 mismatch errors

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
PROJECT_FILE="InOfficeDaysTracker.xcodeproj/project.pbxproj"
MAIN_APP_PLIST="InOfficeDaysTracker/Info.plist"
WIDGET_PLIST="OfficeTrackerWidget/Info.plist"

echo -e "${PURPLE}🔄 Version Synchronization Script${NC}"
echo -e "${BLUE}==================================${NC}"

# Function to show usage
show_usage() {
    echo -e "${YELLOW}Usage: $0 <marketing_version> <build_number>${NC}"
    echo -e "${YELLOW}       $0 --increment-build${NC}"
    echo -e "${YELLOW}       $0 --validate${NC}"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 1.7.0 4           Set version to 1.7.0 build 4"
    echo -e "  $0 --increment-build  Increment build number, keep version"
    echo -e "  $0 --validate         Check for version mismatches"
    echo ""
    echo -e "${BLUE}This script ensures version synchronization across:${NC}"
    echo -e "  • Project file MARKETING_VERSION settings"
    echo -e "  • Project file CURRENT_PROJECT_VERSION settings" 
    echo -e "  • Main app Info.plist"
    echo -e "  • Widget extension Info.plist"
}

# Function to get current marketing version from project file
get_current_marketing_version() {
    grep -m 1 "MARKETING_VERSION = " "$PROJECT_FILE" | sed 's/.*MARKETING_VERSION = \(.*\);/\1/' | tr -d ' '
}

# Function to get current build version from project file
get_current_build_version() {
    grep -m 1 "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/' | tr -d ' '
}

# Function to validate version consistency
validate_versions() {
    echo -e "${YELLOW}🔍 Validating version consistency...${NC}"
    
    # Get versions from project file
    PROJECT_MARKETING_VERSION=$(get_current_marketing_version)
    PROJECT_BUILD_VERSION=$(get_current_build_version)
    
    # Get versions from Info.plist files
    MAIN_APP_MARKETING_VERSION=$(defaults read "$(pwd)/$MAIN_APP_PLIST" CFBundleShortVersionString 2>/dev/null || echo "NOT_FOUND")
    MAIN_APP_BUILD_VERSION=$(defaults read "$(pwd)/$MAIN_APP_PLIST" CFBundleVersion 2>/dev/null || echo "NOT_FOUND")
    
    WIDGET_MARKETING_VERSION=$(defaults read "$(pwd)/$WIDGET_PLIST" CFBundleShortVersionString 2>/dev/null || echo "NOT_FOUND")
    WIDGET_BUILD_VERSION=$(defaults read "$(pwd)/$WIDGET_PLIST" CFBundleVersion 2>/dev/null || echo "NOT_FOUND")
    
    # Display current versions
    echo -e "${BLUE}📊 Current Version Status:${NC}"
    echo -e "Project File Marketing: ${GREEN}$PROJECT_MARKETING_VERSION${NC}"
    echo -e "Project File Build:     ${GREEN}$PROJECT_BUILD_VERSION${NC}"
    echo -e "Main App Marketing:     ${GREEN}$MAIN_APP_MARKETING_VERSION${NC}"
    echo -e "Main App Build:         ${GREEN}$MAIN_APP_BUILD_VERSION${NC}"
    echo -e "Widget Marketing:       ${GREEN}$WIDGET_MARKETING_VERSION${NC}"
    echo -e "Widget Build:           ${GREEN}$WIDGET_BUILD_VERSION${NC}"
    
    # Check for mismatches
    MISMATCH_FOUND=false
    
    if [ "$PROJECT_MARKETING_VERSION" != "$MAIN_APP_MARKETING_VERSION" ] || [ "$PROJECT_MARKETING_VERSION" != "$WIDGET_MARKETING_VERSION" ]; then
        echo -e "${RED}❌ Marketing version mismatch detected!${NC}"
        MISMATCH_FOUND=true
    fi
    
    if [ "$PROJECT_BUILD_VERSION" != "$MAIN_APP_BUILD_VERSION" ] || [ "$PROJECT_BUILD_VERSION" != "$WIDGET_BUILD_VERSION" ]; then
        echo -e "${RED}❌ Build version mismatch detected!${NC}"
        MISMATCH_FOUND=true
    fi
    
    if [ "$MISMATCH_FOUND" = true ]; then
        echo -e "${YELLOW}💡 Run this script with proper version numbers to fix mismatches${NC}"
        return 1
    else
        echo -e "${GREEN}✅ All versions are synchronized${NC}"
        return 0
    fi
}

# Function to update all version references
update_versions() {
    local MARKETING_VERSION=$1
    local BUILD_VERSION=$2
    
    echo -e "${YELLOW}🔄 Updating all version references...${NC}"
    
    # Update project file MARKETING_VERSION (all occurrences)
    echo -e "${BLUE}  📝 Updating project MARKETING_VERSION...${NC}"
    sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $MARKETING_VERSION;/g" "$PROJECT_FILE"
    
    # Update project file CURRENT_PROJECT_VERSION (all occurrences)
    echo -e "${BLUE}  📝 Updating project CURRENT_PROJECT_VERSION...${NC}"
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $BUILD_VERSION;/g" "$PROJECT_FILE"
    
    # Update main app Info.plist
    echo -e "${BLUE}  📝 Updating main app Info.plist...${NC}"
    defaults write "$(pwd)/$MAIN_APP_PLIST" CFBundleShortVersionString "$MARKETING_VERSION"
    defaults write "$(pwd)/$MAIN_APP_PLIST" CFBundleVersion "$BUILD_VERSION"
    
    # Update widget Info.plist
    echo -e "${BLUE}  📝 Updating widget Info.plist...${NC}"
    defaults write "$(pwd)/$WIDGET_PLIST" CFBundleShortVersionString "$MARKETING_VERSION"
    defaults write "$(pwd)/$WIDGET_PLIST" CFBundleVersion "$BUILD_VERSION"
    
    # Convert plists back to XML format (defaults writes in binary format)
    plutil -convert xml1 "$MAIN_APP_PLIST"
    plutil -convert xml1 "$WIDGET_PLIST"
    
    echo -e "${GREEN}✅ All versions updated to $MARKETING_VERSION (Build $BUILD_VERSION)${NC}"
    
    # Validate the update
    validate_versions
}

# Function to increment build number
increment_build() {
    local CURRENT_MARKETING_VERSION=$(get_current_marketing_version)
    local CURRENT_BUILD_VERSION=$(get_current_build_version)
    local NEW_BUILD_VERSION=$((CURRENT_BUILD_VERSION + 1))
    
    echo -e "${YELLOW}📈 Incrementing build number from $CURRENT_BUILD_VERSION to $NEW_BUILD_VERSION${NC}"
    update_versions "$CURRENT_MARKETING_VERSION" "$NEW_BUILD_VERSION"
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 1
elif [ $# -eq 1 ]; then
    case $1 in
        --increment-build)
            increment_build
            exit 0
            ;;
        --validate)
            validate_versions
            exit $?
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid argument: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
elif [ $# -eq 2 ]; then
    MARKETING_VERSION=$1
    BUILD_VERSION=$2
    
    # Validate version format (basic check)
    if [[ ! $MARKETING_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}❌ Invalid marketing version format. Use X.Y.Z (e.g., 1.7.0)${NC}"
        exit 1
    fi
    
    if [[ ! $BUILD_VERSION =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ Invalid build version format. Use integer (e.g., 4)${NC}"
        exit 1
    fi
    
    update_versions "$MARKETING_VERSION" "$BUILD_VERSION"
else
    echo -e "${RED}❌ Invalid number of arguments${NC}"
    show_usage
    exit 1
fi

echo -e "${PURPLE}🎉 Version synchronization complete!${NC}"