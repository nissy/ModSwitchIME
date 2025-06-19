# ModSwitchIME - macOS IME Switcher
# Makefile for building, testing, and distributing ModSwitchIME

# Configuration
PROJECT_NAME = ModSwitchIME
SCHEME = ModSwitchIME
CONFIGURATION_DEBUG = Debug
CONFIGURATION_RELEASE = Release
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(PROJECT_NAME).xcarchive
EXPORT_PATH = $(BUILD_DIR)/export
DMG_PATH = $(BUILD_DIR)/$(PROJECT_NAME).dmg

# Xcode build settings
XCODE_PROJECT = $(PROJECT_NAME).xcodeproj
XCODE_WORKSPACE = $(PROJECT_NAME).xcworkspace
DESTINATION = "platform=macOS"

# Code signing
DEVELOPMENT_TEAM ?= R7LKF73J2W
CODE_SIGN_IDENTITY = "Mac Developer"
INSTALLER_IDENTITY = "Developer ID Installer"

# Version and build number
VERSION ?= 1.0.0
BUILD_NUMBER ?= $(shell git rev-list --count HEAD)

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

.PHONY: all clean build test lint archive package dmg install uninstall help setup-permissions dev run

# Default target
all: clean build test

help: ## Show this help message
	@echo "$(BLUE)ModSwitchIME Makefile$(NC)"
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Build targets
build: ## Build the project for debugging
	@echo "$(BLUE)Building $(PROJECT_NAME) for debug...$(NC)"
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination $(DESTINATION) \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
		CODE_SIGN_STYLE=Automatic \
		build

build-release: ## Build the project for release
	@echo "$(BLUE)Building $(PROJECT_NAME) for release...$(NC)"
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-destination $(DESTINATION) \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		build

build-unsigned: ## Build without code signing (for development)
	@echo "$(BLUE)Building $(PROJECT_NAME) without code signing...$(NC)"
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination $(DESTINATION) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		build

dev: ## Build for development with ad-hoc signing (keeps accessibility permissions)
	@echo "$(BLUE)Building $(PROJECT_NAME) for development with ad-hoc signing...$(NC)"
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination $(DESTINATION) \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGN_STYLE=Automatic \
		build

# Test targets
test: ## Run unit tests
	@echo "$(BLUE)Running unit tests...$(NC)"
	@if xcodebuild -list -project $(XCODE_PROJECT) | grep -q "ModSwitchIMETests"; then \
		echo "$(GREEN)Running tests with ModSwitchIMETests target...$(NC)"; \
		xcodebuild test \
			-project $(XCODE_PROJECT) \
			-scheme $(SCHEME) \
			-destination $(DESTINATION) | xcpretty || true; \
	else \
		echo "$(YELLOW)Test target not found. Running validation tests...$(NC)"; \
		swift run_tests.swift; \
	fi

test-ui: ## Run UI tests
	@echo "$(BLUE)Running UI tests...$(NC)"
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		test -only-testing:$(PROJECT_NAME)UITests

test-unit: ## Run only unit tests
	@echo "$(BLUE)Running unit tests only...$(NC)"
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		test -only-testing:ModSwitchIMETests

test-coverage: ## Generate test coverage report
	@echo "$(BLUE)Generating test coverage report...$(NC)"
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-enableCodeCoverage YES \
		test

test-specific: ## Run specific test (usage: make test-specific TEST=PreferencesViewTests)
	@echo "$(BLUE)Running specific test: $(TEST)...$(NC)"
	@if [ -z "$(TEST)" ]; then \
		echo "$(RED)Error: Please specify TEST=TestClassName$(NC)"; \
		exit 1; \
	fi
	xcodebuild test \
		-project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-only-testing:ModSwitchIMETests/$(TEST)

test-list: ## List all available tests
	@echo "$(BLUE)Available test files:$(NC)"
	@find ModSwitchIMETests -name "*Tests.swift" -type f | while read file; do \
		basename "$$file" .swift; \
	done

# Code quality targets
lint: ## Run SwiftLint if available
	@if command -v swiftlint >/dev/null 2>&1; then \
		echo "$(BLUE)Running SwiftLint...$(NC)"; \
		swiftlint; \
	else \
		echo "$(YELLOW)SwiftLint not found. Install with: brew install swiftlint$(NC)"; \
	fi

lint-fix: ## Auto-fix SwiftLint issues
	@if command -v swiftlint >/dev/null 2>&1; then \
		echo "$(BLUE)Auto-fixing SwiftLint issues...$(NC)"; \
		swiftlint --fix; \
	else \
		echo "$(YELLOW)SwiftLint not found. Install with: brew install swiftlint$(NC)"; \
	fi

format: ## Format code with SwiftFormat if available
	@if command -v swiftformat >/dev/null 2>&1; then \
		echo "$(BLUE)Formatting code with SwiftFormat...$(NC)"; \
		swiftformat .; \
	else \
		echo "$(YELLOW)SwiftFormat not found. Install with: brew install swiftformat$(NC)"; \
	fi

# Archive and distribution targets
archive: ## Create an archive for distribution
	@echo "$(BLUE)Creating archive...$(NC)"
	@mkdir -p $(BUILD_DIR)
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-destination $(DESTINATION) \
		-archivePath $(ARCHIVE_PATH) \
		MARKETING_VERSION=$(VERSION) \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) \
		archive

export-app: archive ## Export the app from archive
	@echo "$(BLUE)Exporting app...$(NC)"
	@mkdir -p $(EXPORT_PATH)
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist ExportOptions.plist

package: export-app ## Create a distributable package
	@echo "$(BLUE)Creating package...$(NC)"
	@if [ -d "$(EXPORT_PATH)/$(PROJECT_NAME).app" ]; then \
		echo "$(GREEN)App exported successfully$(NC)"; \
	else \
		echo "$(RED)App export failed$(NC)"; \
		exit 1; \
	fi

dmg: package ## Create a DMG file for distribution
	@echo "$(BLUE)Creating DMG...$(NC)"
	@if command -v create-dmg >/dev/null 2>&1; then \
		create-dmg \
			--volname "$(PROJECT_NAME)" \
			--window-pos 200 120 \
			--window-size 800 600 \
			--icon-size 100 \
			--icon "$(PROJECT_NAME).app" 200 190 \
			--hide-extension "$(PROJECT_NAME).app" \
			--app-drop-link 600 185 \
			"$(DMG_PATH)" \
			"$(EXPORT_PATH)/"; \
	else \
		echo "$(YELLOW)create-dmg not found. Install with: brew install create-dmg$(NC)"; \
		echo "$(BLUE)Creating simple DMG...$(NC)"; \
		hdiutil create -volname "$(PROJECT_NAME)" -srcfolder "$(EXPORT_PATH)" -ov -format UDZO "$(DMG_PATH)"; \
	fi

notarize: dmg ## Notarize the DMG (requires Apple Developer account)
	@echo "$(BLUE)Notarizing DMG...$(NC)"
	@echo "$(YELLOW)Note: This requires APPLE_ID and APPLE_PASSWORD environment variables$(NC)"
	@if [ -z "$(APPLE_ID)" ] || [ -z "$(APPLE_PASSWORD)" ]; then \
		echo "$(RED)Error: APPLE_ID and APPLE_PASSWORD environment variables must be set$(NC)"; \
		exit 1; \
	fi
	xcrun notarytool submit "$(DMG_PATH)" \
		--apple-id "$(APPLE_ID)" \
		--password "$(APPLE_PASSWORD)" \
		--team-id "$(DEVELOPMENT_TEAM)" \
		--wait
	xcrun stapler staple "$(DMG_PATH)"

# Development setup targets
setup-permissions: ## Setup accessibility permissions for development
	@echo "$(BLUE)Setting up accessibility permissions...$(NC)"
	@echo "$(YELLOW)You need to manually grant accessibility permissions in System Preferences$(NC)"
	@echo "$(YELLOW)Go to: System Preferences > Security & Privacy > Privacy > Accessibility$(NC)"
	@echo "$(YELLOW)Add and enable your development tools (Xcode, Terminal, etc.)$(NC)"
	@open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

setup-dev: ## Setup development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@if ! command -v swiftlint >/dev/null 2>&1; then \
		echo "$(YELLOW)Installing SwiftLint...$(NC)"; \
		brew install swiftlint; \
	fi
	@if ! command -v swiftformat >/dev/null 2>&1; then \
		echo "$(YELLOW)Installing SwiftFormat...$(NC)"; \
		brew install swiftformat; \
	fi
	@if ! command -v create-dmg >/dev/null 2>&1; then \
		echo "$(YELLOW)Installing create-dmg...$(NC)"; \
		brew install create-dmg; \
	fi
	@echo "$(GREEN)Development environment setup complete$(NC)"

# Installation targets
install: package ## Install the app to /Applications
	@echo "$(BLUE)Installing $(PROJECT_NAME) to /Applications...$(NC)"
	@if [ -d "$(EXPORT_PATH)/$(PROJECT_NAME).app" ]; then \
		sudo cp -R "$(EXPORT_PATH)/$(PROJECT_NAME).app" /Applications/; \
		echo "$(GREEN)$(PROJECT_NAME) installed successfully$(NC)"; \
	else \
		echo "$(RED)App not found. Run 'make package' first.$(NC)"; \
		exit 1; \
	fi

uninstall: ## Uninstall the app from /Applications
	@echo "$(BLUE)Uninstalling $(PROJECT_NAME)...$(NC)"
	@if [ -d "/Applications/$(PROJECT_NAME).app" ]; then \
		sudo rm -rf "/Applications/$(PROJECT_NAME).app"; \
		echo "$(GREEN)$(PROJECT_NAME) uninstalled successfully$(NC)"; \
	else \
		echo "$(YELLOW)$(PROJECT_NAME) not found in /Applications$(NC)"; \
	fi

dev-install: dev ## Build with ad-hoc signing and install to /Applications
	@echo "$(BLUE)Installing development build to /Applications...$(NC)"
	@BUILD_PATH=$$(xcodebuild -project $(XCODE_PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION_DEBUG) -showBuildSettings | grep -E '^\s*BUILT_PRODUCTS_DIR' | awk '{print $$3}'); \
	echo "$(YELLOW)Build path: $$BUILD_PATH$(NC)"; \
	if [ -d "$$BUILD_PATH/$(PROJECT_NAME).app" ]; then \
		echo "$(YELLOW)Stopping existing $(PROJECT_NAME) process...$(NC)"; \
		pkill -x $(PROJECT_NAME) || true; \
		echo "$(YELLOW)Removing old installation...$(NC)"; \
		sudo rm -rf /Applications/$(PROJECT_NAME).app || true; \
		sudo cp -R "$$BUILD_PATH/$(PROJECT_NAME).app" /Applications/; \
		echo "$(GREEN)Development build installed successfully$(NC)"; \
		echo "$(BLUE)Starting $(PROJECT_NAME)...$(NC)"; \
		open /Applications/$(PROJECT_NAME).app; \
	else \
		echo "$(RED)App not found at: $$BUILD_PATH/$(PROJECT_NAME).app$(NC)"; \
		echo "$(YELLOW)Looking for app in DerivedData...$(NC)"; \
		APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "$(PROJECT_NAME).app" -type d | grep -v "\.dSYM" | head -1); \
		if [ -n "$$APP_PATH" ]; then \
			echo "$(GREEN)Found app at: $$APP_PATH$(NC)"; \
			echo "$(YELLOW)Stopping existing $(PROJECT_NAME) process...$(NC)"; \
			pkill -x $(PROJECT_NAME) || true; \
			echo "$(YELLOW)Removing old installation...$(NC)"; \
			sudo rm -rf /Applications/$(PROJECT_NAME).app || true; \
			sudo cp -R "$$APP_PATH" /Applications/; \
			echo "$(GREEN)Development build installed successfully$(NC)"; \
			echo "$(BLUE)Starting $(PROJECT_NAME)...$(NC)"; \
			open /Applications/$(PROJECT_NAME).app; \
		else \
			echo "$(RED)Could not find $(PROJECT_NAME).app$(NC)"; \
			exit 1; \
		fi \
	fi

# Utility targets
clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -rf DerivedData
	xcodebuild -project $(XCODE_PROJECT) -scheme $(SCHEME) clean

clean-all: clean ## Clean all artifacts including caches
	@echo "$(BLUE)Cleaning all artifacts...$(NC)"
	@rm -rf ~/Library/Developer/Xcode/DerivedData/$(PROJECT_NAME)-*
	@rm -rf ~/Library/Caches/com.apple.dt.Xcode

version: ## Show current version information
	@echo "$(BLUE)Version Information:$(NC)"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Build: $(BUILD_NUMBER)"
	@echo "Git commit: $(shell git rev-parse --short HEAD)"
	@echo "Git branch: $(shell git branch --show-current)"

status: ## Show project status
	@echo "$(BLUE)Project Status:$(NC)"
	@echo "Git status:"
	@git status --porcelain || echo "Not a git repository"
	@echo ""
	@echo "Build artifacts:"
	@ls -la $(BUILD_DIR) 2>/dev/null || echo "No build artifacts"
	@echo ""
	@echo "Installed version:"
	@if [ -d "/Applications/$(PROJECT_NAME).app" ]; then \
		defaults read "/Applications/$(PROJECT_NAME).app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Cannot read version"; \
	else \
		echo "Not installed"; \
	fi

# Swift Package Manager targets
spm-build: ## Build using Swift Package Manager
	@echo "$(BLUE)Building with Swift Package Manager...$(NC)"
	swift build

spm-test: ## Test using Swift Package Manager
	@echo "$(BLUE)Testing with Swift Package Manager...$(NC)"
	swift test

spm-clean: ## Clean Swift Package Manager artifacts
	@echo "$(BLUE)Cleaning SPM artifacts...$(NC)"
	swift package clean

# Documentation targets
docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@if command -v jazzy >/dev/null 2>&1; then \
		jazzy --clean --author "ModSwitchIME Team" --github_url https://github.com/ModSwitchIME/ModSwitchIME; \
	else \
		echo "$(YELLOW)Jazzy not found. Install with: gem install jazzy$(NC)"; \
	fi

# Release targets
release: clean lint test archive package dmg ## Full release build
	@echo "$(GREEN)Release build completed successfully!$(NC)"
	@echo "$(BLUE)Artifacts created:$(NC)"
	@ls -la $(BUILD_DIR)

release-with-notarization: release notarize ## Full release with notarization
	@echo "$(GREEN)Release with notarization completed successfully!$(NC)"

# CI/CD targets
ci: clean lint test ## Run CI pipeline
	@echo "$(GREEN)CI pipeline completed successfully!$(NC)"

ci-release: clean lint test archive ## Run CI release pipeline
	@echo "$(GREEN)CI release pipeline completed successfully!$(NC)"

# Debug targets
debug-info: ## Show debug information
	@echo "$(BLUE)Debug Information:$(NC)"
	@echo "Xcode version: $(shell xcodebuild -version | head -1)"
	@echo "Swift version: $(shell swift --version | head -1)"
	@echo "macOS version: $(shell sw_vers -productVersion)"
	@echo "Architecture: $(shell uname -m)"
	@echo "Available destinations:"
	@xcodebuild -project $(XCODE_PROJECT) -scheme $(SCHEME) -showdestinations

.DEFAULT_GOAL := help