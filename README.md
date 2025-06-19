# ModSwitchIME

Instantly switch IMEs with 8 modifier keys - A macOS app for multilingual users

## Overview

ModSwitchIME is a macOS menu bar application that allows you to instantly switch to any IME by simply pressing a modifier key (Command, Shift, Control, Option) alone.

### Perfect for

- 🌐 **Multilingual developers** - Code in English, comment in your native language
- 📝 **Translators & Writers** - Quick switching between source and target languages
- 🎯 **Anyone seeking a simple, IME-switching focused tool**

## Features

### 1. IME Switching with Modifier Keys

#### Freely assign any IME to all 8 modifier keys

- **Left Command** → English, Japanese, Chinese, Korean, French, etc.
- **Right Command** → ATOK, Google Japanese Input, Kotoeri, etc.
- **Left Shift** → Chinese (Simplified), Chinese (Traditional), Pinyin, etc.
- **Right Shift** → Russian, Arabic, Hebrew, etc.
- **Left Control** → Vietnamese, Thai, Hindi, etc.
- **Right Control** → Spanish, Portuguese, Italian, etc.
- **Left Option** → German, Dutch, Swedish, etc.
- **Right Option** → Turkish, Greek, Polish, etc.

Choose from any IME registered in your system.

#### How it works
- Press modifier key alone → Switch to assigned IME
- Modifier key + other keys → Normal shortcuts (Cmd+C, Cmd+V, etc.)
- Distinguishes between left and right modifier keys
- Detection time adjustable from 0.1 to 1.0 seconds (default: 0.3 seconds)

#### Supported IMEs
- **Japanese**: Kotoeri, Google Japanese Input, ATOK, Kawasemi, etc.
- **Chinese**: Simplified (SCIM), Traditional (TCIM), Pinyin, Zhuyin, Cangjie
- **Korean**: Hangul input
- **Others**: Vietnamese, Thai, Russian, Arabic, and all system-registered IMEs
- Full support for third-party IMEs

### 2. Auto-Switch on Idle

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

### 3. Real-time Settings Update

- All settings apply instantly
- No app restart required
- Real-time changeable settings:
  - IME assignments to modifier keys
  - Detection time adjustment
  - Auto-switch on idle toggle
  - Idle time modification
  - Target IME selection

### 4. CJK Language Auto-Detection

Right Command key default setting auto-detects based on system locale:

1. Japanese environment → Japanese (Hiragana)
2. Chinese environment (Simplified) → Chinese Simplified
3. Chinese environment (Traditional) → Chinese Traditional
4. Korean environment → Korean

Detection priority:
1. Japanese (Kotoeri)
2. Chinese Simplified (SCIM)
3. Chinese Traditional (TCIM)
4. Korean
5. Vietnamese

### 5. Menu Bar Features

#### Menu Items
- **About ModSwitchIME** - Version information
- **Preferences...** - Open settings window (⌘,)
- **Launch at Login** - Toggle auto-start
- **Quit** - Exit application (⌘Q)

### 6. Automatic Accessibility Permission Detection

- Checks permission status on app launch (no prompt shown)
- Checks permission status on each menu click
- Automatically starts key monitoring when permission is granted
- Visual feedback (✓ icon) when permission is granted

### 7. Launch at Login

- Easy on/off toggle from menu
- Uses SMAppService API (macOS 13.0+)
- Registers as system startup item

### 8. Performance Characteristics

- **Startup time**: Under 1 second
- **IME switch speed**: Under 15 milliseconds
- **CPU usage**: Less than 0.1% when idle
- **Memory usage**: Under 25MB
- **Battery impact**: Minimal

### 9. Parent-Child IME Auto-Grouping

Japanese IME example:
- Select "Japanese" → Hiragana, Katakana, Romaji all available
- Mode switching works as usual with IME operations

Chinese IME example:
- Select "Chinese" → Pinyin, Zhuyin, handwriting input all available

## Installation

### System Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission required

### Installation Steps

1. Download the latest DMG from [Releases](https://github.com/your-username/ModSwitchIME/releases)
2. Mount the DMG and drag ModSwitchIME.app to Applications folder
3. Grant accessibility permission on first launch

## Usage

### Basic Setup

1. Click the "⌘" icon in menu bar
2. Select "Preferences..."
3. Assign desired IMEs to each modifier key

### Settings

#### Modifier Key Assignment
- Assign IME to each of 8 modifier keys
- Default: Left Command = English, Right Command = CJK language (auto-detected)

#### Detection Time (Wait Before Switching)
- Modifier key alone detection time: 0.1-1.0 seconds (100-1000ms)
- Default: 0.3 seconds (300ms)

#### Auto-Switch on Idle
- Idle time: 1-300 seconds
- Target: Select any IME

## Comparison with Karabiner-Elements

| Feature | ModSwitchIME | Karabiner-Elements |
|---------|-------------|-------------------|
| **IME switching focused** | ✅ Purpose-built | ❌ General-purpose tool |
| **Switch to any IME** | ✅ 100% reliable | ❌ CJK languages often fail |
| **Left/Right key distinction** | ✅ 8 keys individually | ❌ Difficult |
| **Configuration** | ✅ GUI | ❌ JSON editing |
| **Auto-switch on idle** | ✅ Built-in | ❌ Not supported |

### Why Choose ModSwitchIME

1. **IME switching focused** - Simple with no unnecessary features
2. **High reliability** - Reliably switches to all IMEs
3. **Easy configuration** - No technical knowledge required

## Troubleshooting

### IME not switching

1. Enable ModSwitchIME in System Settings → Privacy & Security → Accessibility
2. Restart the app

## License

MIT License

Copyright © 2025 nissy. All rights reserved.