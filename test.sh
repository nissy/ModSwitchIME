#!/bin/bash

# ModSwitchIME simple test script
# Since we don't have a test target configured in Xcode, 
# this script performs basic validation

echo "🧪 Running ModSwitchIME validation tests..."

# Check if the project builds
echo "📦 Building project..."
if xcodebuild -project ModSwitchIME.xcodeproj -scheme ModSwitchIME -configuration Debug -destination "platform=macOS" build > /dev/null 2>&1; then
    echo "✅ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi

# Check if required files exist
echo "📋 Checking project structure..."

files=(
    "ModSwitchIME/App.swift"
    "ModSwitchIME/MenuBarApp.swift"
    "ModSwitchIME/ImeController.swift"
    "ModSwitchIME/KeyMonitor.swift"
    "ModSwitchIME/Preferences.swift"
    "ModSwitchIME/PreferencesView.swift"
    "ModSwitchIME/Logger.swift"
)

all_exist=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file missing"
        all_exist=false
    fi
done

if [ "$all_exist" = true ]; then
    echo "✅ All required files exist"
else
    echo "❌ Some files are missing"
    exit 1
fi

# Check if the app was built
BUILD_DIR=$(xcodebuild -project ModSwitchIME.xcodeproj -scheme ModSwitchIME -showBuildSettings | grep -E '^\s*BUILT_PRODUCTS_DIR' | head -1 | awk '{print $3}')
if [ -d "$BUILD_DIR/ModSwitchIME.app" ] || [ -d "/Users/nishida/Library/Developer/Xcode/DerivedData/ModSwitchIME-*/Build/Products/Debug/ModSwitchIME.app" ]; then
    echo "✅ App bundle created"
else
    echo "⚠️  App bundle location varies by system"
    # Don't fail on this check as the build succeeded
fi

echo ""
echo "🎉 All validation tests passed!"
echo ""
echo "Note: To run proper unit tests, you need to:"
echo "1. Open ModSwitchIME.xcodeproj in Xcode"
echo "2. Select Product > Scheme > New Scheme"
echo "3. Create a new scheme for 'ModSwitchIMETests' target"
echo "4. Or use Xcode's test navigator to create a test target"