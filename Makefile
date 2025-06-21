# ModSwitchIME - macOS IME Switcher
# Makefile for building, testing, and distributing ModSwitchIME

#===============================================================================
# CONFIGURATION
#===============================================================================

# Project settings
PROJECT_NAME = ModSwitchIME
SCHEME = ModSwitchIME
XCODE_PROJECT = $(PROJECT_NAME).xcodeproj
DESTINATION = "platform=macOS"

# Build configurations
CONFIGURATION_DEBUG = Debug
CONFIGURATION_RELEASE = Release

# Build directories
BUILD_DIR = build
DEV_BUILD_DIR = $(BUILD_DIR)/dev
PROD_BUILD_DIR = $(BUILD_DIR)/release
ARCHIVE_PATH = $(PROD_BUILD_DIR)/$(PROJECT_NAME).xcarchive
EXPORT_PATH = $(PROD_BUILD_DIR)/export
DMG_PATH = $(PROD_BUILD_DIR)/$(PROJECT_NAME).dmg

# Environment variables (from .envrc)
DEVELOPMENT_TEAM ?= $(DEVELOPMENT_TEAM)
PRODUCT_BUNDLE_IDENTIFIER ?= $(PRODUCT_BUNDLE_IDENTIFIER)
TEST_BUNDLE_IDENTIFIER ?= $(TEST_BUNDLE_IDENTIFIER)
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "1.0.0")
BUILD_NUMBER ?= $(shell git rev-list --count HEAD 2>/dev/null || echo "1")
APPLE_ID ?= $(APPLE_ID)
APPLE_PASSWORD ?= $(APPLE_PASSWORD)

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

#===============================================================================
# PHONY TARGETS
#===============================================================================

# Development targets
.PHONY: all help build-dev test test-coverage test-specific lint lint-fix clean-dev version status

# Production targets  
.PHONY: build archive package dmg notarize notarize-status notarize-staple release clean-release

# Common targets
.PHONY: clean clean-all

#===============================================================================
# DEFAULT & HELP
#===============================================================================

.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "$(BLUE)ModSwitchIME Makefile$(NC)"
	@echo ""
	@echo "$(YELLOW)=== Development Commands ===$(NC)"
	@echo "  $(GREEN)make build-dev$(NC)     Build and run development version"
	@echo "  $(GREEN)make test$(NC)          Run all tests"
	@echo "  $(GREEN)make lint$(NC)          Run SwiftLint"
	@echo "  $(GREEN)make clean-dev$(NC)     Clean development build"
	@echo ""
	@echo "$(YELLOW)=== Production Commands ===$(NC)"
	@echo "  $(GREEN)make build$(NC)         Build production version"
	@echo "  $(GREEN)make release$(NC)       Full release build (clean, lint, test, archive, package, dmg)"
	@echo "  $(GREEN)make notarize$(NC)      Notarize DMG for distribution"
	@echo "  $(GREEN)make clean-release$(NC) Clean release build"
	@echo ""
	@echo "$(YELLOW)All available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

all: clean test build-dev ## Default: clean, test, and build development version

#===============================================================================
# DEVELOPMENT TARGETS
#===============================================================================

build-dev: ## Build and run development version (keeps permissions)
	@echo "$(BLUE)Building $(PROJECT_NAME) for development...$(NC)"
	@echo "$(YELLOW)Team ID: $(DEVELOPMENT_TEAM)$(NC)"
	@mkdir -p $(DEV_BUILD_DIR)
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination $(DESTINATION) \
		-derivedDataPath $(DEV_BUILD_DIR)/DerivedData \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		PRODUCT_BUNDLE_IDENTIFIER="$(PRODUCT_BUNDLE_IDENTIFIER)" \
		CODE_SIGN_STYLE=Automatic \
		CODE_SIGN_IDENTITY="Apple Development" \
		build
	@echo "$(GREEN)Copying to dev directory...$(NC)"
	@BUILD_PATH=$$(xcodebuild -project $(XCODE_PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION_DEBUG) -derivedDataPath $(DEV_BUILD_DIR)/DerivedData -showBuildSettings DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) | grep -E '^\s*BUILT_PRODUCTS_DIR' | awk '{print $$3}'); \
	if [ -d "$$BUILD_PATH/$(PROJECT_NAME).app" ]; then \
		cp -R "$$BUILD_PATH/$(PROJECT_NAME).app" $(DEV_BUILD_DIR)/; \
		echo "$(GREEN)Development build available at: $(DEV_BUILD_DIR)/$(PROJECT_NAME).app$(NC)"; \
		codesign -dv --verbose=2 "$(DEV_BUILD_DIR)/$(PROJECT_NAME).app"; \
		echo "$(YELLOW)Checking for existing $(PROJECT_NAME) processes...$(NC)"; \
		EXISTING_PIDS=$$(pgrep -x $(PROJECT_NAME) || true); \
		if [ -n "$$EXISTING_PIDS" ]; then \
			echo "$(YELLOW)Stopping existing processes: $$EXISTING_PIDS$(NC)"; \
			pkill -x $(PROJECT_NAME) || true; \
			sleep 2; \
		fi; \
		echo "$(BLUE)Starting development version...$(NC)"; \
		open "$(DEV_BUILD_DIR)/$(PROJECT_NAME).app"; \
	fi

#===============================================================================
# PRODUCTION BUILD TARGETS
#===============================================================================

build: ## Build production version
	@echo "$(BLUE)Building $(PROJECT_NAME) for production...$(NC)"
	@mkdir -p $(PROD_BUILD_DIR)
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-destination $(DESTINATION) \
		-derivedDataPath $(PROD_BUILD_DIR)/DerivedData \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		PRODUCT_BUNDLE_IDENTIFIER="$(PRODUCT_BUNDLE_IDENTIFIER)" \
		TEST_BUNDLE_IDENTIFIER="$(TEST_BUNDLE_IDENTIFIER)" \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="Developer ID Application: Yoshihiko Nishida (R7LKF73J2W)" \
		OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
		CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
		build
	@echo "$(GREEN)Copying to prod directory...$(NC)"
	@BUILD_PATH=$$(xcodebuild -project $(XCODE_PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION_RELEASE) -derivedDataPath $(PROD_BUILD_DIR)/DerivedData -showBuildSettings DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) | grep -E '^\s*BUILT_PRODUCTS_DIR' | awk '{print $$3}'); \
	if [ -d "$$BUILD_PATH/$(PROJECT_NAME).app" ]; then \
		cp -R "$$BUILD_PATH/$(PROJECT_NAME).app" $(PROD_BUILD_DIR)/; \
		echo "$(GREEN)Production build available at: $(PROD_BUILD_DIR)/$(PROJECT_NAME).app$(NC)"; \
		codesign -dv --verbose=2 "$(PROD_BUILD_DIR)/$(PROJECT_NAME).app"; \
	fi

#===============================================================================
# TEST TARGETS  
#===============================================================================

test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	xcodebuild test \
		-project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

test-coverage: ## Run tests with coverage report
	@echo "$(BLUE)Running tests with coverage...$(NC)"
	xcodebuild test \
		-project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-enableCodeCoverage YES \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

test-specific: ## Run specific test (use TEST=ClassName)
	@if [ -z "$(TEST)" ]; then \
		echo "$(RED)Error: Please specify a test class with TEST=ClassName$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Running test: $(TEST)...$(NC)"
	xcodebuild test \
		-project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		-only-testing:ModSwitchIMETests/$(TEST)

#===============================================================================
# CODE QUALITY
#===============================================================================

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

#===============================================================================
# PRODUCTION DISTRIBUTION TARGETS
#===============================================================================

archive: ## Create xcarchive with Developer ID signing
	@echo "$(BLUE)Creating xcarchive...$(NC)"
	@mkdir -p $(PROD_BUILD_DIR)
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-archivePath $(ARCHIVE_PATH) \
		-destination $(DESTINATION) \
		-allowProvisioningUpdates \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		PRODUCT_BUNDLE_IDENTIFIER="$(PRODUCT_BUNDLE_IDENTIFIER)" \
		TEST_BUNDLE_IDENTIFIER="$(TEST_BUNDLE_IDENTIFIER)" \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="Developer ID Application: Yoshihiko Nishida (R7LKF73J2W)" \
		OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
		CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
		archive
	@echo "$(GREEN)Archive created at: $(ARCHIVE_PATH)$(NC)"

package: archive ## Export app from archive with Developer ID
	@echo "$(BLUE)Exporting app from archive...$(NC)"
	@mkdir -p $(EXPORT_PATH)
	@echo "$(BLUE)Creating exportOptions.plist...$(NC)"
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(EXPORT_PATH)/exportOptions.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '<plist version="1.0">' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '<dict>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '    <key>method</key>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '    <string>developer-id</string>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '    <key>teamID</key>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '    <string>$(DEVELOPMENT_TEAM)</string>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '    <key>signingCertificate</key>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '    <string>Developer ID Application</string>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '    <key>signingStyle</key>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '    <string>manual</string>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '    <key>hardened-runtime</key>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '    <true/>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '</dict>' >> $(EXPORT_PATH)/exportOptions.plist
	@echo '</plist>' >> $(EXPORT_PATH)/exportOptions.plist
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist $(EXPORT_PATH)/exportOptions.plist \
		-allowProvisioningUpdates
	@echo "$(GREEN)App exported to: $(EXPORT_PATH)/$(PROJECT_NAME).app$(NC)"
	@echo "$(BLUE)Verifying signature...$(NC)"
	@codesign -dv --verbose=2 "$(EXPORT_PATH)/$(PROJECT_NAME).app"
	@echo "$(BLUE)Copying to release directory...$(NC)"
	@rm -rf "$(PROD_BUILD_DIR)/$(PROJECT_NAME).app"
	@cp -R "$(EXPORT_PATH)/$(PROJECT_NAME).app" "$(PROD_BUILD_DIR)/"
	@echo "$(GREEN)Production app ready at: $(PROD_BUILD_DIR)/$(PROJECT_NAME).app$(NC)"

dmg: package ## Create DMG for distribution
	@echo "$(BLUE)Creating DMG...$(NC)"
	@echo "$(BLUE)Preparing DMG contents...$(NC)"
	@rm -rf "$(PROD_BUILD_DIR)/dmg_temp"
	@mkdir -p "$(PROD_BUILD_DIR)/dmg_temp"
	@cp -R "$(PROD_BUILD_DIR)/$(PROJECT_NAME).app" "$(PROD_BUILD_DIR)/dmg_temp/"
	@ln -s /Applications "$(PROD_BUILD_DIR)/dmg_temp/Applications"
	@if command -v create-dmg >/dev/null 2>&1; then \
		create-dmg \
			--volname "$(PROJECT_NAME)" \
			--window-pos 200 120 \
			--window-size 600 400 \
			--icon-size 100 \
			--icon "$(PROJECT_NAME).app" 150 200 \
			--hide-extension "$(PROJECT_NAME).app" \
			--app-drop-link 450 200 \
			--background-color "FFFFFF" \
			"$(DMG_PATH)" \
			"$(PROD_BUILD_DIR)/dmg_temp/"; \
	else \
		echo "$(YELLOW)create-dmg not found. Install with: brew install create-dmg$(NC)"; \
		echo "$(BLUE)Creating simple DMG...$(NC)"; \
		hdiutil create -volname "$(PROJECT_NAME)" -srcfolder "$(PROD_BUILD_DIR)/dmg_temp" -ov -format UDZO "$(DMG_PATH)"; \
	fi
	@rm -rf "$(PROD_BUILD_DIR)/dmg_temp"
	@echo "$(BLUE)Signing DMG...$(NC)"
	codesign --force --sign "Developer ID Application" "$(DMG_PATH)" -v

notarize: ## Submit DMG for notarization (async - returns submission ID)
	@echo "$(BLUE)Submitting DMG for notarization...$(NC)"
	@if [ -z "$(APPLE_ID)" ] || [ -z "$(APPLE_PASSWORD)" ]; then \
		echo "$(RED)Error: APPLE_ID and APPLE_PASSWORD environment variables must be set$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(DMG_PATH)" ]; then \
		echo "$(RED)Error: DMG file not found at $(DMG_PATH)$(NC)"; \
		echo "$(YELLOW)Run 'make dmg' first to create the DMG$(NC)"; \
		exit 1; \
	fi
	@SUBMISSION_ID=$$(xcrun notarytool submit "$(DMG_PATH)" \
		--apple-id "$(APPLE_ID)" \
		--password "$(APPLE_PASSWORD)" \
		--team-id "$(DEVELOPMENT_TEAM)" \
		--output-format json | grep -o '"id":"[^"]*"' | cut -d'"' -f4); \
	if [ -n "$$SUBMISSION_ID" ]; then \
		echo "$(GREEN)Submission ID: $$SUBMISSION_ID$(NC)"; \
		echo "$$SUBMISSION_ID" > $(PROD_BUILD_DIR)/notarization-id.txt; \
		echo ""; \
		echo "$(YELLOW)Next steps:$(NC)"; \
		echo "  1. Check status: make notarize-status"; \
		echo "  2. Once approved, staple: make notarize-staple"; \
		echo ""; \
		echo "$(BLUE)Or check status directly:$(NC)"; \
		echo "  xcrun notarytool info $$SUBMISSION_ID --apple-id \"$(APPLE_ID)\" --password \"$(APPLE_PASSWORD)\" --team-id \"$(DEVELOPMENT_TEAM)\""; \
	else \
		echo "$(RED)Failed to submit for notarization$(NC)"; \
		exit 1; \
	fi

notarize-status: ## Check notarization status (use SUBMISSION_ID=xxx or reads from file)
	@echo "$(BLUE)Checking notarization status...$(NC)"
	@if [ -z "$(APPLE_ID)" ] || [ -z "$(APPLE_PASSWORD)" ]; then \
		echo "$(RED)Error: APPLE_ID and APPLE_PASSWORD environment variables must be set$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(SUBMISSION_ID)" ] && [ -f "$(PROD_BUILD_DIR)/notarization-id.txt" ]; then \
		SUBMISSION_ID=$$(cat $(PROD_BUILD_DIR)/notarization-id.txt); \
	fi; \
	if [ -z "$$SUBMISSION_ID" ]; then \
		echo "$(RED)Error: No SUBMISSION_ID provided and no saved ID found$(NC)"; \
		echo "$(YELLOW)Usage: make notarize-status SUBMISSION_ID=xxx$(NC)"; \
		exit 1; \
	fi; \
	echo "$(BLUE)Submission ID: $$SUBMISSION_ID$(NC)"; \
	xcrun notarytool info "$$SUBMISSION_ID" \
		--apple-id "$(APPLE_ID)" \
		--password "$(APPLE_PASSWORD)" \
		--team-id "$(DEVELOPMENT_TEAM)"

notarize-staple: ## Staple notarization ticket to DMG after approval
	@echo "$(BLUE)Stapling notarization ticket to DMG...$(NC)"
	@if [ ! -f "$(DMG_PATH)" ]; then \
		echo "$(RED)Error: DMG file not found at $(DMG_PATH)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Checking if DMG is notarized...$(NC)"
	@if xcrun stapler staple "$(DMG_PATH)"; then \
		echo "$(GREEN)Successfully stapled notarization ticket!$(NC)"; \
		echo "$(GREEN)DMG is ready for distribution: $(DMG_PATH)$(NC)"; \
		echo ""; \
		echo "$(BLUE)Verifying stapled DMG...$(NC)"; \
		spctl -a -t open --context context:primary-signature -v "$(DMG_PATH)" || true; \
	else \
		echo "$(RED)Failed to staple notarization ticket$(NC)"; \
		echo "$(YELLOW)Make sure notarization is complete with: make notarize-status$(NC)"; \
		exit 1; \
	fi

release: clean lint test dmg ## Full release build (clean, lint, test, archive, package, dmg)
	@echo "$(GREEN)Release build complete!$(NC)"
	@echo "$(GREEN)DMG ready at: $(DMG_PATH)$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Set APPLE_ID and APPLE_PASSWORD environment variables"
	@echo "  2. Run 'make notarize' to submit DMG for notarization"
	@echo "  3. Run 'make notarize-status' to check notarization progress"
	@echo "  4. Run 'make notarize-staple' once notarization is approved"

#===============================================================================
# UTILITIES
#===============================================================================

clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	xcodebuild -project $(XCODE_PROJECT) -scheme $(SCHEME) clean

clean-all: clean ## Clean all artifacts including caches
	@echo "$(BLUE)Cleaning all artifacts...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -rf ~/Library/Developer/Xcode/DerivedData/$(PROJECT_NAME)-*

clean-dev: ## Clean development build artifacts
	@echo "$(BLUE)Cleaning development build...$(NC)"
	@rm -rf $(DEV_BUILD_DIR)

clean-release: ## Clean release build artifacts
	@echo "$(BLUE)Cleaning release build...$(NC)"
	@rm -rf $(PROD_BUILD_DIR)

version: ## Show current version information
	@echo "$(BLUE)Version Information:$(NC)"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Build: $(BUILD_NUMBER)"
	@echo "Team ID: $(DEVELOPMENT_TEAM)"
	@echo "Git commit: $(shell git rev-parse --short HEAD 2>/dev/null || echo "N/A")"
	@echo "Git branch: $(shell git branch --show-current 2>/dev/null || echo "N/A")"

status: ## Show project status
	@echo "$(BLUE)Project Status:$(NC)"
	@echo ""
	@echo "$(YELLOW)Git status:$(NC)"
	@git status --short || echo "Not a git repository"
	@echo ""
	@echo "$(YELLOW)Build artifacts:$(NC)"
	@ls -la $(BUILD_DIR) 2>/dev/null || echo "No build artifacts"
	@echo ""
	@echo "$(YELLOW)Development Team:$(NC)"
	@echo "$(DEVELOPMENT_TEAM)"
	@echo ""
	@echo "$(YELLOW)Installed version:$(NC)"
	@if [ -d "/Applications/$(PROJECT_NAME).app" ]; then \
		defaults read "/Applications/$(PROJECT_NAME).app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Cannot read version"; \
	else \
		echo "Not installed"; \
	fi