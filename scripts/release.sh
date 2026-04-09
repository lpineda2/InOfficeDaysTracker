#!/bin/bash

# InOfficeDaysTracker - Full Release Pipeline
# Complete automation: increment version → test → build → upload to TestFlight

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

echo -e "${PURPLE}🚀 InOfficeDaysTracker - Full Release Pipeline${NC}"
echo -e "${BLUE}=======================================${NC}"

# Function to show usage
show_usage() {
    echo -e "${YELLOW}Usage: $0 [options]${NC}"
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  -i, --increment         Increment build number before release"
    echo -e "  -v, --increment-version Increment marketing version (e.g., 1.12.0 → 1.12.1)"
    echo -e "  -s, --skip-tests        Skip running unit tests"
    echo -e "  -h, --help              Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0                      Run full pipeline with current build number"
    echo -e "  $0 --increment          Increment build number and run full pipeline"
    echo -e "  $0 --increment-version  Increment minor version (for closed TestFlight trains)"
    echo -e "  $0 --skip-tests         Run pipeline without tests (not recommended)"
}

# Parse command line arguments
INCREMENT_BUILD=false
INCREMENT_VERSION=false
SKIP_TESTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--increment)
            INCREMENT_BUILD=true
            shift
            ;;
        -v|--increment-version)
            INCREMENT_VERSION=true
            shift
            ;;
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
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

# Step 1: Version Management and Synchronization
if [ "$INCREMENT_VERSION" = true ]; then
    echo -e "${YELLOW}📈 Incrementing marketing version with version synchronization...${NC}"
    ./scripts/update_version.sh --increment-version || {
        echo -e "${RED}❌ Version increment failed! Aborting release.${NC}"
        exit 1
    }
    
    # Get the new version for commit message
    NEW_VERSION=$(grep -m 1 "MARKETING_VERSION = " InOfficeDaysTracker.xcodeproj/project.pbxproj | sed 's/.*MARKETING_VERSION = \(.*\);/\1/' | tr -d ' ')
    NEW_BUILD=$(grep -m 1 "CURRENT_PROJECT_VERSION = " InOfficeDaysTracker.xcodeproj/project.pbxproj | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/' | tr -d ' ')
    
    # Commit version change
    git add -A
    git commit -m "Increment version to $NEW_VERSION build $NEW_BUILD with synchronized versions"
    echo -e "${GREEN}✅ Version change committed to git${NC}"
elif [ "$INCREMENT_BUILD" = true ]; then
    echo -e "${YELLOW}📈 Incrementing build number with version synchronization...${NC}"
    ./scripts/update_version.sh --increment-build || {
        echo -e "${RED}❌ Version increment failed! Aborting release.${NC}"
        exit 1
    }
    
    # Get the new build number for commit message
    NEW_BUILD=$(grep -m 1 "CURRENT_PROJECT_VERSION = " InOfficeDaysTracker.xcodeproj/project.pbxproj | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/' | tr -d ' ')
    
    # Commit version change
    git add -A
    git commit -m "Increment build number to $NEW_BUILD with synchronized versions"
    echo -e "${GREEN}✅ Version change committed to git${NC}"
else
    # Always validate version synchronization before proceeding
    echo -e "${YELLOW}🔍 Validating version synchronization...${NC}"
    ./scripts/update_version.sh --validate || {
        echo -e "${RED}❌ Version mismatch detected! Run with --increment to fix, or use update_version.sh${NC}"
        exit 1
    }
fi

# Get current version info (now guaranteed to be synchronized)
MARKETING_VERSION=$(defaults read "$(pwd)/InOfficeDaysTracker/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.6.0")
BUILD_NUMBER=$(grep -m 1 "CURRENT_PROJECT_VERSION = " InOfficeDaysTracker.xcodeproj/project.pbxproj | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/' | tr -d ' ')

echo -e "${BLUE}📊 Current Version Info:${NC}"
echo -e "  Marketing Version: ${GREEN}$MARKETING_VERSION${NC}"
echo -e "  Build Number: ${GREEN}$BUILD_NUMBER${NC}"

# Step 2: Testing
if [ "$SKIP_TESTS" = false ]; then
    echo -e "${YELLOW}🧪 Running automated tests (serial execution)...${NC}"
    ./scripts/test.sh || {
        echo -e "${RED}❌ Tests failed! Aborting release.${NC}"
        echo -e "${YELLOW}💡 You can skip tests with: $0 --skip-tests (not recommended)${NC}"
        exit 1
    }
else
    echo -e "${YELLOW}⚠️  Skipping tests (not recommended for production)${NC}"
fi

# Step 3: Build and Archive
echo -e "${YELLOW}🔨 Building and creating archive...${NC}"
./scripts/build.sh || {
    echo -e "${RED}❌ Build failed! Aborting release.${NC}"
    exit 1
}

# Step 4: Upload to TestFlight
echo -e "${YELLOW}☁️ Uploading to TestFlight...${NC}"
./scripts/upload.sh || {
    echo -e "${RED}❌ Upload failed! Check the logs above.${NC}"
    exit 1
}

# Step 5: Tag Release
TAG="v$MARKETING_VERSION-$BUILD_NUMBER"
echo -e "${YELLOW}🏷️  Tagging release as $TAG...${NC}"
git tag "$TAG"
git push origin "$TAG" || echo -e "${RED}⚠️  Failed to push tag to remote. Please push manually: git push origin $TAG${NC}"

# Success!
echo -e "${PURPLE}🎉 RELEASE COMPLETE! 🎉${NC}"
echo -e "${GREEN}✅ Version $MARKETING_VERSION (Build $BUILD_NUMBER) uploaded to TestFlight${NC}"
echo -e "${BLUE}🔗 Check App Store Connect for processing status${NC}"
echo -e "${YELLOW}📱 TestFlight build will be available for testing once processing completes${NC}"

# Show next steps
echo -e "${PURPLE}Next Steps:${NC}"
echo -e "${BLUE}1. Monitor App Store Connect for processing completion${NC}"
echo -e "${BLUE}2. Add release notes in App Store Connect${NC}"
echo -e "${BLUE}3. Submit for TestFlight review if needed${NC}"
echo -e "${BLUE}4. Distribute to internal/external testers${NC}"