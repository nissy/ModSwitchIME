import Foundation
import CoreGraphics
import Carbon
import Combine

class KeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var imeController = ImeController()
    private let preferences: Preferences
    
    init(preferences: Preferences = Preferences.shared) {
        self.preferences = preferences
    }
    private var isRunning = false
    private var cancellables = Set<AnyCancellable>()
    
    // Error handling and retry
    private var retryCount = 0
    private let maxRetries = 5
    private var retryTimer: Timer?
    var onError: ((ModSwitchIMEError) -> Void)?
    
    // Minimal state: track key press timestamps and order
    private var keyPressTimestamps: [ModifierKey: CFAbsoluteTime] = [:]
    private var lastPressedKey: ModifierKey?
    private var multiKeyPressKeys: Set<ModifierKey> = []  // Track all keys involved in multi-key press
    private var isFirstKeyPress = true  // Track if this is the very first key press
    private var nonModifierKeyPressed = false  // Track if any non-modifier key is pressed
    private var modifierKeysWithNonModifierPress: Set<ModifierKey> = []  // Track which modifier keys had non-modifier keys pressed during their hold
    
    // Idle timer related
    private var idleTimer: Timer?
    private var lastActivityTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    // Debug
    var isIdleTimerRunning: Bool {
        return idleTimer != nil
    }
    
    // Public property to check if KeyMonitor is running
    var isMonitoring: Bool {
        return isRunning
    }
    
    func start() {
        if isRunning {
            return
        }
        
        Logger.info("KeyMonitor.start() called", category: .keyboard)
        
        // Check accessibility permission
        if !AccessibilityManager.shared.hasPermission {
            Logger.warning("KeyMonitor cannot start without accessibility permission", category: .keyboard)
            return
        }
        
        // Monitor modifier keys and regular key events to detect shortcuts
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) |
                       (1 << CGEventType.keyDown.rawValue) |
                       (1 << CGEventType.keyUp.rawValue)
        
        // Create event tap
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.error("Failed to create event tap (attempt \(retryCount + 1)/\(maxRetries))", category: .keyboard)
            handleEventTapCreationFailure()
            return
        }
        
        self.eventTap = eventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        // Add to run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        isRunning = true
        retryCount = 0
        cancelRetryTimer()
        Logger.info("KeyMonitor started successfully", category: .keyboard)
        
        // Start idle timer
        startIdleTimer()
        
        // Observe preference changes
        observePreferenceChanges()
    }
    
    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        
        // Stop idle timer
        stopIdleTimer()
        
        // Cancel retry timer
        cancelRetryTimer()
        
        // Cancel observations
        cancellables.removeAll()
        
        // Clear state
        keyPressTimestamps.removeAll()
        lastPressedKey = nil
        multiKeyPressKeys.removeAll()
        nonModifierKeyPressed = false
        modifierKeysWithNonModifierPress.removeAll()
        
        Logger.info("KeyMonitor stopped", category: .keyboard)
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Record activity
        lastActivityTime = CFAbsoluteTimeGetCurrent()
        
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
        case .keyDown:
            nonModifierKeyPressed = true
            // When non-modifier key is pressed, mark all currently pressed modifier keys
            for (key, _) in keyPressTimestamps {
                modifierKeysWithNonModifierPress.insert(key)
            }
            // Non-modifier key pressed - don't log content for privacy
        case .keyUp:
            nonModifierKeyPressed = false
            // Non-modifier key released
        case .tapDisabledByTimeout:
            Logger.error("Event tap disabled by timeout", category: .keyboard)
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                onError?(.eventTapDisabled(automatic: true))
            }
        case .tapDisabledByUserInput:
            Logger.error("Event tap disabled by user input", category: .keyboard)
            onError?(.eventTapDisabled(automatic: false))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                if let eventTap = self?.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
            }
        default:
            break
        }
        
        // Return the original event unchanged
        return Unmanaged.passUnretained(event)
    }
    
    private func handleFlagsChanged(event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        guard let modifierKey = ModifierKey.from(keyCode: keyCode) else {
            return
        }
        
        // IMPORTANT: For left/right keys that share the same flag mask (like leftCommand/rightCommand),
        // we need to determine press/release based on the presence in keyPressTimestamps
        let wasAlreadyPressed = keyPressTimestamps[modifierKey] != nil
        let currentlyPressed = flags.contains(modifierKey.flagMask)
        
        // For Command keys (and other pairs that share flagMask), we need special handling
        let isSharedFlagKey = (modifierKey.flagMask == .maskCommand || 
                              modifierKey.flagMask == .maskShift || 
                              modifierKey.flagMask == .maskControl || 
                              modifierKey.flagMask == .maskAlternate)
        
        let isKeyDown: Bool
        if isSharedFlagKey && wasAlreadyPressed {
            // For shared flag keys, if the key was already pressed and we get an event for it,
            // it's likely a release (since macOS sends events for both press and release)
            // We'll determine based on the current state and other pressed keys
            let otherPressedKeysWithSameFlag = keyPressTimestamps.keys.filter { 
                $0 != modifierKey && $0.flagMask == modifierKey.flagMask 
            }
            
            if otherPressedKeysWithSameFlag.isEmpty {
                // No other key with same flag is pressed, so flag state determines press/release
                isKeyDown = currentlyPressed
            } else {
                // Other keys with same flag are pressed, this is likely a release
                isKeyDown = false
            }
        } else if currentlyPressed && !wasAlreadyPressed {
            // Key down: flag is set and key wasn't previously pressed
            isKeyDown = true
        } else if !currentlyPressed && wasAlreadyPressed {
            // Key up: flag is not set and key was previously pressed
            isKeyDown = false
        } else if currentlyPressed && wasAlreadyPressed {
            // Key is still down (no change)
            return // No action needed
        } else {
            // Key is still up (no change)
            return // No action needed
        }
        let now = CFAbsoluteTimeGetCurrent()
        
        // Log only essential information for debugging
        if isKeyDown != (keyPressTimestamps[modifierKey] != nil) {
            Logger.debug(
                "\(modifierKey.displayName) \(isKeyDown ? "down" : "up")",
                category: .keyboard
            )
        }
        
        if isKeyDown {
            // Key down: record timestamp and check for multi-key press
            keyPressTimestamps[modifierKey] = now
            
            // Check if this key has IME configured and is enabled
            let hasIME = preferences.getIME(for: modifierKey) != nil && preferences.isKeyEnabled(modifierKey)
            
            // Count other CURRENTLY pressed keys that have IME configured (excluding current key)
            // IMPORTANT: Only consider keys that are actually still pressed (in keyPressTimestamps)
            let otherPressedKeys = keyPressTimestamps.filter { $0.key != modifierKey }
            var otherKeysWithIME: [ModifierKey] = []
            for (key, _) in otherPressedKeys {
                if preferences.getIME(for: key) != nil && preferences.isKeyEnabled(key) {
                    otherKeysWithIME.append(key)
                }
            }
            
            // Debug log removed - too verbose
            
            // Multi-key press detection: ONLY when BOTH the current key AND at least one other key have IME configured
            // This ensures we only trigger multi-key for IME-configured key combinations
            if hasIME && !otherKeysWithIME.isEmpty {
                // Check if this is a new multi-key combination (not already in multi-key state)
                // Check if this is a new multi-key combination
                
                // This is a valid multi-key press: current key + other IME-configured keys
                lastPressedKey = modifierKey
                
                // Add to multiKeyPressKeys
                multiKeyPressKeys.insert(modifierKey)
                for key in otherKeysWithIME {
                    multiKeyPressKeys.insert(key)
                }
                
                Logger.info(
                    "Multi-key press: \(modifierKey.displayName)",
                    category: .keyboard
                )
                
                // In multi-key scenario, always switch to the last pressed key's IME
                // (Even if it's the same key being pressed again)
                if let targetIME = preferences.getIME(for: modifierKey) {
                    Logger.info("Multi-key IME switch: \(modifierKey.displayName) -> \(targetIME)", category: .keyboard)
                    imeController.switchToSpecificIME(targetIME)
                }
            } else {
                // Not a multi-key press scenario
                // Either this key has no IME, or no other IME-configured keys are pressed
                lastPressedKey = modifierKey
                
                // For single key press: Don't switch on key down
                // We need to wait for key up to check if other keys were pressed
                
                // Clear the first key press flag if this is the first key
                if isFirstKeyPress && otherPressedKeys.isEmpty {
                    isFirstKeyPress = false
                }
                
                // Single key press - debug log removed
            }
        } else {
            // Key up: check if we should switch IME
            let pressTime = keyPressTimestamps[modifierKey]
            keyPressTimestamps.removeValue(forKey: modifierKey)
            
            // Key released - state updated
            
            handleKeyRelease(modifierKey: modifierKey, pressTime: pressTime, event: event)
            
            // Remove this key from multiKeyPressKeys AFTER handling the release
            multiKeyPressKeys.remove(modifierKey)
            modifierKeysWithNonModifierPress.remove(modifierKey)
            
            // Clean up multiKeyPressKeys: remove any keys that are no longer pressed
            multiKeyPressKeys = multiKeyPressKeys.filter { keyPressTimestamps[$0] != nil }
            
            
            // Multi-key cleanup complete
            
            // IMPORTANT: For left/right Command keys that share the same flagMask,
            // we need to ensure both are removed when flags indicate no Command keys are pressed
            if modifierKey.flagMask == .maskCommand && !flags.contains(.maskCommand) {
                // No Command keys are pressed according to flags, remove both if they exist
                let commandKeysToRemove = keyPressTimestamps.keys.filter { $0.flagMask == .maskCommand }
                for key in commandKeysToRemove {
                    // Force removing Command key due to flag state
                    keyPressTimestamps.removeValue(forKey: key)
                    multiKeyPressKeys.remove(key)
                    modifierKeysWithNonModifierPress.remove(key)
                }
            }
            
            // Clear lastPressedKey when all keys are released
            if keyPressTimestamps.isEmpty {
                lastPressedKey = nil
                // Ensure multiKeyPressKeys is completely clear when no keys are pressed
                multiKeyPressKeys.removeAll()
                // Clear all modifier keys that had non-modifier presses
                modifierKeysWithNonModifierPress.removeAll()
                // Reset first key press flag when all keys are released
                isFirstKeyPress = true
                // All keys released - cleared all state
            }
        }
    }
    
    private func handleKeyRelease(modifierKey: ModifierKey, pressTime: CFAbsoluteTime?, event: CGEvent) {
        // Check if IME is configured for this key
        guard let targetIME = preferences.getIME(for: modifierKey),
              preferences.isKeyEnabled(modifierKey) else {
            // No IME configured or disabled for this key
            return
        }
        
        // Check if we have a valid press time
        guard pressTime != nil else {
            Logger.warning("Key release without corresponding press: \(modifierKey.displayName)", category: .keyboard)
            return
        }
        
        // Check if other keys are currently pressed
        let otherKeysPressed = !keyPressTimestamps.isEmpty  // We already removed the current key
        
        // Process key release with duration and target IME
        
        // IME switching rules:
        // 1. For single key press: switch on release if no other keys are pressed (any duration)
        // 2. For multi-key press: NEVER switch on release (already switched on key down)
        
        let wasInvolvedInMultiKeyPress = multiKeyPressKeys.contains(modifierKey)
        
        // Check if this modifier key had any non-modifier key pressed during its hold
        let hadNonModifierKeyPress = modifierKeysWithNonModifierPress.contains(modifierKey)
        
        // Check if IME switch should occur on release
        
        if !otherKeysPressed && !wasInvolvedInMultiKeyPress && !hadNonModifierKeyPress {
            // Single key press scenario - switch on release only if no non-modifier key was pressed during the hold
            let currentIME = imeController.getCurrentInputSource()
            
            // Only switch if it's different from current IME
            if currentIME != targetIME {
                Logger.info("Single key IME switch on release: \(modifierKey.displayName) -> \(targetIME)", category: .keyboard)
                
                // Clear any stuck state before switching
                if keyPressTimestamps.isEmpty {
                    clearStuckModifierState()
                }
                
                imeController.switchToSpecificIME(targetIME)
                
                // Ensure event tap is in good state after switching
                if keyPressTimestamps.isEmpty {
                    ensureEventTapActive()
                }
            } else {
                // Single key switch skipped: already on target IME
            }
        } else if otherKeysPressed {
            // IME switch skipped: other keys still pressed
        } else if wasInvolvedInMultiKeyPress {
            // IME switch skipped: was involved in multi-key press
        } else {
            // IME switch skipped: other keys are still pressed
        }
    }
    
    private func ensureEventTapActive() {
        // Ensure the event tap is still active and functioning
        if let eventTap = eventTap {
            let isEnabled = CGEvent.tapIsEnabled(tap: eventTap)
            if !isEnabled {
                Logger.warning("Event tap was disabled, re-enabling", category: .keyboard)
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            
            // Force clear any stuck modifier state by posting dummy events
            clearStuckModifierState()
        }
    }
    
    private func clearStuckModifierState() {
        // Currently no-op. Reserved for future use if needed.
        // clearStuckModifierState called - currently no-op
    }
    
    // MARK: - Idle Timer
    
    private func startIdleTimer() {
        guard preferences.idleOffEnabled else {
            // Idle timer not started: idleOffEnabled is false
            return
        }
        
        let interval = calculateOptimalTimerInterval()
        
        Logger.info("Starting idle timer with interval: \(interval)s, timeout: \(preferences.idleTimeout)s", category: .keyboard)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.idleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.checkIdleTimeout()
            }
        }
    }
    
    private func calculateOptimalTimerInterval() -> TimeInterval {
        let timeout = preferences.idleTimeout
        
        if timeout <= 5 {
            return 0.5
        } else if timeout <= 30 {
            return 1.0
        } else if timeout <= 60 {
            return 2.0
        } else {
            return 5.0
        }
    }
    
    private func stopIdleTimer() {
        // Stop idle timer
        DispatchQueue.main.async { [weak self] in
            self?.idleTimer?.invalidate()
            self?.idleTimer = nil
        }
    }
    
    private func checkIdleTimeout() {
        guard preferences.idleOffEnabled else {
            stopIdleTimer()
            return
        }
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        let idleTime = currentTime - lastActivityTime
        
        // Check if idle timeout is reached
        
        if idleTime >= preferences.idleTimeout {
            if let idleIME = preferences.idleReturnIME {
                Logger.info("Idle timeout reached (\(idleTime)s), switching to configured IME: \(idleIME)", category: .keyboard)
                imeController.switchToSpecificIME(idleIME)
            } else {
                Logger.info("Idle timeout reached (\(idleTime)s), switching to English", category: .keyboard)
                imeController.forceAscii()
            }
            lastActivityTime = currentTime
        }
    }
    
    // MARK: - Preference Observation
    
    private func observePreferenceChanges() {
        preferences.$idleOffEnabled
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                // idleOffEnabled changed
                self?.handleIdleEnabledChange(enabled)
            }
            .store(in: &cancellables)
        
        preferences.$idleTimeout
            .removeDuplicates()
            .sink { [weak self] _ in
                // idleTimeout changed
                guard let self = self else { return }
                if self.preferences.idleOffEnabled && self.idleTimer != nil {
                    self.stopIdleTimer()
                    self.startIdleTimer()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleIdleEnabledChange(_ enabled: Bool) {
        if enabled {
            if idleTimer == nil {
                startIdleTimer()
            }
        } else {
            stopIdleTimer()
        }
    }
    
    // MARK: - Error Handling
    
    private func handleEventTapCreationFailure() {
        let error = ModSwitchIMEError.eventTapCreationFailed(
            reason: retryCount < maxRetries ? "Attempting retry..." : "Maximum retries exceeded"
        )
        onError?(error)
        
        if retryCount < maxRetries {
            retryCount += 1
            let delay = Double(retryCount) * 2.0
            
            Logger.info("Scheduling retry #\(retryCount) in \(delay) seconds", category: .keyboard)
            
            retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                Logger.info("Retrying event tap creation...", category: .keyboard)
                self.start()
            }
        } else {
            Logger.error("Failed to create event tap after \(maxRetries) attempts", category: .keyboard)
        }
    }
    
    private func cancelRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    // MARK: - Testing Support
    #if DEBUG
    func getKeyPressTimestamps() -> [ModifierKey: CFAbsoluteTime] {
        return keyPressTimestamps
    }
    
    func setImeController(_ controller: ImeController) {
        self.imeController = controller
    }
    
    func simulateFlagsChanged(keyCode: Int64, flags: CGEventFlags) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)!
        event.flags = flags
        handleFlagsChanged(event: event)
    }
    
    // Force sync state with current flags for testing
    func forceStateSync(flags: CGEventFlags) {
        let keysToRemove = keyPressTimestamps.keys.filter { !flags.contains($0.flagMask) }
        for key in keysToRemove {
            keyPressTimestamps.removeValue(forKey: key)
            multiKeyPressKeys.remove(key)
            modifierKeysWithNonModifierPress.remove(key)
            // Force sync removed key
        }
        
        if keyPressTimestamps.isEmpty {
            lastPressedKey = nil
            multiKeyPressKeys.removeAll()
            modifierKeysWithNonModifierPress.removeAll()
            // Force sync cleared all state
        }
    }
    
    // Compatibility methods for tests (return dummy values since we don't track these anymore)
    func getModifierKeyStates() -> [ModifierKey: (isDown: Bool, downTime: CFAbsoluteTime)] {
        // Convert current key press timestamps to the expected format
        var states: [ModifierKey: (isDown: Bool, downTime: CFAbsoluteTime)] = [:]
        for (key, time) in keyPressTimestamps {
            states[key] = (isDown: true, downTime: time)
        }
        return states
    }
    
    func getIsValidMultiKeyPress() -> Bool {
        // In stateless architecture, we don't track this
        return false
    }
    
    func getLastPressedModifierKey() -> ModifierKey? {
        // In stateless architecture, we don't track this
        return nil
    }
    #endif
}
