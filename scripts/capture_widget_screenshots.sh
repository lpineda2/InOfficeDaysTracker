#!/bin/bash

# Widget Screenshot Capture Helper
# Run this script to open the iOS Simulator and guide you through taking screenshots

echo "📱 Widget Screenshot Capture Guide"
echo "=================================="
echo ""

# Check if iOS Simulator is available
if ! command -v xcrun &> /dev/null; then
    echo "❌ Xcode command line tools not found. Please install Xcode first."
    exit 1
fi

echo "🚀 Step-by-Step Screenshot Guide:"
echo ""
echo "1. 📱 PREPARE SIMULATOR:"
echo "   - Open iOS Simulator (iPhone 16 Pro recommended)"
echo "   - Install your InOfficeDaysTracker app"
echo "   - Ensure you have realistic data (e.g., 8 of 12 office days)"
echo ""

echo "2. 🔒 LOCK SCREEN WIDGETS:"
echo "   a) Add lock screen widgets:"
echo "      - Lock iPhone simulator (Cmd+L)"
echo "      - Long press on lock screen"
echo "      - Tap 'Customize'"
echo "      - Tap 'Lock Screen'"
echo "      - Add your app widgets"
echo ""
echo "   b) Capture screenshots:"
echo "      - Lock screen with circular widget → Save as 'lock-screen-circular.png'"
echo "      - Lock screen with rectangular widget → Save as 'lock-screen-rectangular.png'"
echo ""

echo "3. 🏠 HOME SCREEN WIDGETS:"
echo "   - Unlock simulator"
echo "   - Long press home screen"
echo "   - Tap '+' button"
echo "   - Find InOfficeDaysTracker"
echo "   - Add medium (4x2) widget"
echo "   - Screenshot → Save as 'home-screen-medium.png'"
echo ""

echo "4. 💾 SAVE SCREENSHOTS:"
echo "   Screenshots should be saved to:"
echo "   /Users/lpineda/Desktop/InOfficeDaysTracker/InOfficeDaysTracker/Assets.xcassets/"
echo ""
echo "   Replace these files:"
echo "   - lock-screen-circular.imageset/lock-screen-circular.png"
echo "   - lock-screen-rectangular.imageset/lock-screen-rectangular.png" 
echo "   - home-screen-medium.imageset/home-screen-medium.png"
echo ""

echo "5. ✅ VERIFICATION:"
echo "   - Build your app in Xcode"
echo "   - Check that WhatsNew screen shows with your screenshots"
echo ""

echo "🎯 Pro Tips:"
echo "   - Use realistic data (8/12 days, current month)"
echo "   - Capture in light mode for better visibility"
echo "   - Ensure building.2.fill and clock.badge.fill icons are visible"
echo "   - Screenshots will be automatically scaled for @2x and @3x"
echo ""

read -p "Press Enter to open iOS Simulator, or Ctrl+C to exit..."

# Open iOS Simulator
echo "🚀 Opening iOS Simulator..."
open -a Simulator

echo ""
echo "✨ Simulator opened! Follow the steps above to capture your widget screenshots."
echo ""
echo "After capturing screenshots, replace the placeholder PNG files and rebuild your app."
echo "The WhatsNew screen will automatically show your beautiful widget showcase! 🎉"