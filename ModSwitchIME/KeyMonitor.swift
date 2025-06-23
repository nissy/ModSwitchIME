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
        
        // Privacy protection: Only monitor modifier key events (flagsChanged)
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        
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
        
        Logger.info("KeyMonitor stopped", category: .keyboard)
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Record activity
        lastActivityTime = CFAbsoluteTimeGetCurrent()
        
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
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
        
        let isKeyDown: Bool
        if currentlyPressed && !wasAlreadyPressed {
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
        
        Logger.info(
            "\(modifierKey.displayName) flags changed - isKeyDown: \(isKeyDown), flags: \(flags.rawValue), keyFlag: \(modifierKey.flagMask.rawValue)",
            category: .keyboard
        )
        
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
            
            Logger.debug(
                "\(modifierKey.displayName) down - hasIME: \(hasIME), otherKeysWithIME: \(otherKeysWithIME.map { $0.displayName })",
                category: .keyboard
            )
            
            // Multi-key press detection: ONLY when BOTH the current key AND at least one other key have IME configured
            // This ensures we only trigger multi-key for IME-configured key combinations
            if hasIME && !otherKeysWithIME.isEmpty {
                // This is a valid multi-key press: current key + other IME-configured keys
                lastPressedKey = modifierKey
                
                // CLEAR multiKeyPressKeys first, then add currently pressed keys
                multiKeyPressKeys.removeAll()
                multiKeyPressKeys.insert(modifierKey)
                for key in otherKeysWithIME {
                    multiKeyPressKeys.insert(key)
                }
                
                Logger.info(
                    "Multi-key press detected: \(modifierKey.displayName) is the latest key, " +
                    "multiKeyPressKeys: \(multiKeyPressKeys.map { $0.displayName })",
                    category: .keyboard
                )
                
                // Get current IME before switching
                let currentIME = imeController.getCurrentInputSource()
                
                // Switch to the IME of the LAST PRESSED key (modifierKey is the latest)
                if let targetIME = preferences.getIME(for: modifierKey) {
                    // Only switch if it's different from current IME
                    if currentIME != targetIME {
                        Logger.info("Multi-key IME switch: \(modifierKey.displayName) -> \(targetIME)", category: .keyboard)
                        imeController.switchToSpecificIME(targetIME)
                    } else {
                        Logger.debug("Multi-key press skipped: already on target IME \(targetIME)", category: .keyboard)
                    }
                }
            } else {
                // Not a multi-key press scenario
                // Either this key has no IME, or no other IME-configured keys are pressed
                lastPressedKey = modifierKey
                Logger.debug(
                    "\(modifierKey.displayName) down - not multi-key (hasIME: \(hasIME), otherIMEKeys: \(otherKeysWithIME.count))",
                    category: .keyboard
                )
            }
        } else {
            // Key up: check if we should switch IME
            let pressTime = keyPressTimestamps[modifierKey]
            keyPressTimestamps.removeValue(forKey: modifierKey)
            
            Logger.debug(
                "\(modifierKey.displayName) up - keyPressTimestamps after removal: \(keyPressTimestamps.keys.map { $0.displayName })",
                category: .keyboard
            )
            
            handleKeyRelease(modifierKey: modifierKey, pressTime: pressTime, event: event)
            
            // Remove this key from multiKeyPressKeys AFTER handling the release
            multiKeyPressKeys.remove(modifierKey)
            
            // Clean up multiKeyPressKeys: remove any keys that are no longer pressed
            multiKeyPressKeys = multiKeyPressKeys.filter { keyPressTimestamps[$0] != nil }
            
            Logger.debug(
                "\(modifierKey.displayName) up - multiKeyPressKeys after cleanup: \(multiKeyPressKeys.map { $0.displayName })",
                category: .keyboard
            )
            
            // IMPORTANT: For left/right Command keys that share the same flagMask,
            // we need to ensure both are removed when flags indicate no Command keys are pressed
            if modifierKey.flagMask == .maskCommand && !flags.contains(.maskCommand) {
                // No Command keys are pressed according to flags, remove both if they exist
                let commandKeysToRemove = keyPressTimestamps.keys.filter { $0.flagMask == .maskCommand }
                for key in commandKeysToRemove {
                    Logger.debug(
                        "Force removing Command key: \(key.displayName) due to flag state",
                        category: .keyboard
                    )
                    keyPressTimestamps.removeValue(forKey: key)
                    multiKeyPressKeys.remove(key)
                }
            }
            
            // Clear lastPressedKey when all keys are released
            if keyPressTimestamps.isEmpty {
                lastPressedKey = nil
                // Ensure multiKeyPressKeys is completely clear when no keys are pressed
                multiKeyPressKeys.removeAll()
                Logger.debug("All keys released - cleared all state", category: .keyboard)
            }
        }
    }
    
    private func handleKeyRelease(modifierKey: ModifierKey, pressTime: CFAbsoluteTime?, event: CGEvent) {
        // Check if IME is configured for this key
        guard let targetIME = preferences.getIME(for: modifierKey),
              preferences.isKeyEnabled(modifierKey) else {
            Logger.debug("\(modifierKey.displayName) up - no IME configured or disabled", category: .keyboard)
            return
        }
        
        // Check if we have a valid press time
        guard let pressTime = pressTime else {
            Logger.warning("Key release without corresponding press: \(modifierKey.displayName)", category: .keyboard)
            return
        }
        
        let now = CFAbsoluteTimeGetCurrent()
        let pressDuration = now - pressTime
        
        // Check if other keys are currently pressed
        let otherKeysPressed = !keyPressTimestamps.isEmpty  // We already removed the current key
        
        Logger.info(
            "\(modifierKey.displayName) up - duration: \(Int(pressDuration * 1000))ms, otherKeys: \(otherKeysPressed), target: \(targetIME)",
            category: .keyboard
        )
        
        // IME switching rules:
        // 1. For single key press: switch on release if no other keys are pressed (any duration)
        // 2. For multi-key press: NEVER switch on release (already switched on key down)
        
        let wasInvolvedInMultiKeyPress = multiKeyPressKeys.contains(modifierKey)
        
        Logger.debug(
            "\(modifierKey.displayName) release check - wasInvolvedInMultiKeyPress: \(wasInvolvedInMultiKeyPress), " +
            "multiKeyPressKeys: \(multiKeyPressKeys.map { $0.displayName }), otherKeysPressed: \(otherKeysPressed), " +
            "pressDuration: \(Int(pressDuration * 1000))ms",
            category: .keyboard
        )
        
        if !otherKeysPressed && !wasInvolvedInMultiKeyPress {
            // Single key press scenario
            let currentIME = imeController.getCurrentInputSource()
            
            // Only switch if it's different from current IME
            if currentIME != targetIME {
                Logger.info("Single key IME switch: \(modifierKey.displayName) -> \(targetIME)", category: .keyboard)
                
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
                Logger.debug("Single key switch skipped: already on target IME \(targetIME)", category: .keyboard)
            }
        } else if otherKeysPressed {
            Logger.debug("IME switch skipped: other keys still pressed", category: .keyboard)
        } else if wasInvolvedInMultiKeyPress {
            Logger.debug(
                "IME switch skipped: \(modifierKey.displayName) was involved in multi-key press",
                category: .keyboard
            )
        } else {
            Logger.debug("IME switch skipped: other keys are still pressed", category: .keyboard)
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
        Logger.debug("clearStuckModifierState called", category: .keyboard)
    }
    
    // MARK: - Idle Timer
    
    private func startIdleTimer() {
        guard preferences.idleOffEnabled else {
            Logger.debug("Idle timer not started: idleOffEnabled is false", category: .keyboard)
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
        Logger.debug("Stopping idle timer", category: .keyboard)
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
        
        Logger.debug(
            "Checking idle timeout: idle for \(idleTime)s, timeout: \(preferences.idleTimeout)s",
            category: .keyboard
        )
        
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
                Logger.debug("idleOffEnabled changed to: \(enabled)", category: .keyboard)
                self?.handleIdleEnabledChange(enabled)
            }
            .store(in: &cancellables)
        
        preferences.$idleTimeout
            .removeDuplicates()
            .sink { [weak self] timeout in
                Logger.debug("idleTimeout changed to: \(timeout)", category: .keyboard)
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
            Logger.debug("Force sync removed: \(key.displayName)", category: .keyboard)
        }
        
        if keyPressTimestamps.isEmpty {
            lastPressedKey = nil
            multiKeyPressKeys.removeAll()
            Logger.debug("Force sync cleared all state", category: .keyboard)
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
