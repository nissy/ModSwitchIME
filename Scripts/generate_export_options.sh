#!/bin/bash
# Generate ExportOptions.plist from environment variables

cat > ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>mac-application</string>
	<key>teamID</key>
	<string>${DEVELOPMENT_TEAM}</string>
	<key>uploadBitcode</key>
	<false/>
	<key>uploadSymbols</key>
	<false/>
	<key>compileBitcode</key>
	<false/>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>destination</key>
	<string>export</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>thinning</key>
	<string>&lt;none&gt;</string>
</dict>
</plist>
EOF

echo "ExportOptions.plist generated with DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM}"