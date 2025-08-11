# ModSwitchIME

<img src="https://github.com/user-attachments/assets/f603fcce-77fa-474b-8f8e-c9fc7a426005" width="128">

Instantly switch IMEs with 8 modifier keys - A macOS app for multilingual users

## Overview

ModSwitchIME is a macOS menu bar application that allows you to instantly switch to any IME by simply pressing a modifier key (Command, Shift, Control, Option) alone.

### Perfect for

- 🌐 **Multilingual developers** - Code in English, comment in your native language
- 📝 **Translators & Writers** - Quick switching between source and target languages
- 🎯 **Anyone seeking a simple, IME-switching focused tool**

## Features

### 1. IME Switching with Modifier Keys
<img width="562" height="772" src="https://github.com/user-attachments/assets/d662ebb5-35f3-46b8-aa5d-8d210c4dc8d9" />

#### Freely assign any IME to all 8 modifier keys

- **Left/Right Command** ⌘
- **Left/Right Shift** ⇧
- **Left/Right Control** ⌃
- **Left/Right Option** ⌥

Assign your preferred IME to each key. For example:
- Left Command → English
- Right Command → Japanese
- Left Shift → Chinese
- Any system-registered IME can be configured

#### How it works
- **Single key press**: Press and release modifier key alone → Switch to assigned IME
- **Multi-key press**: Press multiple modifier keys → Switch to the IME of the last pressed key
- **Normal shortcuts**: Modifier key + other keys → Standard shortcuts work as usual (Cmd+C, Cmd+V, etc.)
- **Left/Right distinction**: Treats left and right modifier keys as separate keys
- **Instant switching**: IME switches immediately upon key release (no delay needed)


### 2. Advanced IME Switching Features

#### Multi-Key Press
When multiple modifier keys are configured with IMEs:
- Switches to the IME of the last pressed key during simultaneous press
- Example: Left Cmd (English) + Right Cmd (Japanese) → Switches to Japanese

#### Smart Detection
- Distinguishes between single key press and key combinations
- Helps prevent accidental switching during shortcuts (Cmd+W, Ctrl+Tab, etc.)
- Designed to work with your existing keyboard shortcuts
- Note: Detection is based on modifier key events only

### 3. Auto-Switch on Idle

#### Settings
- **Enable/Disable**: Toggle switch
- **Idle detection time**: 1-300 seconds (1-second increments)
- **Target IME**: 
  - Default: English (ABC)
  - Customizable: Any system-enabled IME

#### Behavior
- Counts time without keyboard activity
- Automatically switches to specified IME when idle time is reached
- Does not detect mouse activity (keyboard only)
- Returns to normal operation on key input

### 4. Real-time Settings Update

- Most settings apply instantly without app restart
- Real-time changeable settings:
  - IME assignments to modifier keys
  - Auto-switch on idle toggle
  - Idle time modification
  - Target IME selection
- Note: Some system-level changes may require menu bar icon click to refresh


### 5. Performance Characteristics

- **Startup time**: Fast application launch
- **IME switch speed**: Fast switching with 50ms duplicate prevention
- **CPU usage**: Low resource usage when idle
- **Memory usage**: Lightweight memory footprint  
- **Battery impact**: Minimal

### 6. Enhanced Stability & Recovery

#### Automatic System Recovery
- **Event tap health monitoring**: Monitors system-level key detection capability
- **Automatic recovery**: Attempts to restore functionality when macOS disables key monitoring
- **Duplicate prevention**: 50ms throttling prevents accidental duplicate switches
- **Application focus tracking**: Detects IME state changes when switching between applications
- **Background resilience**: Designed for stable operation during system activity

#### Reliability Features
- **Automatic recovery**: Attempts to restore functionality without user intervention
- **System integration**: Handles macOS updates and permission changes gracefully
- **Performance optimization**: Reduces redundant operations while maintaining responsiveness


## Security & Privacy

ModSwitchIME is designed with privacy and security as core principles:

- **Privacy-first design**: Detects key presses to distinguish shortcuts from single modifier keys, never captures text content
- **No data collection**: All processing happens locally on your Mac
- **Open source**: Complete source code available for inspection
- **Code signed**: Official releases are signed with Developer ID and notarized by Apple

📋 **[View detailed Security Policy](https://github.com/nissy/ModSwitchIME/blob/main/SECURITY_POLICY.md)**

## Installation

### System Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission required

### Installation Steps

1. Download the latest DMG from [Releases](https://github.com/nissy/ModSwitchIME/releases)
2. **If updating**: Quit ModSwitchIME first (click 🌐 icon → Quit)
3. Mount the DMG and drag ModSwitchIME.app to Applications folder
4. Grant accessibility permission on first launch

> **Note**: When updating, you must quit the app first to avoid "Item is in use" error. This is a macOS security feature.

## Usage

### Basic Setup

1. Click the "🌐" icon in menu bar
2. Select "Preferences..."
3. Assign desired IMEs to each modifier key

### Settings

#### Modifier Key Assignment
- Assign IME to each of 8 modifier keys
- Default: No automatic assignments (manual configuration required)

#### Switching Behavior
- **Instant switching**: IME switches immediately when you release a modifier key
- **No delay required**: Unlike other tools, no waiting time needed
- **Smart detection**: Automatically distinguishes between single key press and shortcuts

#### Auto-Switch on Idle
- Idle time: 1-300 seconds
- Target: Select any IME

## Technical Comparison with Other IME Switchers

### Implementation Approaches

ModSwitchIME uses **TISInputSource API** for direct IME switching, while most other apps use **key event simulation**:

| App | Implementation | Strengths | Limitations |
|-----|---------------|-----------|-------------|
| **ModSwitchIME** | TISInputSource API with retry | Direct IME control, reliable CJK support | Requires accessibility permission |
| **英かな (eisukana)** | CGEvent API + TIS | Simple, lightweight | Primarily English⇔Japanese |
| **Karabiner-Elements** | IOKit HID interception | Highly customizable, low-level control | Known CJK switching issues |
| **BetterTouchTool** | Automation/External tools | Wide gesture support | Indirect, requires helper tools |
| **Hammerspoon** | Lua scripting bridge | Unlimited customization | Requires programming knowledge |

### Key Technical Advantages

#### 1. **Direct IME Control**
- **ModSwitchIME**: Uses TISSelectInputSource for immediate switching
- **Others**: Most simulate Cmd+Space or send key codes (indirect method)

#### 2. **CJK Language Reliability**
- **ModSwitchIME**: Implements retry logic and verification for reliable CJK switching
- **Karabiner-Elements**: Documented issues with TISSelectInputSource for CJK languages
- **Others**: Inherit macOS API limitations or use workarounds

#### 3. **Modifier Key Support**
- **ModSwitchIME**: All 8 modifier keys (Left/Right × 4) independently configurable
- **英かな**: Left/Right Command only
- **Others**: Various key combinations, often require complex configuration

#### 4. **Configuration Complexity**
- **ModSwitchIME**: GUI-based configuration
- **Karabiner-Elements**: JSON file editing required
- **Hammerspoon**: Lua programming required
- **Others**: App-specific interfaces

### Why Choose ModSwitchIME

**For users who need:**
1. **Reliable multilingual switching** - Especially for CJK languages
2. **Maximum modifier key flexibility** - 8 independent keys vs 2-4 in other apps  
3. **Fast switching** - Direct API calls (50ms duplicate prevention)
4. **Simple configuration** - GUI vs JSON/programming
5. **IME-focused design** - Purpose-built vs general automation tools

**Technical uniqueness:**
- Only app using modern TISInputSource API for comprehensive IME control
- Precise modifier key detection for single key vs combination
- State-based implementation for reliable key detection

## Troubleshooting

### IME not switching

1. Enable ModSwitchIME in System Settings → Privacy & Security → Accessibility
2. The app automatically detects and recovers from system permission issues
3. If issues persist, restart the app - it will automatically restore full functionality

### System Updates or Permission Changes

ModSwitchIME includes automatic recovery features:
- **Automatic detection**: Monitors system permission status continuously
- **Self-healing**: Automatically restores functionality after macOS updates
- **No manual intervention**: Recovery happens in the background without user action

## License

MIT License

Copyright © 2025 nissy. All rights reserved.
