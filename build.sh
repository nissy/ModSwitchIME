#!/bin/bash

# ModSwitchIME Build Script
# Provides convenient wrapper for xcodebuild commands

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="ModSwitchIME"
SCHEME="ModSwitchIME"

# Load environment variables from .env if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Use environment variables with defaults
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-YOUR_TEAM_ID}"
PRODUCT_BUNDLE_IDENTIFIER="${PRODUCT_BUNDLE_IDENTIFIER:-com.example.ModSwitchIME}"

# Functions
print_usage() {
    echo -e "${BLUE}ModSwitchIME Build Script${NC}"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build         - Build debug version with code signing"
    echo "  build-release - Build release version with code signing"
    echo "  build-unsigned- Build without code signing (for development)"
    echo "  test          - Run tests"
    echo "  clean         - Clean build artifacts"
    echo "  archive       - Create archive for distribution"
    echo "  help          - Show this help"
    echo ""
    echo "Environment variables:"
    echo "  DEVELOPMENT_TEAM - Your Apple Developer Team ID (default: $DEVELOPMENT_TEAM)"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Build functions
build_debug() {
    print_header "Building $PROJECT_NAME (Debug)"
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "platform=macOS" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        PRODUCT_BUNDLE_IDENTIFIER="$PRODUCT_BUNDLE_IDENTIFIER" \
        build
    
    if [ $? -eq 0 ]; then
        print_success "Debug build completed successfully"
    else
        print_error "Debug build failed"
        exit 1
    fi
}

build_release() {
    print_header "Building $PROJECT_NAME (Release)"
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "platform=macOS" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        PRODUCT_BUNDLE_IDENTIFIER="$PRODUCT_BUNDLE_IDENTIFIER" \
        build
    
    if [ $? -eq 0 ]; then
        print_success "Release build completed successfully"
    else
        print_error "Release build failed"
        exit 1
    fi
}

build_unsigned() {
    print_header "Building $PROJECT_NAME (Unsigned)"
    print_warning "Building without code signing - for development only"
    
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "platform=macOS" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        build
    
    if [ $? -eq 0 ]; then
        print_success "Unsigned build completed successfully"
    else
        print_error "Unsigned build failed"
        exit 1
    fi
}

run_tests() {
    print_header "Running Tests"
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "platform=macOS" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        PRODUCT_BUNDLE_IDENTIFIER="$PRODUCT_BUNDLE_IDENTIFIER" \
        test
    
    if [ $? -eq 0 ]; then
        print_success "All tests passed"
    else
        print_error "Tests failed"
        exit 1
    fi
}

clean_build() {
    print_header "Cleaning Build Artifacts"
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        clean
    
    rm -rf build/
    rm -rf ~/Library/Developer/Xcode/DerivedData/$PROJECT_NAME-*
    
    print_success "Build artifacts cleaned"
}

create_archive() {
    print_header "Creating Archive"
    mkdir -p build
    
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "platform=macOS" \
        -archivePath "build/$PROJECT_NAME.xcarchive" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        PRODUCT_BUNDLE_IDENTIFIER="$PRODUCT_BUNDLE_IDENTIFIER" \
        archive
    
    if [ $? -eq 0 ]; then
        print_success "Archive created successfully"
    else
        print_error "Archive creation failed"
        exit 1
    fi
}

# Check if running in correct directory
if [ ! -f "$PROJECT_NAME.xcodeproj/project.pbxproj" ]; then
    print_error "Not in project directory. Please run from the ModSwitchIME project root."
    exit 1
fi

# Check if direnv is available and load environment
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv export bash 2>/dev/null)" || true
fi

# Parse command line arguments
case "${1:-help}" in
    "build")
        build_debug
        ;;
    "build-release")
        build_release
        ;;
    "build-unsigned")
        build_unsigned
        ;;
    "test")
        run_tests
        ;;
    "clean")
        clean_build
        ;;
    "archive")
        create_archive
        ;;
    "help"|"--help"|"-h")
        print_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        print_usage
        exit 1
        ;;
esac