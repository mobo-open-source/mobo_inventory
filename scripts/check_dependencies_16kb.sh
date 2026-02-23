#!/bin/bash

# Script to check if dependencies support 16 KB page sizes
# This helps identify potential compatibility issues

echo "=========================================="
echo "16 KB Dependency Compatibility Checker"
echo "=========================================="
echo ""

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

cd "$(dirname "$0")/.."

echo "Checking pubspec.yaml dependencies..."
echo ""

# List of dependencies from pubspec.yaml
echo -e "${GREEN}Flutter Dependencies:${NC}"
grep -A 100 "dependencies:" pubspec.yaml | grep -v "^dev_dependencies:" | grep ":" | grep -v "sdk:" | grep -v "dependencies:" | while read -r line; do
    echo "  - $line"
done

echo ""
echo -e "${YELLOW}Recommendations:${NC}"
echo "1. Keep all dependencies up to date"
echo "2. Check release notes for 16 KB compatibility mentions"
echo "3. Test thoroughly on 16 KB devices"
echo ""

# Check for native plugins
echo "Checking for plugins with native code..."
echo ""

PLUGINS_WITH_NATIVE=(
    "image_picker"
    "mobile_scanner"
    "permission_handler"
    "shared_preferences"
    "speech_to_text"
    "webview_flutter"
)

echo -e "${GREEN}Plugins with native code in your project:${NC}"
for plugin in "${PLUGINS_WITH_NATIVE[@]}"; do
    if grep -q "$plugin:" pubspec.yaml; then
        VERSION=$(grep "$plugin:" pubspec.yaml | awk '{print $2}')
        echo "  ✓ $plugin: $VERSION"
    fi
done

echo ""
echo -e "${YELLOW}Action Items:${NC}"
echo "1. Verify these plugins are on their latest versions"
echo "2. Check each plugin's changelog for 16 KB support"
echo "3. Run: flutter pub upgrade --major-versions"
echo "4. Test the app on a 16 KB device after updating"
echo ""

# Check AGP version
echo "Checking Android Gradle Plugin version..."
if [ -f "android/settings.gradle.kts" ]; then
    AGP_VERSION=$(grep "com.android.application" android/settings.gradle.kts | grep -oP 'version "\K[^"]+')
    if [ -n "$AGP_VERSION" ]; then
        echo -e "${GREEN}✓ AGP Version: $AGP_VERSION${NC}"
        
        # Compare version (basic comparison)
        MAJOR=$(echo "$AGP_VERSION" | cut -d. -f1)
        MINOR=$(echo "$AGP_VERSION" | cut -d. -f2)
        
        if [ "$MAJOR" -gt 8 ] || ([ "$MAJOR" -eq 8 ] && [ "$MINOR" -ge 5 ]); then
            echo -e "${GREEN}✓ AGP version supports 16 KB page sizes${NC}"
        else
            echo -e "${YELLOW}⚠ AGP version should be 8.5.1 or higher${NC}"
        fi
    fi
fi

echo ""
echo "=========================================="
echo "Check complete!"
echo "=========================================="
