import Foundation
import CoreGraphics
import Carbon
import Combine

class KeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var imeController = ImeController()
    private let preferences = Preferences.shared
    private var isRunning = false
    private var cancellables = Set<AnyCancellable>()
    
    // Error handling and retry
    private var retryCount = 0
    private let maxRetries = 5
    private var retryTimer: Timer?
    var onError: ((ModSwitchIMEError) -> Void)?
    
    // Removed cache - direct access to preferences is fast enough for 8 keys
    
    // Track modifier key states
    private var modifierKeyStates: [ModifierKey: (isDown: Bool, downTime: CFAbsoluteTime)] = [:]
    
    // Track last pressed modifier key for multi-key press handling
    private var lastPressedModifierKey: ModifierKey?
    private var isValidMultiKeyPress = false
    
    // Track consecutive multi-key issues
    private var consecutiveMultiKeyFailures = 0
    private let maxConsecutiveFailures = 3
    
    // New approach: Track the last IME switch to prevent stuck states
    private var lastIMESwitchKey: ModifierKey?
    private var lastIMESwitchTime: CFAbsoluteTime = 0
    
    // アイドルタイマー関連
    private var idleTimer: Timer?
    private var lastActivityTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    // デバッグ用
    var isIdleTimerRunning: Bool {
        return idleTimer != nil
    }
    
    // Public property to check if KeyMonitor is running
    var isMonitoring: Bool {
        return isRunning
    }
    
    // Public method to check modifier key state
    func isModifierKeyPressed(_ key: ModifierKey) -> Bool {
        return modifierKeyStates[key]?.isDown ?? false
    }
    
    // Get all pressed modifier keys
    var pressedModifierKeys: [ModifierKey] {
        return modifierKeyStates.compactMap { key, state in
            state.isDown ? key : nil
        }
    }
    
    func start() {
        // 既に実行中の場合はスキップ
        if isRunning {
            return
        }
        
        Logger.info("KeyMonitor.start() called", category: .keyboard)
        
        // No cache initialization needed
        
        // アクセシビリティ権限を確認
        if !AccessibilityManager.shared.hasPermission {
            Logger.warning("KeyMonitor cannot start without accessibility permission", category: .keyboard)
            // Don't show alert from KeyMonitor - let MenuBarApp handle it
            return
        }
        
        // Privacy protection: Only monitor modifier key events (flagsChanged)
        // This ensures we never capture regular keystrokes or text input
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        
        // イベントタップを作成（高優先度で処理）
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
        
        // Add to multiple run loop modes for better responsiveness
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        isRunning = true
        retryCount = 0  // Reset retry count on success
        cancelRetryTimer()
        Logger.info("KeyMonitor started successfully", category: .keyboard)
        
        // アイドルタイマーを開始
        startIdleTimer()
        
        // Preferencesの変更を監視
        Logger.debug("Setting up preference observation", category: .keyboard)
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
        
        // アイドルタイマーを停止
        stopIdleTimer()
        
        // リトライタイマーを停止
        cancelRetryTimer()
        
        // 監視をキャンセル
        cancellables.removeAll()
        
        Logger.info("KeyMonitor stopped", category: .keyboard)
    }
    
    // Force reset event tap to clear any stuck state
    private func resetEventTap() {
        Logger.warning("Resetting event tap to clear stuck state", category: .keyboard)
        
        // Save current running state
        let wasRunning = isRunning
        
        // Stop current event tap
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
        
        // Reset all state
        modifierKeyStates.removeAll()
        lastPressedModifierKey = nil
        isValidMultiKeyPress = false
        consecutiveMultiKeyFailures = 0
        lastIMESwitchKey = nil
        lastIMESwitchTime = 0
        
        // Restart if it was running
        if wasRunning {
            // Small delay to ensure clean restart
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.start()
            }
        }
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // アクティビティを記録
        lastActivityTime = CFAbsoluteTimeGetCurrent()
        
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
        case .tapDisabledByTimeout:
            Logger.error("Event tap disabled by timeout", category: .keyboard)
            // イベントタップを再有効化
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                onError?(.eventTapDisabled(automatic: true))
            }
        case .tapDisabledByUserInput:
            Logger.error("Event tap disabled by user input", category: .keyboard)
            onError?(.eventTapDisabled(automatic: false))
            // Attempt to re-enable after a delay
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
        // Store event data in local variables for processing
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Identify which modifier key based on keyCode
        guard let modifierKey = ModifierKey.from(keyCode: keyCode) else {
            return  // Early exit for non-modifier keys
        }
        
        // Get current state before any updates
        let currentState = modifierKeyStates[modifierKey] ?? (isDown: false, downTime: 0)
        
        // Check if the corresponding flag is set
        let isKeyDown = flags.contains(modifierKey.flagMask)
        
        // Skip if state hasn't changed
        if isKeyDown == currentState.isDown {
            // Log duplicate events for debugging
            Logger.debug("Duplicate event ignored: \(modifierKey.displayName) isDown=\(isKeyDown)", category: .keyboard)
            return  // Early exit for duplicate events
        }
        
        // Get IME mapping (may be nil)
        let targetIME = getCachedIME(for: modifierKey)
        
        // For key down, check other keys BEFORE updating state
        // For key up, check after updating (handled in handleKeyUp)
        let otherModifiersPressed: Bool
        if isKeyDown {
            // Check current state before we update it
            otherModifiersPressed = modifierKeyStates.contains { key, state in
                key != modifierKey && state.isDown
            }
        } else {
            // For key up, this value isn't used
            otherModifiersPressed = false
        }
        
        // Temporary debug logging to diagnose multi-key issues
        Logger.info(
            "\(modifierKey.displayName) event - down:\(isKeyDown), other:\(otherModifiersPressed), ime:\(targetIME ?? "nil"), enabled:\(preferences.isKeyEnabled(modifierKey))",
            category: .keyboard
        )
        
        if isKeyDown {
            handleKeyDown(
                modifierKey: modifierKey,
                otherModifiersPressed: otherModifiersPressed,
                targetIME: targetIME
            )
        } else {
            handleKeyUp(
                modifierKey: modifierKey,
                currentState: currentState,
                targetIME: targetIME
            )
        }
    }
    
    // Helper function for key down handling
    private func handleKeyDown(modifierKey: ModifierKey, otherModifiersPressed: Bool, targetIME: String?) {
        let now = CFAbsoluteTimeGetCurrent()
        
        // Update state after bounce check
        modifierKeyStates[modifierKey] = (isDown: true, downTime: now)
        
        // Check if this key has IME mapping AND is enabled
        let currentKeyIME = targetIME ?? getCachedIME(for: modifierKey)
        let currentKeyEnabled = preferences.isKeyEnabled(modifierKey)
        let currentKeyHasValidIME = currentKeyIME != nil && currentKeyEnabled
        
        // Debug current state
        let pressedKeys = modifierKeyStates.compactMap { key, state in
            state.isDown ? key.displayName : nil
        }
        Logger.info(
            "\(modifierKey.displayName) down - pressed:[\(pressedKeys.joined(separator:","))], hasIME:\(currentKeyHasValidIME)",
            category: .keyboard
        )
        
        // Quick check for other pressed keys with IME mappings AND enabled
        let otherPressedKeyWithIME = otherModifiersPressed && modifierKeyStates.contains { key, state in
            if key == modifierKey || !state.isDown {
                return false
            }
            // Check if the other key has IME mapping AND is enabled
            let otherKeyIME = preferences.getIME(for: key)
            let otherKeyEnabled = preferences.isKeyEnabled(key)
            return otherKeyIME != nil && otherKeyEnabled
        }
        
        // Debug multi-key detection with current state
        Logger.info(
            "\(modifierKey.displayName) DOWN - hasIME:\(currentKeyHasValidIME), otherPressed:\(otherModifiersPressed), " +
            "currentMultiState:\(isValidMultiKeyPress), lastPressed:\(lastPressedModifierKey?.displayName ?? "none")",
            category: .keyboard
        )
        
        // Always reset multi-key state when starting a new single key press
        if !otherModifiersPressed {
            if isValidMultiKeyPress || lastPressedModifierKey != nil {
                Logger.info("Single key press detected - resetting all multi-key state", category: .keyboard)
                isValidMultiKeyPress = false
                lastPressedModifierKey = nil
                lastIMESwitchKey = nil
                consecutiveMultiKeyFailures = 0
            }
        }
        
        // Multi-key scenario: current key has IME AND other keys are pressed
        if currentKeyHasValidIME && otherModifiersPressed {
            // Force reset if we're stuck
            let timeSinceLastSwitch = now - lastIMESwitchTime
            if lastIMESwitchKey == modifierKey && timeSinceLastSwitch < 2.0 {
                Logger.warning("Detected repeated switch to same key within 2s - forcing state reset", category: .keyboard)
                isValidMultiKeyPress = false
                lastPressedModifierKey = nil
                lastIMESwitchKey = nil
            }
            
            let previousState = isValidMultiKeyPress ? "continuing" : "new"
            Logger.info("MULTI-KEY DETECTED (\(previousState)): \(modifierKey.displayName) -> \(currentKeyIME!)", category: .keyboard)
            
            // Always trigger the switch, regardless of state
            lastPressedModifierKey = modifierKey
            isValidMultiKeyPress = true
            lastIMESwitchKey = modifierKey
            lastIMESwitchTime = now
            
            // Force IME switch without any conditions
            imeController.switchToSpecificIME(currentKeyIME!)
            Logger.info("Direct IME switch executed for \(modifierKey.displayName)", category: .keyboard)
        }
    }
    
    // Public method to force reset - can be called from MenuBarApp
    func forceReset() {
        Logger.info("Force reset requested", category: .keyboard)
        resetEventTap()
    }
    
    // Helper function for key up handling
    private func handleKeyUp(modifierKey: ModifierKey, currentState: (isDown: Bool, downTime: CFAbsoluteTime), targetIME: String?) {
        // Update state first
        modifierKeyStates[modifierKey] = (isDown: false, downTime: 0)
        
        // Check if other keys are still pressed
        let otherKeysStillPressed = modifierKeyStates.contains { key, state in
            key != modifierKey && state.isDown
        }
        
        // Additional validation: Check actual key states from the system
        let actualFlags = CGEventSource.flagsState(.combinedSessionState)
        let systemKeyDown = actualFlags.contains(modifierKey.flagMask)
        if systemKeyDown {
            Logger.warning("System reports \(modifierKey.displayName) still down, but we received key up event", category: .keyboard)
        }
        
        // Debug current state
        let stillPressedKeys = modifierKeyStates.compactMap { key, state in
            state.isDown ? key.displayName : nil
        }
        
        Logger.info(
            "\(modifierKey.displayName) UP - multi:\(isValidMultiKeyPress), othersPressed:\(otherKeysStillPressed), " +
            "lastPressed:\(lastPressedModifierKey?.displayName ?? "none"), stillPressed:[\(stillPressedKeys.joined(separator:","))], ime:\(targetIME ?? "nil")",
            category: .keyboard
        )
        
        // Handle single key press (when not in multi-key mode)
        if !isValidMultiKeyPress && targetIME != nil && preferences.isKeyEnabled(modifierKey) && !otherKeysStillPressed {
            Logger.info("SINGLE-KEY up: \(modifierKey.displayName) -> \(targetIME!)", category: .keyboard)
            triggerIMESwitch(modifierKey: modifierKey, downTime: currentState.downTime, targetIME: targetIME!)
        }
        
        // More conservative multi-key state reset
        if isValidMultiKeyPress {
            if !otherKeysStillPressed {
                // All keys released - immediate reset
                Logger.info("Multi-key reset: all keys released", category: .keyboard)
                lastPressedModifierKey = nil
                isValidMultiKeyPress = false
                lastIMESwitchKey = nil
                lastIMESwitchTime = 0
            }
            // DO NOT reset when just the last pressed key is released while others are still pressed
            // This preserves multi-key state for consecutive presses
        }
    }
    
    // Helper function for IME switching logic
    private func triggerIMESwitch(modifierKey: ModifierKey, downTime: CFAbsoluteTime, targetIME: String) {
        // Get current IME before switch
        let currentIME = imeController.getCurrentInputSource()
        
        // Don't skip even if on target IME - force the switch
        // This helps clear any stuck internal state
        if currentIME == targetIME {
            Logger.debug("Already on target IME: \(targetIME), but forcing switch anyway", category: .keyboard)
        }
        
        Logger.info("IME SWITCH: \(modifierKey.displayName) -> \(targetIME) (current: \(currentIME))", category: .keyboard)
        
        // Switch immediately without any delays or thread synchronization
        // TIS APIs can be called from any thread safely
        imeController.switchToSpecificIME(targetIME)
        
        // Verify switch happened
        let newIME = imeController.getCurrentInputSource()
        if newIME != targetIME {
            Logger.warning("IME switch may have failed: requested \(targetIME), got \(newIME)", category: .keyboard)
            
            // Force a retry if the switch failed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                let retryIME = self?.imeController.getCurrentInputSource() ?? "Unknown"
                if retryIME != targetIME {
                    Logger.warning("IME switch retry: still not on target \(targetIME), current: \(retryIME)", category: .keyboard)
                    self?.imeController.switchToSpecificIME(targetIME)
                }
            }
        }
    }
    
    // MARK: - アイドルタイマー関連
    
    private func startIdleTimer() {
        guard preferences.idleOffEnabled else {
            Logger.debug("Idle timer not started: idleOffEnabled is false", category: .keyboard)
            return
        }
        
        // Calculate optimal timer interval based on timeout setting
        let interval = calculateOptimalTimerInterval()
        
        Logger.info("Starting idle timer with interval: \(interval)s, timeout: \(preferences.idleTimeout)s", category: .keyboard)
        
        // Ensure timer is created on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.idleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.checkIdleTimeout()
            }
            Logger.debug("Idle timer started successfully on main thread", category: .keyboard)
        }
    }
    
    private func calculateOptimalTimerInterval() -> TimeInterval {
        let timeout = preferences.idleTimeout
        
        // Use adaptive intervals based on timeout duration
        if timeout <= 5 {
            return 0.5  // Check every 0.5 seconds for short timeouts
        } else if timeout <= 30 {
            return 1.0  // Check every second for medium timeouts
        } else if timeout <= 60 {
            return 2.0  // Check every 2 seconds for longer timeouts
        } else {
            return 5.0  // Check every 5 seconds for very long timeouts
        }
    }
    
    private func stopIdleTimer() {
        Logger.debug("Stopping idle timer", category: .keyboard)
        DispatchQueue.main.async { [weak self] in
            self?.idleTimer?.invalidate()
            self?.idleTimer = nil
            Logger.debug("Idle timer stopped", category: .keyboard)
        }
    }
    
    private func checkIdleTimeout() {
        guard preferences.idleOffEnabled else {
            Logger.debug("Idle timer check skipped: idleOffEnabled is false", category: .keyboard)
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
            // タイマーを再開するために最後のアクティビティ時間を更新
            lastActivityTime = currentTime
        }
    }
    
    // MARK: - Preference観察
    
    private func observePreferenceChanges() {
        Logger.debug("observePreferenceChanges called", category: .keyboard)
        
        // Test: observe value immediately
        let currentValue = preferences.idleOffEnabled
        Logger.debug("Current idleOffEnabled value: \(currentValue)", category: .keyboard)
        
        // idleOffEnabledの変更を監視
        preferences.$idleOffEnabled
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                Logger.debug("idleOffEnabled changed to: \(enabled) (thread: \(Thread.current))", category: .keyboard)
                self?.handleIdleEnabledChange(enabled)
            }
            .store(in: &cancellables)
        
        Logger.debug(
            "idleOffEnabled subscription created, cancellables count: \(cancellables.count)",
            category: .keyboard
        )
        
        // idleTimeoutの変更も監視（タイマーが有効な場合は再起動が必要）
        preferences.$idleTimeout
            .removeDuplicates()
            .sink { [weak self] timeout in
                Logger.debug("idleTimeout changed to: \(timeout)", category: .keyboard)
                guard let self = self else { return }
                if self.preferences.idleOffEnabled && self.idleTimer != nil {
                    // タイマーが動作中の場合は再起動
                    self.stopIdleTimer()
                    self.startIdleTimer()
                }
            }
            .store(in: &cancellables)
        
        // No cache to invalidate, removed notification observer
    }
    
    private func handleIdleEnabledChange(_ enabled: Bool) {
        Logger.debug("handleIdleEnabledChange called with: \(enabled)", category: .keyboard)
        if enabled {
            // 有効になった場合、タイマーを開始
            if idleTimer == nil {
                Logger.debug("Starting idle timer", category: .keyboard)
                startIdleTimer()
            }
        } else {
            // 無効になった場合、タイマーを停止
            Logger.debug("Stopping idle timer", category: .keyboard)
            stopIdleTimer()
        }
    }
    
    // MARK: - Error Handling and Retry
    
    private func handleEventTapCreationFailure() {
        let error = ModSwitchIMEError.eventTapCreationFailed(
            reason: retryCount < maxRetries ? "Attempting retry..." : "Maximum retries exceeded"
        )
        onError?(error)
        
        if retryCount < maxRetries {
            retryCount += 1
            let delay = Double(retryCount) * 2.0 // Exponential backoff
            
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
    
    // MARK: - Performance Optimization
    
    private func getCachedIME(for key: ModifierKey) -> String? {
        // Direct access without cache
        return preferences.getIME(for: key)
    }
    
    // Cache methods removed - no longer needed
    
    // MARK: - Testing Support
    #if DEBUG
    // Expose internal state for testing
    func getModifierKeyStates() -> [ModifierKey: (isDown: Bool, downTime: CFAbsoluteTime)] {
        return modifierKeyStates
    }
    
    func getIsValidMultiKeyPress() -> Bool {
        return isValidMultiKeyPress
    }
    
    func getLastPressedModifierKey() -> ModifierKey? {
        return lastPressedModifierKey
    }
    
    // Allow test injection of mock ImeController
    func setImeController(_ controller: ImeController) {
        self.imeController = controller
    }
    
    // Simulate key events for testing
    func simulateFlagsChanged(keyCode: Int64, flags: CGEventFlags) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)!
        event.flags = flags
        handleFlagsChanged(event: event)
    }
    #endif
}
