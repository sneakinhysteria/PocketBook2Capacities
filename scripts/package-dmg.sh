#!/bin/bash
set -e

# Configuration
APP_NAME="PocketBook2Capacities"
BUNDLE_ID="com.pocketbook2capacities.app"
VERSION="1.0.0"

# Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
# Universal binary build puts products in apple/Products/Release
RELEASE_DIR="$BUILD_DIR/apple/Products/Release"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_DIR="$BUILD_DIR/dmg"
DMG_PATH="$PROJECT_DIR/$APP_NAME-$VERSION.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building $APP_NAME v$VERSION${NC}"
echo "============================================"

# Step 1: Build release
echo -e "\n${YELLOW}Step 1: Building release...${NC}"
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64 --disable-sandbox

# Step 2: Create app bundle structure
echo -e "\n${YELLOW}Step 2: Creating app bundle...${NC}"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Step 3: Copy executable
echo -e "\n${YELLOW}Step 3: Copying executable...${NC}"
cp "$RELEASE_DIR/PocketBook2CapacitiesApp" "$BUNDLE_DIR/Contents/MacOS/"

# Step 4: Copy Info.plist
echo -e "\n${YELLOW}Step 4: Copying Info.plist...${NC}"
cp "$SCRIPT_DIR/Info.plist" "$BUNDLE_DIR/Contents/"

# Step 5: Create PkgInfo
echo -e "\n${YELLOW}Step 5: Creating PkgInfo...${NC}"
echo -n "APPL????" > "$BUNDLE_DIR/Contents/PkgInfo"

# Step 5b: Copy icon
echo -e "\n${YELLOW}Step 5b: Copying app icon...${NC}"
if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/"
    echo "Icon copied successfully"
else
    echo -e "${YELLOW}Warning: AppIcon.icns not found${NC}"
fi

# Step 6: Code signing (optional)
echo -e "\n${YELLOW}Step 6: Code signing...${NC}"
DEVELOPER_ID="${DEVELOPER_ID:-}"

if [ -n "$DEVELOPER_ID" ]; then
    echo "Signing with: $DEVELOPER_ID"
    codesign --force --options runtime --sign "$DEVELOPER_ID" "$BUNDLE_DIR"
    echo -e "${GREEN}App signed successfully${NC}"
else
    echo -e "${YELLOW}No DEVELOPER_ID set. Skipping code signing.${NC}"
    echo "To sign, run: DEVELOPER_ID='Developer ID Application: Your Name' $0"
    # Ad-hoc sign for local testing
    codesign --force --sign - "$BUNDLE_DIR"
    echo "Ad-hoc signed for local testing"
fi

# Step 7: Create DMG
echo -e "\n${YELLOW}Step 7: Creating DMG...${NC}"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$BUNDLE_DIR" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Remove old DMG if exists
rm -f "$DMG_PATH"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# Cleanup
rm -rf "$DMG_DIR"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "App bundle: $BUNDLE_DIR"
echo "DMG file:   $DMG_PATH"
echo ""

# Notarization instructions
if [ -n "$DEVELOPER_ID" ]; then
    echo -e "${YELLOW}To notarize the DMG:${NC}"
    echo "  xcrun notarytool submit \"$DMG_PATH\" --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID --password YOUR_APP_PASSWORD --wait"
    echo "  xcrun stapler staple \"$DMG_PATH\""
fi
