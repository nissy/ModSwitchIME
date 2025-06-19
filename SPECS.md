# ModSwitchIME Project Specifications

## Project Status (2025-06-19 - Evening Update)

### Build Status
- ✅ Build successful (`make dev` passes with ad-hoc signing)
- ✅ Development build working without code signing issues
- ⚠️  Test execution requires proper code signing

### Test Status
- ⚠️  Test execution fails due to code signing requirements
- Tests themselves are properly structured but cannot run in ad-hoc signed environment

### Implementation Status
- ✅ Core functionality implemented and working
- ✅ Menu bar application structure
- ✅ Key monitoring with CGEventTap
- ✅ IME switching logic
- ✅ Preferences management with singleton pattern
- ✅ SwiftUI preferences window
- ✅ Logging system
- ✅ Real-time preference updates (no restart required)
- ✅ Accessibility permission detection on menu click

### Recent Changes (2025-06-19 Evening)

1. **Removed Automatic Permission Detection Timer**
   - Removed `permissionCheckTimer` and related automatic detection code
   - Permission check now only happens when menu bar icon is clicked
   - Kept the `menuNeedsUpdate` delegate method for menu-based detection

2. **Improved Permission Detection Flow**
   - App checks permission on startup (without prompt)
   - If permission granted later, detected when menu is opened
   - Automatically starts KeyMonitor when permission detected
   - Shows checkmark (✓) icon briefly when permission is granted

3. **Debug Menu Conditional Compilation**
   - Debug Info menu item now only appears in DEBUG builds
   - Uses `#if DEBUG` preprocessor directive

### Current Features

1. **Accessibility Permission Handling**
   - Initial check on app startup (no prompt)
   - Menu-based detection when clicking menu bar icon
   - Automatic KeyMonitor start when permission granted
   - Visual feedback with checkmark icon

2. **Real-time Preference Updates**
   - Auto Switch on Idle: Changes apply immediately
   - Wait Before Switching: Changes apply immediately
   - Modifier key assignments: Changes apply immediately
   - No app restart required for any preference changes

3. **Development Workflow**
   - `make dev`: Build with ad-hoc signing
   - `make dev-install`: Install to /Applications (retains permissions)
   - Development builds in /Applications keep accessibility permissions

### Previous Changes

1. **Implemented Singleton Pattern for Preferences**
   - Changed Preferences class to use singleton pattern
   - Fixed issue where preference changes required app restart
   - Now all components share the same Preferences instance via `Preferences.shared`

2. **Fixed Auto Switch on Idle Real-time Updates**
   - Added preference observation using Combine in KeyMonitor.swift
   - `idleOffEnabled` changes now immediately start/stop the idle timer
   - No restart required for Auto Switch on Idle toggle

3. **Confirmed Wait Before Switching Works Without Changes**
   - `cmdKeyTimeoutEnabled` already works in real-time
   - No monitoring needed as the value is checked on each key event
   - No restart required for this setting

4. **Fixed IME Detection for Multiple Languages**
   - Refactored Kotoeri-specific code to generic parent-child IME detection
   - Added support for Chinese, Korean, and other language IMEs
   - Implemented `isChildIME()` and `getParentIMEId()` helper functions

5. **Simplified IME Filtering**
   - Changed to use `TISCreateInputSourceList(nil, false)` directly
   - This returns only IMEs enabled in System Preferences
   - Removed complex filtering logic

### Resolved Issues
1. ✅ **Preference changes required app restart** (Fixed 2025-06-19)
   - Issue: Changes in preferences were not applied in real-time
   - Root cause: Each component had its own Preferences instance
   - Solution: Implemented singleton pattern with Preferences.shared

2. ✅ **IME list showed disabled IMEs** (Fixed 2025-06-19)
   - Issue: IMEs not enabled in System Preferences appeared in the list
   - Root cause: Using TISCreateInputSourceList with includeAllInstalled=true
   - Solution: Changed to use includeAllInstalled=false

3. ✅ **Only supported Japanese (Kotoeri)** (Fixed 2025-06-19)
   - Issue: Code was hardcoded for Kotoeri Japanese input
   - Root cause: Specific string matching for Kotoeri modes
   - Solution: Implemented generic parent-child IME detection

4. ✅ **Auto Switch on Idle not updating in real-time** (Fixed 2025-06-19)
   - Issue: Idle timer settings weren't applied immediately
   - Root cause: Missing preference observation in KeyMonitor
   - Solution: Added Combine-based preference observation for idleOffEnabled and idleTimeout

5. ✅ **Development requires accessibility permissions on every build** (Fixed 2025-06-19)
   - Issue: Each build creates a new unsigned app requiring new permissions
   - Root cause: Lack of consistent code signing
   - Solution: Added `make dev-install` target and instructions for installing to /Applications

6. ✅ **Automatic permission detection with timer** (Fixed 2025-06-19)
   - Issue: User didn't want automatic detection running in background
   - Root cause: Timer checking permissions every second
   - Solution: Removed timer, kept only menu-based detection

### Known Issues
1. Tests cannot run with ad-hoc signing due to code signing requirements
2. Production builds require proper Apple Developer account and team ID

### Next Steps
- Set up proper code signing for test execution
- Prepare for Mac App Store submission with proper certificates
- Consider adding unit tests that can run without full app signing