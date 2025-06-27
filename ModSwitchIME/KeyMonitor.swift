import Foundation
import CoreGraphics
import Carbon
import Combine

class KeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let imeController: IMEControlling
    private let preferences: Preferences
    
    init(preferences: Preferences = Preferences.shared, imeController: IMEControlling = ImeController.shared) {
        self.preferences = preferences
        self.imeController = imeController
    }
    private var isRunning = false
    private var cancellables = Set<AnyCancellable>()
    
    // Error handling and retry
    private var retryCount = 0
    private let maxRetries = 5
    private var retryTimer: Timer?
    var onError: ((ModSwitchIMEError) -> Void)?
    
    // Optimized state management using a single struct
    private struct ModifierKeyState {
        var downTime: CFAbsoluteTime
        var isInMultiKeyPress: Bool = false
        var hadNonModifierPress: Bool = false
    }
    
    // Single dictionary for all key states (faster than multiple collections)
    // Protected by serial queue for thread safety
    private let stateQueue = DispatchQueue(label: "com.nissy.ModSwitchIME.keyStateQueue")
    private var keyStates: [ModifierKey: ModifierKeyState] = [:]
    private var lastPressedKey: ModifierKey?
    private var nonModifierKeyPressed = false  // Track if any non-modifier key is pressed
    
    // Idle timer related
    private var idleTimer: Timer?
    private var lastActivityTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    // Event tap health monitoring
    private var eventTapHealthTimer: Timer?
    private var lastEventTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private let eventTapHealthCheckInterval: TimeInterval = 5.0
    private let eventTapInactivityThreshold: TimeInterval = 30.0
    
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
                guard let refcon = refcon else {
                    Logger.error("Event callback received nil refcon", category: .keyboard)
                    return Unmanaged.passUnretained(event)
                }
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
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
        
        // Start event tap health monitoring
        startEventTapHealthMonitoring()
        
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
        
        // Stop event tap health monitoring
        stopEventTapHealthMonitoring()
        
        // Cancel retry timer
        cancelRetryTimer()
        
        // Cancel observations
        cancellables.removeAll()
        
        // Clear state
        keyStates.removeAll()
        lastPressedKey = nil
        nonModifierKeyPressed = false
        
        Logger.info("KeyMonitor stopped", category: .keyboard)
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Record activity
        lastActivityTime = CFAbsoluteTimeGetCurrent()
        lastEventTime = CFAbsoluteTimeGetCurrent()
        
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
        case .keyDown:
            // Only process if modifier keys are pressed (performance optimization)
            stateQueue.sync {
                if !keyStates.isEmpty {
                    nonModifierKeyPressed = true
                    // When non-modifier key is pressed, mark all currently pressed modifier keys
                    for key in keyStates.keys {
                        keyStates[key]?.hadNonModifierPress = true
                    }
                }
            }
        case .keyUp:
            // Only update if we were tracking non-modifier key press
            if nonModifierKeyPressed {
                nonModifierKeyPressed = false
            }
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
        // we need to determine press/release based on the presence in keyStates
        let wasAlreadyPressed = keyStates[modifierKey] != nil
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
            let otherPressedKeysWithSameFlag = keyStates.keys.filter { 
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
        if isKeyDown != (keyStates[modifierKey] != nil) {
            // Logger.debug(
            //     "\(modifierKey.displayName) \(isKeyDown ? "down" : "up")",
            //     category: .keyboard
            // )
        }
        
        if isKeyDown {
            // Key down: record state
            keyStates[modifierKey] = ModifierKeyState(downTime: now)
            
            // Check if this key has IME configured and is enabled
            let hasIME = preferences.getIME(for: modifierKey) != nil && preferences.isKeyEnabled(modifierKey)
            
            // Count other CURRENTLY pressed keys that have IME configured (excluding current key)
            // IMPORTANT: Only consider keys that are actually still pressed (in keyStates)
            let otherPressedKeys = keyStates.filter { $0.key != modifierKey }
            var otherKeysWithIME: [ModifierKey] = []
            for (key, _) in otherPressedKeys {
                if preferences.getIME(for: key) != nil && preferences.isKeyEnabled(key) {
                    otherKeysWithIME.append(key)
                }
            }
            
            // Multi-key press detection: ONLY when BOTH the current key AND at least one other key have IME configured
            if hasIME && !otherKeysWithIME.isEmpty {
                // This is a valid multi-key press: current key + other IME-configured keys
                lastPressedKey = modifierKey
                
                // Mark keys as being in multi-key press
                keyStates[modifierKey]?.isInMultiKeyPress = true
                for key in otherKeysWithIME {
                    keyStates[key]?.isInMultiKeyPress = true
                }
                
                Logger.debug(
                    "Multi-key press: \(modifierKey.displayName)",
                    category: .keyboard
                )
                
                // In multi-key scenario, always switch to the last pressed key's IME
                // (Even if it's the same key being pressed again)
                if let targetIME = preferences.getIME(for: modifierKey) {
                    Logger.debug("Multi-key IME switch: \(modifierKey.displayName) -> \(targetIME)", category: .keyboard)
                    imeController.switchToSpecificIME(targetIME)
                }
            } else {
                // Not a multi-key press scenario
                // Either this key has no IME, or no other IME-configured keys are pressed
                lastPressedKey = modifierKey
                
                // For single key press: Don't switch on key down
                // We need to wait for key up to check if other keys were pressed
                
                // Single key press - wait for key up to check if other keys were pressed
            }
        } else {
            // Key up: check if we should switch IME
            let keyState = keyStates[modifierKey]
            keyStates.removeValue(forKey: modifierKey)
            
            handleKeyRelease(modifierKey: modifierKey, keyState: keyState, event: event)
            
            // IMPORTANT: For left/right Command keys that share the same flagMask,
            // we need to ensure both are removed when flags indicate no Command keys are pressed
            if modifierKey.flagMask == .maskCommand && !flags.contains(.maskCommand) {
                // No Command keys are pressed according to flags, remove both if they exist
                let commandKeysToRemove = keyStates.keys.filter { $0.flagMask == .maskCommand }
                for key in commandKeysToRemove {
                    keyStates.removeValue(forKey: key)
                }
            }
            
            // Clear lastPressedKey when all keys are released
            if keyStates.isEmpty {
                lastPressedKey = nil
                // All keys released - clear all state
            }
        }
    }
    
    private func handleKeyRelease(modifierKey: ModifierKey, keyState: ModifierKeyState?, event: CGEvent) {
        // Check if IME is configured for this key
        guard let targetIME = preferences.getIME(for: modifierKey),
              preferences.isKeyEnabled(modifierKey) else {
            // No IME configured or disabled for this key
            return
        }
        
        // Check if we have a valid state
        guard let state = keyState else {
            Logger.warning("Key release without corresponding press: \(modifierKey.displayName)", category: .keyboard)
            return
        }
        
        // Check if other keys are currently pressed
        let otherKeysPressed = !keyStates.isEmpty  // We already removed the current key
        
        if !otherKeysPressed && !state.isInMultiKeyPress && !state.hadNonModifierPress {
            // Single key press - switch on release
            Logger.debug("Single key IME switch on release: \(modifierKey.displayName) -> \(targetIME)", category: .keyboard)
            
            // Direct switch without checking current IME for better performance
            imeController.switchToSpecificIME(targetIME)
        }
    }
    
    // MARK: - Idle Timer
    
    private func startIdleTimer() {
        guard preferences.idleOffEnabled else {
            // Idle timer not started: idleOffEnabled is false
            return
        }
        
        let interval = calculateOptimalTimerInterval()
        
        Logger.debug("Starting idle timer with interval: \(interval)s, timeout: \(preferences.idleTimeout)s", category: .keyboard)
        
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
                Logger.debug("Idle timeout reached (\(idleTime)s), switching to configured IME: \(idleIME)", category: .keyboard)
                imeController.switchToSpecificIME(idleIME)
            } else {
                Logger.debug("Idle timeout reached (\(idleTime)s), switching to English", category: .keyboard)
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
    
    // MARK: - Event Tap Health Monitoring
    
    private func startEventTapHealthMonitoring() {
        eventTapHealthTimer = Timer.scheduledTimer(withTimeInterval: eventTapHealthCheckInterval, repeats: true) { [weak self] _ in
            self?.checkEventTapHealth()
        }
    }
    
    private func stopEventTapHealthMonitoring() {
        eventTapHealthTimer?.invalidate()
        eventTapHealthTimer = nil
    }
    
    private func checkEventTapHealth() {
        let timeSinceLastEvent = CFAbsoluteTimeGetCurrent() - lastEventTime
        
        // If no events for threshold time and we're supposed to be monitoring
        if timeSinceLastEvent > eventTapInactivityThreshold && isRunning {
            Logger.warning("No events received for \(Int(timeSinceLastEvent))s, checking event tap health", category: .keyboard)
            
            // Test if event tap is still active
            if let eventTap = eventTap {
                if !CGEvent.tapIsEnabled(tap: eventTap) {
                    Logger.error("Event tap is disabled, attempting to re-enable", category: .keyboard)
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                    
                    // If still not enabled after attempt, recreate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self, let tap = self.eventTap else { return }
                        if !CGEvent.tapIsEnabled(tap: tap) {
                            Logger.error("Event tap re-enable failed, recreating event tap", category: .keyboard)
                            self.recreateEventTap()
                        } else {
                            Logger.info("Event tap successfully re-enabled", category: .keyboard)
                        }
                    }
                }
            } else {
                Logger.error("Event tap is nil, recreating", category: .keyboard)
                recreateEventTap()
            }
        }
    }
    
    private func recreateEventTap() {
        Logger.info("Recreating event tap", category: .keyboard)
        stop()
        
        // Reset retry count to allow recreation attempts
        retryCount = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.start()
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
        return stateQueue.sync {
            var timestamps: [ModifierKey: CFAbsoluteTime] = [:]
            for (key, state) in keyStates {
                timestamps[key] = state.downTime
            }
            return timestamps
        }
    }
    
    func simulateFlagsChanged(keyCode: Int64, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true) else {
            Logger.error("Failed to create CGEvent for testing", category: .keyboard)
            return
        }
        event.flags = flags
        handleFlagsChanged(event: event)
    }
    
    // Force sync state with current flags for testing
    func forceStateSync(flags: CGEventFlags) {
        stateQueue.sync {
            let keysToRemove = keyStates.keys.filter { !flags.contains($0.flagMask) }
            for key in keysToRemove {
                keyStates.removeValue(forKey: key)
            }
            
            if keyStates.isEmpty {
                lastPressedKey = nil
            }
        }
    }
    
    // Compatibility method for tests
    func getModifierKeyStates() -> [ModifierKey: (isDown: Bool, downTime: CFAbsoluteTime)] {
        // Convert current key states to the expected format
        var states: [ModifierKey: (isDown: Bool, downTime: CFAbsoluteTime)] = [:]
        for (key, state) in keyStates {
            states[key] = (isDown: true, downTime: state.downTime)
        }
        return states
    }
    
    // Removed obsolete test methods that are no longer needed
    #endif
    
    deinit {
        stop()
        // Ensure all resources are cleaned up
        cancellables.removeAll()
        keyStates.removeAll()
        cancelRetryTimer()
        stopIdleTimer()
    }
}
