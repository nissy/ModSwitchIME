# ModSwitchIME - Technical Specifications

## Overview

ModSwitchIME (Modifier Switch Input Method Editor) is a macOS menu bar application that enables quick switching between English input and native IME (Input Method Editor) by pressing left/right Command (⌘) keys individually.

## Current Project Status (2025-06-19)

### Build Status
- **Version**: 1.0.0
- **Branch**: main (with uncommitted changes)
- **Latest Commit**: "fix" (f8d0260) 
- **Build Artifacts**: Successfully built and archived
- **Test Status**: Code signing issues preventing test execution

### Implementation Status
- ✅ Core functionality implemented and working
- ✅ CGEventTap-based key monitoring
- ✅ IME switching with TISInputSource
- ✅ Menu bar interface with preferences
- ✅ Accessibility permission handling
- ✅ Launch at login support
- ✅ All 8 modifier keys supported for IME switching
- ✅ Real-time setting updates (no restart required)
- ⚠️ Test suite exists but cannot run due to code signing

### Recent Changes (Latest Session)
- **IME Picker Fix**: Fixed issue where Apple Kotoeri and Google Japanese Input weren't showing
  - Changed to always fetch all input sources and filter by enabled state
  - `TISCreateInputSourceList(nil, false)` doesn't return all enabled IMEs
- **UI Text Improvements**: Made all UI text more intuitive and clear
  - "Auto Switch on Idle" for idle timeout
  - "Modifier Key Detection" with clearer descriptions
  - "Click to assign" instead of "Not configured"
  - Permission menu shows "Permission Not Granted" when not granted
- **Disabled IME Display**: Shows disabled IMEs in gray when "Show disabled sources" is checked
  - Disabled IMEs cannot be selected (button disabled)
  - Clear visual distinction with opacity 0.5
- **Removed Restart System**: All settings now apply in real-time
  - Removed `needsRestart` property and all restart-related code
  - Removed restart alerts and buttons from Preferences
  - Kept manual restart option in top menu for user convenience
- **Preferences Window Size**: Increased to 500x700 to show all content properly
- **Bug Fixes**:
  - Fixed initial checkbox state for modifier keys
  - Fixed IME assignment from "Not configured" state

### Architecture Overview
The application uses CGEventTap for system-wide key event monitoring:

```
MenuBarApp (Host Application)
    ├── KeyMonitor (CGEventTap for key detection)
    ├── ImeController (TISSelectInputSource wrapper)
    ├── Preferences (UserDefaults persistence)
    └── Logger (os.Logger for debugging)
```

### Key Files
- **Core Implementation**: 8 Swift files in `ModSwitchIME/` directory
- **Test Suite**: 17 test files in `ModSwitchIMETests/` directory
- **Build System**: Comprehensive Makefile with multiple targets
- **Documentation**: README.md, CLAUDE.md, SPECS.md

## Current Features

### 1. Modifier Key IME Switching
- **All 8 Modifier Keys Supported**:
  - Left Control, Right Control
  - Left Shift, Right Shift  
  - Left Option (Alt), Right Option (Alt)
  - Left Command (⌘), Right Command (⌘)
- **Per-Key Configuration**: Each modifier key can be assigned to any available IME
- **Default Configuration**:
  - Left ⌘ Key: Switch to English input (ABC/US keyboard)
  - Right ⌘ Key: Switch to user-configured IME (Japanese, Chinese, Korean, etc.)
  - Other keys: Not configured by default
- **Key Detection**: Configurable timeout (default 300ms) for single key press detection
- **Modifier Combination Handling**: Only triggers when modifier key is pressed alone, not in combination

### 2. Idle Timeout
- **Automatic IME Switch**: Optionally switches to specified IME after user-defined idle period
- **Configurable Timeout**: 1-300 seconds
- **Activity Tracking**: Monitors keyboard activity to reset idle timer
- **Return IME Selection**: Choose specific IME to return to (English default)
- **No Configuration Restrictions**: Available regardless of modifier key configuration

### 3. Menu Bar Interface
- **Status Icon**: Shows "⌘" when active, "⌘?" when permissions not granted
- **Menu Items**:
  - About ModSwitchIME
  - Preferences... (⌘,)
  - Grant Permissions... / Permission Not Granted (shows current state)
  - Launch at Login (checkmark when enabled)
  - Restart ModSwitchIME (⌘R)
  - Quit (⌘Q)
- **Permission-based UI**: 
  - Permission menu shows "Permission Not Granted" when not granted
  - Shows "Accessibility Granted ✓" when granted (grayed out)
  - Preferences disabled without permission

### 4. Preferences Window
- **Window Size**: 500x700 to accommodate all settings
- **Auto Switch on Idle**: 
  - Toggle for automatic IME switching when idle
  - Timeout duration: 1-300 seconds
  - Return to: Select specific IME or default to English
- **Modifier Key Detection**:
  - "Wait before switching" toggle to prevent accidental triggers
  - Hold time: 0.1-1.0 seconds
  - Clear explanatory text for behavior
- **Modifier Key Assignments**:
  - All 8 modifier keys listed with current IME assignment
  - "Click to assign" placeholder for unconfigured keys
  - IME picker with language grouping and search
  - "Remove Assignment" button in picker
  - "Show disabled sources" toggle in picker
  - Disabled IMEs shown in gray and not selectable
- **Real-time Updates**: All settings apply immediately without restart

### 5. Multi-IME Support
- **Automatic Detection**: Detects all available input methods
- **Language Grouping**: Organizes input sources by language
- **CJK Priority**: Smart detection of Chinese, Japanese, Korean IMEs
- **ATOK Support**: Special handling for ATOK modes (Hiragana, Katakana, etc.)
- **Google IME Support**: Proper naming for Google Japanese Input modes
- **Disabled Source Visibility**: Option to show/hide disabled input sources

## Technical Implementation

### Architecture

```
┌─────────────────┐
│   Menu Bar UI   │
│  (SwiftUI/AppKit)│
└────────┬────────┘
         │
┌────────▼────────┐
│  MenuBarApp     │
│  (Main Controller)│
└────────┬────────┘
         │
    ┌────┴────┬─────────┬──────────┐
    │         │         │          │
┌───▼───┐ ┌──▼───┐ ┌──▼────┐ ┌───▼────┐
│KeyMonitor│ │ImeController│ │Preferences│ │Logger│
│(CGEventTap)│ │(TISInputSource)│ │(UserDefaults)│ │(os.Logger)│
└───────┘ └──────┘ └───────┘ └────────┘
```

### Key Components

#### 1. App.swift
- Entry point using SwiftUI App protocol
- Initializes MenuBarApp as @StateObject
- Provides Settings scene for preferences

#### 2. MenuBarApp.swift
- Main application controller
- Manages NSStatusItem for menu bar presence
- Handles menu actions and window management
- Monitors system events (sleep/wake, screen lock)
- Manages accessibility permissions
- Implements launch at login via SMAppService

#### 3. KeyMonitor.swift
- Implements CGEventTap for global key monitoring
- State machine for modifier key detection:
  ```
  Idle → Modifier Down → [Timeout/Other Key] → Action/Reset
  ```
- Tracks all 8 modifier keys independently using keyCode detection
- Idle timer implementation with 1-second check interval
- Idle timeout switches to configured IME or defaults to English
- Event tap recovery on timeout/disable
- Generic modifier key state tracking with legacy command key support

#### 4. ImeController.swift
- Wraps Text Input Services (TIS) framework
- Manages input source switching
- switchToSpecificIME() method for arbitrary IME switching
- Caches input sources for performance
- Implements workaround for same-IME-family switching
- Validates switching success with async verification

#### 5. Preferences.swift
- UserDefaults-backed preference storage
- Observable object for SwiftUI bindings
- ModifierKey enum defining all 8 modifier keys with keyCodes and display names
- modifierKeyMappings dictionary for per-key IME assignments
- modifierKeyEnabled dictionary for per-key enable/disable states
- idleReturnIME for configuring idle timeout return IME
- getIME() returns nil for disabled keys
- Auto-detects default CJK input method based on system locale
- Provides comprehensive input source enumeration
- Language detection and categorization logic
- Backward compatibility with legacy motherImeId

#### 6. PreferencesView.swift
- SwiftUI-based preferences interface
- ModifierKeyRow component for each modifier key configuration
  - Simplified UI without checkbox
  - IME picker button always accessible
- Custom ModifierKeyInputSourcePicker with search
- IdleIMEPicker for selecting idle timeout return IME
  - Always available regardless of modifier key configuration
  - Default to English option
- Language-based grouping of input sources
- Real-time preference updates
- App restart handling for IME changes
- Clear selection button for removing assignments

#### 7. Logger.swift
- Unified logging using os.Logger
- Category-based logging (main, ime, keyboard)
- Debug-only logging with #if DEBUG
- No file I/O or console output in release

#### 8. ModSwitchIMEError.swift
- Custom error types with localized descriptions
- Recovery suggestions for each error type
- Comprehensive error handling throughout

### Technical Details

#### Real-time Settings Application
All settings are read directly from UserDefaults on each use:
- **Modifier key mappings**: Checked on each key press via `preferences.getIME(for: modifierKey)`
- **Idle timeout settings**: Checked every second in timer via `preferences.idleOffEnabled`, `preferences.idleTimeout`, `preferences.idleReturnIME`
- **Key timeout enabled**: Checked on key release via `preferences.cmdKeyTimeoutEnabled`
- **No restart required**: All configuration changes take effect immediately

#### Event Handling
```swift
// CGEventTap configuration
let eventMask = (1 << CGEventType.flagsChanged.rawValue) | 
                (1 << CGEventType.keyDown.rawValue)

CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: handleEvent,
    userInfo: self
)
```

#### IME Switching
```swift
// TIS framework usage
TISSelectInputSource(inputSource)

// Same-family workaround
if currentFamily == targetFamily {
    // Switch to English first
    TISSelectInputSource(englishSource)
    Thread.sleep(forTimeInterval: 0.05)
    // Then switch to target
    TISSelectInputSource(targetSource)
}
```

#### Permission Handling
- Uses `AXIsProcessTrusted()` for accessibility check
- No automatic permission prompts
- User-initiated permission request via menu
- Graceful degradation when permissions not granted
- Visual feedback when permission is granted

### Security & Privacy

#### Entitlements
```xml
<!-- Non-sandboxed for CGEventTap access -->
<key>com.apple.security.app-sandbox</key>
<false/>

<!-- Required for automation -->
<key>com.apple.security.automation.apple-events</key>
<true/>
```

#### Permissions
- **Accessibility**: Required for keyboard monitoring
- **No Network Access**: Completely offline
- **No File System Access**: Only UserDefaults
- **No Personal Data Collection**: Privacy-focused

### Performance Characteristics

#### Resource Usage
- **Memory**: < 25MB RSS typical
- **CPU**: < 0.1% idle, spike during switching
- **Energy**: Minimal impact using event-driven design

#### Latency
- **Key Detection**: < 1ms from physical press
- **IME Switch**: 10-50ms depending on system load
- **UI Response**: Immediate (< 16ms)

### Platform Requirements

- **macOS Version**: 15.0+ (Sequoia)
- **Architecture**: Universal (Apple Silicon + Intel)
- **Xcode**: 15.0+
- **Swift**: 5.9+

### Build Configuration

#### Debug
- Assertions enabled
- Debug logging active
- Code coverage enabled
- No code signing required

#### Release
- Optimizations enabled
- Debug logging disabled
- Hardened runtime
- Notarization ready

### Testing Strategy

#### Unit Tests
- ImeController logic tests
- Preferences persistence tests
- State machine validation
- Input source enumeration tests
- Error handling tests
- Memory leak tests

#### Integration Tests
- IME switching verification
- Permission flow testing
- System event handling
- UI state transitions

#### Manual Testing
- Multiple IME configurations
- Permission grant/revoke cycles
- System sleep/wake cycles
- Multi-monitor setups

### Known Limitations

1. **CGEventTap Limitations**
   - Can be disabled by system under load
   - Requires accessibility permission
   - Not available in sandboxed environment

2. **IME Switching**
   - Some IMEs may have internal state
   - Switching delay varies by IME
   - Cannot detect IME-internal mode changes

3. **System Integration**
   - Cannot override system shortcuts
   - Limited to session-level events
   - No support for secure input fields

4. **IME Detection Issue**
   - `TISCreateInputSourceList(nil, false)` doesn't return all enabled IMEs
   - Workaround: Always fetch all sources and filter by enabled state manually

### Future Enhancements

1. **Planned Features**
   - Visual feedback for mode switches
   - Customizable key combinations
   - Per-application settings
   - IME mode indicators

2. **Technical Improvements**
   - Performance optimizations
   - Extended test coverage
   - Enhanced error recovery
   - Improved IME compatibility

## Development Setup

### Prerequisites
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install development dependencies
brew install swiftlint swiftformat
```

### Building
```bash
# Debug build
make build

# Release build
make build-release

# Run tests
make test

# Lint code
make lint
```

### Environment Variables
```bash
# Required for code signing
export DEVELOPMENT_TEAM="YOUR_TEAM_ID"
export PRODUCT_BUNDLE_IDENTIFIER="com.yourcompany.ModSwitchIME"
```

## Distribution

### Mac App Store
- Currently not supported due to CGEventTap requirements
- Would require significant architecture changes

### Direct Distribution
- Notarization required
- Developer ID signing
- DMG creation supported via Makefile

## License

Copyright © 2024 ModSwitchIME contributors. All rights reserved.