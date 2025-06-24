#!/bin/bash

# update_version.sh
# Update version numbers in Version.xcconfig

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VERSION_CONFIG="ModSwitchIME/Config/Version.xcconfig"

# Function to display usage
usage() {
    echo "Usage: $0 <version> [build_number]"
    echo ""
    echo "Examples:"
    echo "  $0 1.0.3          # Update marketing version to 1.0.3"
    echo "  $0 1.0.3 42       # Update marketing version to 1.0.3 and build number to 42"
    echo "  $0 --build-only   # Increment build number only"
    echo ""
    exit 1
}

# Function to validate version format
validate_version() {
    if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid version format. Expected: X.Y.Z (e.g., 1.0.3)${NC}"
        exit 1
    fi
}

# Function to get current values
get_current_version() {
    grep "^MARKETING_VERSION" "$VERSION_CONFIG" | cut -d'=' -f2 | xargs
}

get_current_build() {
    grep "^CURRENT_PROJECT_VERSION" "$VERSION_CONFIG" | cut -d'=' -f2 | xargs
}

# Check if config file exists
if [ ! -f "$VERSION_CONFIG" ]; then
    echo -e "${RED}Error: Version config file not found at $VERSION_CONFIG${NC}"
    exit 1
fi

# Parse arguments
if [ $# -eq 0 ]; then
    usage
fi

CURRENT_VERSION=$(get_current_version)
CURRENT_BUILD=$(get_current_build)

echo -e "${BLUE}Current version: ${CURRENT_VERSION} (${CURRENT_BUILD})${NC}"

if [ "$1" == "--build-only" ]; then
    # Increment build number only
    NEW_VERSION=$CURRENT_VERSION
    NEW_BUILD=$((CURRENT_BUILD + 1))
    echo -e "${YELLOW}Incrementing build number to ${NEW_BUILD}${NC}"
elif [ $# -eq 1 ]; then
    # Update version, increment build
    NEW_VERSION=$1
    validate_version "$NEW_VERSION"
    
    if [ "$NEW_VERSION" == "$CURRENT_VERSION" ]; then
        NEW_BUILD=$((CURRENT_BUILD + 1))
        echo -e "${YELLOW}Same version, incrementing build number to ${NEW_BUILD}${NC}"
    else
        NEW_BUILD=1
        echo -e "${YELLOW}New version, resetting build number to 1${NC}"
    fi
elif [ $# -eq 2 ]; then
    # Update both version and build
    NEW_VERSION=$1
    NEW_BUILD=$2
    validate_version "$NEW_VERSION"
    
    if ! [[ "$NEW_BUILD" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Build number must be a positive integer${NC}"
        exit 1
    fi
else
    usage
fi

# Update the config file
echo -e "${BLUE}Updating version configuration...${NC}"

# Create backup
cp "$VERSION_CONFIG" "${VERSION_CONFIG}.bak"

# Update values
sed -i '' "s/^MARKETING_VERSION = .*/MARKETING_VERSION = ${NEW_VERSION}/" "$VERSION_CONFIG"
sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${NEW_BUILD}/" "$VERSION_CONFIG"

echo -e "${GREEN}✓ Updated to version ${NEW_VERSION} (${NEW_BUILD})${NC}"

# Show the changes
echo -e "\n${BLUE}Updated configuration:${NC}"
grep -E "^(MARKETING_VERSION|CURRENT_PROJECT_VERSION)" "$VERSION_CONFIG"

# Update VERSION file if it exists
if [ -f "VERSION" ]; then
    echo "$NEW_VERSION" > VERSION
    echo -e "\n${GREEN}✓ Updated VERSION file${NC}"
fi

# Suggest next steps
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Open Xcode and verify the project configuration is using the xcconfig files"
echo "2. Build the project to apply the new version"
echo "3. Commit the changes: git add -A && git commit -m \"Bump version to ${NEW_VERSION} (${NEW_BUILD})\""

# Clean up backup
rm -f "${VERSION_CONFIG}.bak"