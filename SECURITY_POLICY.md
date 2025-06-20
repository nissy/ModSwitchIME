# Security Policy

## Overview

ModSwitchIME is designed with privacy and security as core principles. This document outlines our security measures and what data the application can access.

## What ModSwitchIME Can Access

### ✅ Allowed Access
- **Modifier key presses only** (Command ⌘, Shift ⇧, Control ⌃, Option ⌥)
- **Input method switching** via macOS Text Input Source APIs
- **User preferences** stored locally in UserDefaults

### ❌ No Access To
- **Regular keystrokes or typing content** - The app only monitors modifier keys
- **Clipboard contents** - No clipboard access is requested or used
- **Screen contents** - No screen recording or capture
- **Network communication** - No network capabilities
- **File system** - No file system access except preferences
- **Personal data** - No collection of user data or telemetry

## Security Measures

### 1. Minimal Permissions
- Only requests Accessibility permission for modifier key detection
- Limited entitlements for input method functionality and system integration
- Event monitoring limited to `flagsChanged` events only
- Read-only file access for user-selected files (system integration)

### 2. Privacy Protection
- **No keylogging**: Regular keystrokes are never captured
- **Immediate data disposal**: Event data is cleared from memory after processing
- **No data persistence**: No logs or records of key presses are stored
- **Local processing only**: All operations happen on your Mac

### 3. Open Source Transparency
- Complete source code available for inspection
- Build instructions provided for self-compilation
- Regular security updates and community review

### 4. Code Signing & Notarization
- **Production builds**: Signed with Developer ID certificate
- **Development builds**: Ad-hoc signed for local development  
- Notarized by Apple for additional security verification (production only)
- Hardened Runtime enabled

## Accessibility Permission

ModSwitchIME requires Accessibility permission to monitor modifier key events. This permission allows the app to:
- Detect when modifier keys are pressed and released
- Distinguish between left and right modifier keys
- Measure key press duration for combination detection

You can revoke this permission at any time:
1. Open System Settings
2. Go to Privacy & Security → Accessibility
3. Uncheck ModSwitchIME

## Security Best Practices for Users

1. **Download from official sources only**
   - GitHub Releases: https://github.com/nissy/ModSwitchIME/releases
   - Verify code signature: `codesign -dv --verbose=4 /Applications/ModSwitchIME.app`
   - Production builds should show: `Authority=Developer ID Application: Yoshihiko Nishida (R7LKF73J2W)`

2. **Review permissions**
   - Only grant Accessibility permission
   - No additional permissions should be requested

3. **Monitor system resources**
   - CPU usage should be minimal (<0.1% when idle)
   - Memory usage should be under 25MB

## Reporting Security Issues

If you discover a security vulnerability, please report it responsibly:

1. **Do not** create a public GitHub issue
2. Email: [Contact repository owner via GitHub]
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Audit Trail

### Latest Security Review
- **Date**: 2025-06-20
- **Version**: 1.0.0
- **Changes**:
  - Confirmed flagsChanged-only event monitoring for enhanced privacy
  - Verified immediate event data disposal implementation
  - Enhanced user privacy notifications
  - Updated security documentation with actual implementation details
  - Verified minimal entitlements configuration

### Security Checklist
- [x] Minimal permission model
- [x] No network capabilities
- [x] No file system access beyond preferences
- [x] No data collection or telemetry
- [x] Signed and notarized builds
- [x] Open source for transparency
- [x] Regular security updates

## Privacy Compliance

ModSwitchIME is designed to comply with:
- macOS privacy guidelines
- GDPR principles (no personal data collection)
- California Consumer Privacy Act (CCPA)

## Version History

| Version | Date | Security Changes |
|---------|------|------------------|
| 1.0.0 | 2025-06-20 | Enhanced privacy protections, removed keyDown monitoring |

---

*This security policy is subject to updates. Please check the latest version in the repository.*