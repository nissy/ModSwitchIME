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
DESTINATION = "platform=macOS"

# Environment variables (from .envrc)
DEVELOPMENT_TEAM ?= $(DEVELOPMENT_TEAM)
VERSION ?= $(VERSION)
BUILD_NUMBER ?= $(BUILD_NUMBER)

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

.PHONY: all clean build test lint help

# Default target
all: clean build test

help: ## Show this help message
	@echo "$(BLUE)ModSwitchIME Makefile$(NC)"
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Build targets
build: ## Build the project for debugging
	@echo "$(BLUE)Building $(PROJECT_NAME) for debug...$(NC)"
	./Scripts/generate_info_plist.sh
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination $(DESTINATION) \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		PRODUCT_BUNDLE_IDENTIFIER=$(PRODUCT_BUNDLE_IDENTIFIER) \
		TEST_BUNDLE_IDENTIFIER=$(TEST_BUNDLE_IDENTIFIER) \
		CODE_SIGN_STYLE=Automatic \
		build

build-release: ## Build the project for release
	@echo "$(BLUE)Building $(PROJECT_NAME) for release...$(NC)"
	./Scripts/generate_info_plist.sh
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-destination $(DESTINATION) \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		PRODUCT_BUNDLE_IDENTIFIER=$(PRODUCT_BUNDLE_IDENTIFIER) \
		TEST_BUNDLE_IDENTIFIER=$(TEST_BUNDLE_IDENTIFIER) \
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

# Test targets
test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	xcodebuild test \
		-project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

test-coverage: ## Generate test coverage report
	@echo "$(BLUE)Generating test coverage report...$(NC)"
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-enableCodeCoverage YES \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		test

test-specific: ## Run specific test (usage: make test-specific TEST=TestClassName)
	@echo "$(BLUE)Running specific test: $(TEST)...$(NC)"
	@if [ -z "$(TEST)" ]; then \
		echo "$(RED)Error: Please specify TEST=TestClassName$(NC)"; \
		exit 1; \
	fi
	xcodebuild test \
		-project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		-only-testing:ModSwitchIMETests/$(TEST)

# Code quality targets
lint: ## Run SwiftLint
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

# Archive and distribution targets
archive: ## Create an archive for distribution
	@echo "$(BLUE)Creating archive...$(NC)"
	@mkdir -p $(BUILD_DIR)
	./Scripts/generate_export_options.sh
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-destination $(DESTINATION) \
		-archivePath $(ARCHIVE_PATH) \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		MARKETING_VERSION=$(VERSION) \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) \
		archive

package: archive ## Export the app from archive
	@echo "$(BLUE)Exporting app...$(NC)"
	@mkdir -p $(EXPORT_PATH)
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist ExportOptions.plist

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
	@echo "$(BLUE)Signing DMG...$(NC)"
	codesign --force --sign "Developer ID Application" "$(DMG_PATH)" -v

notarize: ## Notarize the DMG (requires APPLE_ID and APPLE_PASSWORD)
	@echo "$(BLUE)Notarizing DMG...$(NC)"
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

dev-install: build ## Build and install development version (faster, keeps permissions)
	@echo "$(BLUE)Installing development build to /Applications...$(NC)"
	@BUILD_PATH=$$(xcodebuild -project $(XCODE_PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION_DEBUG) -showBuildSettings | grep -E '^\s*BUILT_PRODUCTS_DIR' | awk '{print $$3}'); \
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
		exit 1; \
	fi

# Utility targets
clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	xcodebuild -project $(XCODE_PROJECT) -scheme $(SCHEME) clean

clean-all: clean ## Clean all artifacts including caches
	@echo "$(BLUE)Cleaning all artifacts...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -rf ~/Library/Developer/Xcode/DerivedData/$(PROJECT_NAME)-*

version: ## Show current version information
	@echo "$(BLUE)Version Information:$(NC)"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Build: $(BUILD_NUMBER)"
	@echo "Git commit: $(shell git rev-parse --short HEAD 2>/dev/null || echo "N/A")"
	@echo "Git branch: $(shell git branch --show-current 2>/dev/null || echo "N/A")"

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

# Release targets
release: clean lint test archive package dmg ## Full release build
	@echo "$(GREEN)Release build completed successfully!$(NC)"
	@echo "$(BLUE)Artifacts created:$(NC)"
	@ls -la $(BUILD_DIR)

.DEFAULT_GOAL := help