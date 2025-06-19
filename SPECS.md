# ModSwitchIME Project Specifications

## Project Status (2025-06-19)

### Build Status
- ✅ Build successful (`make build` passes)
- ✅ Unsigned build working (`make build-unsigned` passes)
- ⚠️  Code signing requires proper development team setup

### Test Status
- ⚠️  Several test failures after updating to use `Preferences.createForTesting()`
- Test failures are primarily related to:
  - Default preference values being different in test environment
  - Input source icon/language detection variations
  - Error message content assertions

### Implementation Status
- ✅ Core functionality implemented
- ✅ Menu bar application structure
- ✅ Key monitoring with CGEventTap
- ✅ IME switching logic
- ✅ Preferences management
- ✅ SwiftUI preferences window
- ✅ Logging system

### Recent Changes (2025-06-19)
1. **Implemented Singleton Pattern for Preferences**
   - Changed Preferences class to use singleton pattern
   - Fixed issue where preference changes required app restart
   - Now all components share the same Preferences instance via `Preferences.shared`

2. **Fixed IME Detection for Multiple Languages**
   - Refactored Kotoeri-specific code to generic parent-child IME detection
   - Added support for Chinese, Korean, and other language IMEs
   - Implemented `isChildIME()` and `getParentIMEId()` helper functions

3. **Simplified IME Filtering**
   - Changed to use `TISCreateInputSourceList(nil, false)` directly
   - This returns only IMEs enabled in System Preferences
   - Removed complex filtering logic

4. **Added Debug Logging for Auto Switch**
   - Added debug logs to idle timer implementation in KeyMonitor.swift
   - Logs now show when idle timer starts, stops, and checks timeout
   - Helps diagnose Auto Switch feature issues

### Previous Changes
1. **Updated all test files to use `Preferences.createForTesting()` instead of `Preferences()`**
   - Modified 8 test files:
     - KeyMonitorIntegrationTests.swift
     - AccessibilityMockTests.swift
     - MemoryLeakTests.swift
     - UIStateTransitionTests.swift
     - PreferencesLogicTests.swift
     - ErrorHandlingTests.swift
     - PreferencesViewTests.swift
     - AsyncOperationTests.swift

2. **Added `createForTesting()` method to Preferences class**
   - Clears UserDefaults before creating test instance
   - Ensures clean state for each test

3. **Fixed test compilation issues**
   - Replaced reference to non-existent `InputSourcePickerSheet` with `ModifierKeyInputSourcePicker`

### Known Issues
1. Some tests still failing due to:
   - Expectations about default values
   - Platform-specific input source differences
   - Error message content changes
   - Code signing issues in test environment

2. Tests that need adjustment:
   - `testLaunchAtLoginFailedError` - error message content
   - `testNormalToggleBehavior` - IME controller behavior
   - `testRightCmdDoublePress` - key handling logic
   - `testInputSourceIconMapping` - icon expectations
   - `testPreferencesWindowCreation` - default timeout value

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

### Next Steps
- Fix remaining test failures by adjusting test expectations
- Consider mocking input sources for more reliable tests
- Add integration tests for actual IME switching
- Prepare for Mac App Store submission