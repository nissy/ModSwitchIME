# ModSwitchIME Technical Specifications

## Project Overview

ModSwitchIME is a macOS menu bar application that enables instant IME (Input Method Editor) switching by pressing modifier keys alone. The application distinguishes between left and right modifier keys, allowing users to assign up to 8 different IMEs to individual modifier keys.

## Current Project Status (2025-12-19)

### Build Status
- ✅ **Build**: Fully functional (`make build` succeeds)
- ✅ **Tests**: All 134 tests passing
- ✅ **Code Signing**: Automatic signing with DEVELOPMENT_TEAM
- ✅ **Target macOS**: 13.0+ (Ventura and later)

### Implementation Status
- ✅ **Core Features**: 100% implemented and tested
- ✅ **Real-time Updates**: All settings apply without restart
- ✅ **Performance**: < 15ms switching, < 0.1% CPU idle
- ✅ **Memory Usage**: < 25MB RSS

## Architecture Overview

```
ModSwitchIME.app
├── App.swift                 # SwiftUI app entry point
├── MenuBarApp.swift          # NSStatusItem & main controller
├── KeyMonitor.swift          # CGEventTap key detection
├── ImeController.swift       # TIS API wrapper for IME switching
├── Preferences.swift         # UserDefaults + singleton pattern
├── PreferencesView.swift     # SwiftUI settings UI
├── Logger.swift              # os.Logger wrapper
└── ModSwitchIMEError.swift   # Custom error types
```

## Core Features

### 1. Modifier Key IME Switching

**Implementation**: `KeyMonitor.swift` + `ImeController.swift`

- **8 Modifier Keys**: Left/Right Command, Shift, Control, Option
- **Key Detection**: CGEventTap monitoring `flagsChanged` events
- **State Machine**: Idle → KeyDownWaiting → Action/Abort
- **Timing**: 0.1-1.0 second configurable timeout (default: 0.3s)

```swift
// Key detection flow
1. Modifier key down → Start timer
2. If other key pressed → Abort
3. If modifier key released within timeout → Switch IME
4. If timeout exceeded → Abort
```

### 2. Auto-Switch on Idle

**Implementation**: `KeyMonitor.swift` (lines 201-236)

- **Timer**: 1-second interval checking idle time
- **Range**: 1-300 seconds configurable
- **Target**: Any system IME (default: English)
- **Detection**: Keyboard activity only (mouse ignored)

### 3. Real-time Settings

**Implementation**: `Preferences.swift` singleton pattern

- **Singleton**: `Preferences.shared` instance
- **Combine**: Property observers for instant updates
- **No Restart**: All settings apply immediately

### 4. IME Support

**Implementation**: `ImeController.swift` + Text Input Services

- **All System IMEs**: Full support via TIS APIs
- **Third-party**: ATOK, Google Japanese Input, etc.
- **Parent-Child**: Automatic grouping (e.g., Hiragana/Katakana)
- **CJK Auto-detect**: System locale-based defaults

### 5. Menu Bar Integration

**Implementation**: `MenuBarApp.swift`

- **Icon States**: 
  - Normal: "⌘"
  - No permission: "⌘?"
  - Permission granted: "✓" (3 seconds)
- **Menu Items**: About, Preferences, Launch at Login, Quit
- **Permission Check**: On each menu click

### 6. Accessibility Permission

**Implementation**: `MenuBarApp.swift` + `AXIsProcessTrusted`

- **Auto-detection**: Check on launch and menu click
- **No Prompt**: Silent check without dialog
- **Auto-start**: KeyMonitor starts when permission granted

## Technical Implementation Details

### CGEventTap Architecture

```swift
// Event tap creation (KeyMonitor.swift:57-67)
CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: handleEvent
)
```

### IME Switching Logic

```swift
// Smart switching for same-family IMEs (ImeController.swift:78-89)
if currentFamily == targetFamily {
    // Switch to English first, then target
    selectInputSource("com.apple.keylayout.ABC")
    Thread.sleep(0.05)
    selectInputSource(targetIME)
}
```

### Preference Storage

```swift
// UserDefaults keys
- modifierKeyMappings: [ModifierKey: String]
- idleOffEnabled: Bool
- idleTimeout: Double (1-300)
- idleReturnIME: String?
- cmdKeyTimeout: Double (0.1-1.0)
- cmdKeyTimeoutEnabled: Bool
```

## Performance Characteristics

### Measured Performance
- **Startup**: < 1 second to menu bar
- **IME Switch**: 15ms maximum latency
- **CPU Usage**: 0.05-0.1% when idle
- **Memory**: 20-25MB typical RSS
- **Battery**: Negligible impact

### Optimization Techniques
1. **Cached Input Sources**: Avoid repeated TIS queries
2. **Efficient Event Handling**: Minimal processing in tap callback
3. **Smart Timer Management**: Stop when not needed
4. **Singleton Pattern**: Shared preference instance

## API Dependencies

### macOS 13.0+ Requirements
- `SMAppService`: Launch at Login (MenuBarApp.swift:261)
- `Locale.current.language`: CJK detection (Preferences.swift:207)

### Core APIs (10.5+)
- `CGEvent`: Key monitoring
- `TISSelectInputSource`: IME switching
- `AXIsProcessTrusted`: Permission check

## Known Issues & Workarounds

### 1. Same-Family IME Switching
**Issue**: Direct switching between Hiragana/Katakana fails
**Workaround**: Switch through English intermediate state

### 2. IME List Completeness
**Issue**: `TISCreateInputSourceList` may miss some IMEs
**Workaround**: Use `includeAllInstalled: false` parameter

### 3. Concurrent Test Crashes
**Issue**: XCTest crashes with concurrent execution
**Workaround**: Disabled concurrent testing

## Development Workflow

### Build Commands
```bash
make build          # Debug build
make test           # Run all tests
make lint           # SwiftLint check
make release        # Full release (clean, test, archive, DMG)
```

### Environment Setup
```bash
# Required: .envrc with DEVELOPMENT_TEAM
export DEVELOPMENT_TEAM="YOUR_TEAM_ID"
```

## Testing Strategy

### Test Coverage
- **Unit Tests**: 17 test files, 134 tests total
- **Mock Objects**: CGEvent, TISInputSource, AXIsProcessTrusted
- **Integration**: KeyMonitor state transitions
- **Memory**: Leak detection tests

### Key Test Files
- `KeyMonitorTests.swift`: Core functionality
- `ImeControllerTests.swift`: IME switching
- `PreferencesTests.swift`: Settings persistence
- `MenuBarAppTests.swift`: UI interactions

## Distribution

### Current Method
- Direct distribution with Developer ID
- Notarization for Gatekeeper
- DMG packaging

### Future Considerations
- Mac App Store (requires sandboxing changes)
- Homebrew cask distribution

## Security & Privacy

### Permissions
- **Required**: Accessibility (for CGEventTap)
- **Not Required**: Network, Files, Camera, etc.

### Data Handling
- **Local Only**: All processing on-device
- **No Analytics**: Zero data collection
- **No Network**: Completely offline

## Maintenance Notes

### Adding New Features
1. Update `Preferences.swift` for new settings
2. Add UI in `PreferencesView.swift`
3. Implement logic in appropriate component
4. Add tests following existing patterns

### Debugging
- Enable `Logger` categories in Console.app
- Check Debug Info menu (debug builds only)
- Use `make test-specific TEST=TestName`

## Future Roadmap

### Potential Enhancements
1. IME status in menu bar icon
2. Keyboard shortcut customization
3. Profile switching
4. Import/Export settings
5. Multi-display awareness

### Technical Debt
1. Migrate legacy command key code
2. Improve test concurrency support
3. Add UI tests
4. Enhance error recovery

---

*This document represents the complete technical state of ModSwitchIME as of 2025-12-19. It serves as both a reference for current functionality and a guide for future development.*