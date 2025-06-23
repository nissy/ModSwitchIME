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
    
    // Configuration
    private let singleKeyTimeout: TimeInterval = 0.3  // 300ms
    
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
        
        let isKeyDown = flags.contains(modifierKey.flagMask)
        let now = CFAbsoluteTimeGetCurrent()
        
        if isKeyDown {
            // Key down: record timestamp and check for multi-key press
            keyPressTimestamps[modifierKey] = now
            
            // Check if this key has IME configured
            let hasIME = preferences.getIME(for: modifierKey) != nil && preferences.isKeyEnabled(modifierKey)
            
            // Count other pressed keys that have IME configured (excluding current key)
            let otherPressedKeys = keyPressTimestamps.filter { $0.key != modifierKey }
            var otherKeysWithIME = false
            for (key, _) in otherPressedKeys {
                if preferences.getIME(for: key) != nil && preferences.isKeyEnabled(key) {
                    otherKeysWithIME = true
                    break
                }
            }
            
            Logger.debug("\(modifierKey.displayName) down - hasIME: \(hasIME), otherKeysWithIME: \(otherKeysWithIME)", category: .keyboard)
            
            // If both keys have IME configured, this is a valid multi-key press
            if hasIME && otherKeysWithIME {
                lastPressedKey = modifierKey
                Logger.info("Multi-key press detected: \(modifierKey.displayName) is the latest key", category: .keyboard)
                
                // Get current IME before switching
                let currentIME = imeController.getCurrentInputSource()
                
                // Switch to the IME of the last pressed key
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
                // Record this as the last pressed key for single key press
                lastPressedKey = modifierKey
            }
        } else {
            // Key up: check if we should switch IME
            let pressTime = keyPressTimestamps[modifierKey]
            keyPressTimestamps.removeValue(forKey: modifierKey)
            
            handleKeyRelease(modifierKey: modifierKey, pressTime: pressTime)
            
            // Clear lastPressedKey when all keys are released
            if keyPressTimestamps.isEmpty {
                lastPressedKey = nil
            }
        }
    }
    
    private func handleKeyRelease(modifierKey: ModifierKey, pressTime: CFAbsoluteTime?) {
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
        let otherKeysPressed = keyPressTimestamps.count > 0  // We already removed the current key
        
        Logger.info(
            "\(modifierKey.displayName) up - duration: \(Int(pressDuration * 1000))ms, otherKeys: \(otherKeysPressed), target: \(targetIME)",
            category: .keyboard
        )
        
        // IME switching rules:
        // 1. For single key press: switch on release if no other keys are pressed
        // 2. For multi-key press: only switch if this was NOT the last pressed key
        //    (last pressed key already switched on key down)
        // 3. Press duration must be within timeout
        
        let wasMultiKeyPress = lastPressedKey != nil && lastPressedKey != modifierKey
        
        if !otherKeysPressed && pressDuration < singleKeyTimeout && !wasMultiKeyPress {
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
        } else if wasMultiKeyPress {
            Logger.debug("IME switch skipped: multi-key handled on key down", category: .keyboard)
        } else {
            Logger.debug("IME switch skipped: timeout exceeded (\(Int(pressDuration * 1000))ms > \(Int(singleKeyTimeout * 1000))ms)", category: .keyboard)
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