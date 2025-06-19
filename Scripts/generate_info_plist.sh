#!/bin/bash
# Generate Info.plist from template with environment variables

# Check if template exists
if [ ! -f "ModSwitchIME/Info.plist.template" ]; then
    echo "Error: Info.plist.template not found"
    exit 1
fi

# Generate Info.plist from template
sed -e "s/\${PRODUCT_BUNDLE_IDENTIFIER}/${PRODUCT_BUNDLE_IDENTIFIER}/g" \
    -e "s/\${COPYRIGHT_HOLDER}/${COPYRIGHT_HOLDER}/g" \
    -e "s/\${COPYRIGHT_YEAR}/${COPYRIGHT_YEAR}/g" \
    -e "s/\${VERSION}/${VERSION}/g" \
    -e "s/\${BUILD_NUMBER}/${BUILD_NUMBER}/g" \
    ModSwitchIME/Info.plist.template > ModSwitchIME/Info.plist

echo "Info.plist generated with:"
echo "  Bundle ID: ${PRODUCT_BUNDLE_IDENTIFIER}"
echo "  Copyright: © ${COPYRIGHT_YEAR} ${COPYRIGHT_HOLDER}"
echo "  Version: ${VERSION} (${BUILD_NUMBER})"