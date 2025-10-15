#!/bin/bash

# Smart Upload Script - Handles build number collisions automatically
# This script will increment build number and retry if needed

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🤖 Smart Upload - Build, Test & Upload Pipeline${NC}"
echo -e "${BLUE}=============================================${NC}"

# Step 1: Run tests first
echo -e "${YELLOW}🧪 Step 1: Running tests...${NC}"
if ./scripts/test.sh; then
    echo -e "${GREEN}✅ Tests passed${NC}"
else
    echo -e "${RED}❌ Tests failed! Please fix tests before uploading.${NC}"
    exit 1
fi

# Step 2: Build archive
echo -e "${YELLOW}🔨 Step 2: Building archive...${NC}"
if ./scripts/build.sh; then
    echo -e "${GREEN}✅ Archive built successfully${NC}"
else
    echo -e "${RED}❌ Build failed! Please fix build errors.${NC}"
    exit 1
fi

# Step 3: Attempt upload with automatic retry on build number collision
echo -e "${YELLOW}☁️ Step 3: Uploading to TestFlight...${NC}"

MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if [ $RETRY_COUNT -gt 0 ]; then
        echo -e "${YELLOW}🔄 Retry attempt $RETRY_COUNT of $MAX_RETRIES${NC}"
    fi
    
    # Try upload
    if ./scripts/upload.sh 2>&1 | tee /tmp/upload_output.log; then
        echo -e "${GREEN}🎉 Upload successful!${NC}"
        rm -f /tmp/upload_output.log
        exit 0
    else
        # Check if it's a build number collision
        if grep -q "bundle version must be higher than the previously uploaded version" /tmp/upload_output.log; then
            echo -e "${YELLOW}🔢 Build number collision detected. Auto-incrementing...${NC}"
            
            # Increment build number
            ./scripts/update_version.sh --increment-build
            
            # Rebuild with new build number
            echo -e "${YELLOW}🔨 Rebuilding with new build number...${NC}"
            ./scripts/build.sh
            
            RETRY_COUNT=$((RETRY_COUNT + 1))
        else
            echo -e "${RED}❌ Upload failed for reasons other than build number collision${NC}"
            echo -e "${YELLOW}Check the error output above for details${NC}"
            rm -f /tmp/upload_output.log
            exit 1
        fi
    fi
done

echo -e "${RED}❌ Failed to upload after $MAX_RETRIES retries${NC}"
rm -f /tmp/upload_output.log
exit 1