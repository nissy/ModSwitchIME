# ModSwitchIME - Input Method Switcher

A macOS menu bar application that switches between English input and native IME by pressing left/right ⌘ keys individually.

## Setup

### Environment Configuration

1. Copy the environment template:
```bash
cp .env.example .env
```

2. Edit `.env` with your Apple Developer credentials:
```bash
# Your Apple Developer Team ID
DEVELOPMENT_TEAM=YOUR_TEAM_ID

# Your app's bundle identifier
PRODUCT_BUNDLE_IDENTIFIER=com.yourcompany.ModSwitchIME
```

3. Find your Team ID:
```bash
security find-identity -v -p codesigning
```

### Building

The project uses direnv for automatic environment loading:

```bash
# Install direnv (if not already installed)
brew install direnv

# Allow direnv for this project
direnv allow

# Build the app
./build.sh build
```

### Alternative: Manual Environment Setup

If you prefer not to use direnv, you can export environment variables manually:

```bash
export DEVELOPMENT_TEAM="YOUR_TEAM_ID"
export PRODUCT_BUNDLE_IDENTIFIER="com.yourcompany.ModSwitchIME"
./build.sh build
```

## Features

- Left ⌘ key: Switch to English input
- Right ⌘ key: Switch to configured IME (Japanese, Chinese, Korean, etc.)
- Optional idle timeout for automatic English switching
- Menu bar interface with settings

## Requirements

- macOS 15.0 or later
- Xcode 15 or later
- Apple Developer account (for code signing)

## Privacy

This project template includes environment variable support to keep your personal information (Team ID, Bundle ID) out of the source code. Always use `.env` files for sensitive configuration and never commit them to version control.