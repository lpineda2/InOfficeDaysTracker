#!/bin/bash

# InOfficeDaysTracker - Setup Script for TestFlight Automation
# Sets up App-Specific Password for automated TestFlight uploads

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🔧 InOfficeDaysTracker - TestFlight Automation Setup${NC}"
echo -e "${BLUE}===================================================${NC}"

echo -e "${YELLOW}This script will help you set up automated TestFlight uploads.${NC}"
echo ""

# Step 1: App-Specific Password
echo -e "${BLUE}Step 1: App-Specific Password Setup${NC}"
echo -e "${YELLOW}You need to create an App-Specific Password for TestFlight uploads.${NC}"
echo ""
echo -e "${BLUE}1. Go to: ${GREEN}https://appleid.apple.com${NC}"
echo -e "${BLUE}2. Sign in with your Apple ID: ${GREEN}lpineda2@gmail.com${NC}"
echo -e "${BLUE}3. Go to 'Sign-In and Security' → 'App-Specific Passwords'${NC}"
echo -e "${BLUE}4. Generate a new password with label: ${GREEN}InOfficeDaysTracker${NC}"
echo -e "${BLUE}5. Copy the generated password (format: xxxx-xxxx-xxxx-xxxx)${NC}"
echo ""

read -p "Press Enter when you have your App-Specific Password ready..."

echo ""
echo -e "${YELLOW}Now we'll store the password securely in your macOS Keychain.${NC}"
echo -e "${BLUE}Enter your App-Specific Password when prompted:${NC}"

# Store the password in keychain
xcrun altool --store-password-in-keychain-item "ALT_PASSWORD" \
             -u "lpineda2@gmail.com" \
             -p "@env:APP_SPECIFIC_PASSWORD" || {
    echo -e "${RED}❌ Failed to store password in keychain${NC}"
    echo -e "${YELLOW}💡 You can run this command manually:${NC}"
    echo -e "${BLUE}xcrun altool --store-password-in-keychain-item \"ALT_PASSWORD\" -u \"lpineda2@gmail.com\" -p \"your-app-specific-password\"${NC}"
    exit 1
}

echo -e "${GREEN}✅ App-Specific Password stored successfully!${NC}"

# Step 2: Test the setup
echo ""
echo -e "${BLUE}Step 2: Testing the Setup${NC}"
echo -e "${YELLOW}Let's test if the automation is working correctly...${NC}"

echo -e "${BLUE}Running test suite...${NC}"
./scripts/test.sh || {
    echo -e "${RED}❌ Tests failed! Please fix any issues before proceeding.${NC}"
    exit 1
}

echo -e "${GREEN}✅ All tests passed!${NC}"

# Step 3: Ready to use
echo ""
echo -e "${PURPLE}🎉 Setup Complete! 🎉${NC}"
echo -e "${GREEN}Your TestFlight automation is now ready to use!${NC}"

echo ""
echo -e "${BLUE}Available Commands:${NC}"
echo -e "${GREEN}./scripts/test.sh${NC}          - Run unit tests"
echo -e "${GREEN}./scripts/build.sh${NC}         - Build and create archive"
echo -e "${GREEN}./scripts/upload.sh${NC}        - Upload to TestFlight"
echo -e "${GREEN}./scripts/release.sh${NC}       - Full pipeline (test → build → upload)"
echo -e "${GREEN}./scripts/release.sh -i${NC}    - Full pipeline with build increment"

echo ""
echo -e "${BLUE}VS Code Integration:${NC}"
echo -e "Press ${YELLOW}Cmd+Shift+P${NC} → Search for ${YELLOW}Tasks: Run Task${NC}"
echo -e "- ${GREEN}🚀 Full Release Pipeline${NC}"
echo -e "- ${GREEN}📈 Release with Version Increment${NC}"
echo -e "- ${GREEN}🧪 Run Tests${NC}"
echo -e "- ${GREEN}🔨 Build Archive${NC}"

echo ""
echo -e "${PURPLE}Next Steps:${NC}"
echo -e "${BLUE}1. Try running: ${GREEN}./scripts/release.sh${NC}"
echo -e "${BLUE}2. This will test → build → upload your current version${NC}"
echo -e "${BLUE}3. Monitor App Store Connect for processing status${NC}"
echo -e "${BLUE}4. Use ${GREEN}./scripts/release.sh -i${NC} for future releases to auto-increment build numbers${NC}"

echo ""
echo -e "${YELLOW}💡 Pro Tip: The full pipeline takes ~5-10 minutes but runs everything automatically!${NC}"