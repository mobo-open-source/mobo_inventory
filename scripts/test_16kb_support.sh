#!/bin/bash

# 16 KB Page Size Support Testing Script
# This script helps verify that your app supports 16 KB page sizes

set -e

echo "=========================================="
echo "16 KB Page Size Support Testing Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo -e "${RED}Error: adb not found. Please install Android SDK platform tools.${NC}"
    exit 1
fi

# Check if device is connected
echo "Checking for connected devices..."
DEVICE_COUNT=$(adb devices | grep -w "device" | wc -l)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo -e "${RED}Error: No Android device connected.${NC}"
    echo "Please connect a device or start an emulator."
    exit 1
fi

echo -e "${GREEN}✓ Device connected${NC}"
echo ""

# Step 1: Check device page size
echo "Step 1: Checking device page size..."
PAGE_SIZE=$(adb shell getconf PAGE_SIZE 2>/dev/null || echo "0")

if [ "$PAGE_SIZE" == "16384" ]; then
    echo -e "${GREEN}✓ Device is using 16 KB page size${NC}"
elif [ "$PAGE_SIZE" == "4096" ]; then
    echo -e "${YELLOW}⚠ Device is using 4 KB page size${NC}"
    echo "  To test 16 KB support, you need:"
    echo "  - Android 15+ device with 16 KB mode enabled in Developer Options, or"
    echo "  - Android Emulator with 16 KB system image"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${RED}✗ Could not determine page size (got: $PAGE_SIZE)${NC}"
    exit 1
fi

echo ""

# Step 2: Build the app
echo "Step 2: Building APK..."
cd "$(dirname "$0")/.."

if ! flutter build apk --release; then
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ APK built successfully${NC}"
echo ""

# Step 3: Find the APK
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

if [ ! -f "$APK_PATH" ]; then
    echo -e "${RED}✗ APK not found at $APK_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ APK found: $APK_PATH${NC}"
echo ""

# Step 4: Check APK alignment
echo "Step 3: Checking APK 16 KB alignment..."

# Try to find zipalign
ZIPALIGN=""
if command -v zipalign &> /dev/null; then
    ZIPALIGN="zipalign"
elif [ -n "$ANDROID_HOME" ]; then
    # Find the latest build-tools version
    BUILD_TOOLS_DIR="$ANDROID_HOME/build-tools"
    if [ -d "$BUILD_TOOLS_DIR" ]; then
        LATEST_VERSION=$(ls -v "$BUILD_TOOLS_DIR" | tail -n 1)
        if [ -f "$BUILD_TOOLS_DIR/$LATEST_VERSION/zipalign" ]; then
            ZIPALIGN="$BUILD_TOOLS_DIR/$LATEST_VERSION/zipalign"
        fi
    fi
fi

if [ -z "$ZIPALIGN" ]; then
    echo -e "${YELLOW}⚠ zipalign not found. Skipping alignment check.${NC}"
    echo "  To check alignment manually, run:"
    echo "  zipalign -c -P 16 -v 4 $APK_PATH"
else
    echo "Using zipalign: $ZIPALIGN"
    if $ZIPALIGN -c -P 16 -v 4 "$APK_PATH"; then
        echo -e "${GREEN}✓ APK is properly aligned for 16 KB page sizes${NC}"
    else
        echo -e "${RED}✗ APK is NOT properly aligned for 16 KB page sizes${NC}"
        echo "  This may cause issues on 16 KB devices."
        echo "  Please check your build.gradle.kts configuration."
        exit 1
    fi
fi

echo ""

# Step 5: Install the app
echo "Step 4: Installing APK on device..."

if adb install -r "$APK_PATH"; then
    echo -e "${GREEN}✓ APK installed successfully${NC}"
else
    echo -e "${RED}✗ Installation failed${NC}"
    exit 1
fi

echo ""

# Step 6: Launch the app
echo "Step 5: Launching app..."
PACKAGE_NAME="com.cybrosys.mobo_inventory"

adb shell am start -n "$PACKAGE_NAME/.MainActivity" 2>/dev/null || {
    echo -e "${YELLOW}⚠ Could not auto-launch app${NC}"
    echo "  Please launch the app manually and test thoroughly."
}

echo ""
echo "=========================================="
echo -e "${GREEN}Testing Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Thoroughly test all app features"
echo "2. Pay special attention to:"
echo "   - App startup and initialization"
echo "   - Memory-intensive operations"
echo "   - Native library interactions"
echo "   - Camera and media operations"
echo "3. Monitor logcat for any errors:"
echo "   adb logcat | grep -i '$PACKAGE_NAME'"
echo ""
echo "If you encounter issues, refer to:"
echo "  16KB_PAGE_SIZE_SUPPORT.md"
echo ""
