import Foundation
import CoreGraphics
import Carbon
import Combine

class KeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let imeController = ImeController()
    private let preferences = Preferences.shared
    private var isRunning = false
    private var cancellables = Set<AnyCancellable>()
    
    // Track modifier key states
    private var modifierKeyStates: [ModifierKey: (isDown: Bool, downTime: CFAbsoluteTime)] = [:]
    private var otherKeyPressed = false
    
    // Legacy support for old code
    private var leftCmdDownTime: CFAbsoluteTime = 0
    private var rightCmdDownTime: CFAbsoluteTime = 0
    private var leftCmdDown = false
    private var rightCmdDown = false
    
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
    
    func start() {
        // 既に実行中の場合はスキップ
        if isRunning {
            return
        }
        
        Logger.debug("KeyMonitor.start() called", category: .keyboard)
        
        // アクセシビリティ権限を確認
        let trusted = AXIsProcessTrusted()
        
        if !trusted {
            Logger.warning("KeyMonitor cannot start without accessibility permission", category: .keyboard)
            return
        }
        
        // Privacy protection: Only monitor modifier key events (flagsChanged)
        // This ensures we never capture regular keystrokes or text input
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        
        // イベントタップを作成
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
            Logger.error("Failed to create event tap", category: .keyboard)
            return
        }
        
        self.eventTap = eventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        isRunning = true
        Logger.info("KeyMonitor started", category: .keyboard)
        
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
        
        // 監視をキャンセル
        cancellables.removeAll()
        
        Logger.info("KeyMonitor stopped", category: .keyboard)
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        
        // アクティビティを記録
        let previousActivityTime = lastActivityTime
        lastActivityTime = CFAbsoluteTimeGetCurrent()
        
        // Reset idle timer if we were close to timeout
        if preferences.idleOffEnabled && idleTimer != nil {
            let timeSinceLastActivity = lastActivityTime - previousActivityTime
            let remainingTime = preferences.idleTimeout - timeSinceLastActivity
            
            // If we're within 10% of the timeout, restart the timer for better accuracy
            if remainingTime < preferences.idleTimeout * 0.1 {
                stopIdleTimer()
                startIdleTimer()
            }
        }
        
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
        case .tapDisabledByTimeout:
            Logger.error("Event tap disabled by timeout", category: .keyboard)
            // イベントタップを再有効化
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        case .tapDisabledByUserInput:
            Logger.error("Event tap disabled by user input", category: .keyboard)
        default:
            break
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func handleFlagsChanged(event: CGEvent) {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // Privacy: Clear the event data after reading
        defer {
            // Ensure no sensitive data remains in memory
            event.setIntegerValueField(.keyboardEventKeycode, value: 0)
        }
        
        // Identify which modifier key based on keyCode
        guard let modifierKey = ModifierKey.from(keyCode: keyCode) else {
            return
        }
        
        // Check if this key has an IME mapping
        guard let targetIME = preferences.getIME(for: modifierKey) else {
            return
        }
        
        // Check if the corresponding flag is set
        let isKeyDown = flags.contains(modifierKey.flagMask)
        
        // Get current state
        let currentState = modifierKeyStates[modifierKey] ?? (isDown: false, downTime: 0)
        
        // Check if other modifier keys are pressed (for combination detection)
        let otherModifiersPressed = flags.intersection([.maskControl, .maskShift, .maskAlternate, .maskCommand])
            .subtracting(modifierKey.flagMask)
            .rawValue > 0
        
        if isKeyDown && !currentState.isDown {
            handleKeyDown(modifierKey: modifierKey, otherModifiersPressed: otherModifiersPressed)
        } else if !isKeyDown && currentState.isDown {
            handleKeyUp(
                modifierKey: modifierKey,
                currentState: currentState,
                otherModifiersPressed: otherModifiersPressed,
                targetIME: targetIME
            )
        }
    }
    
    // Helper function for key down handling
    private func handleKeyDown(modifierKey: ModifierKey, otherModifiersPressed: Bool) {
        modifierKeyStates[modifierKey] = (isDown: true, downTime: CFAbsoluteTimeGetCurrent())
        otherKeyPressed = otherModifiersPressed
        Logger.debug("\(modifierKey.displayName) down", category: .keyboard)
        
        // Update legacy state for command keys
        updateLegacyCommandState(modifierKey: modifierKey, isDown: true)
    }
    
    // Helper function for key up handling
    private func handleKeyUp(modifierKey: ModifierKey, currentState: (isDown: Bool, downTime: CFAbsoluteTime), otherModifiersPressed: Bool, targetIME: String) {
        modifierKeyStates[modifierKey] = (isDown: false, downTime: 0)
        
        // Only trigger if no other modifiers were pressed during this key press
        if !otherKeyPressed && !otherModifiersPressed {
            triggerIMESwitch(modifierKey: modifierKey, downTime: currentState.downTime, targetIME: targetIME)
        }
        
        // Update legacy state for command keys
        updateLegacyCommandState(modifierKey: modifierKey, isDown: false)
    }
    
    // Helper function for IME switching logic
    private func triggerIMESwitch(modifierKey: ModifierKey, downTime: CFAbsoluteTime, targetIME: String) {
        if preferences.cmdKeyTimeoutEnabled {
            let elapsed = CFAbsoluteTimeGetCurrent() - downTime
            if elapsed < preferences.cmdKeyTimeout {
                Logger.debug("\(modifierKey.displayName) triggered (elapsed: \(elapsed)s)", category: .keyboard)
                imeController.switchToSpecificIME(targetIME)
            }
        } else {
            Logger.debug("\(modifierKey.displayName) triggered (instant)", category: .keyboard)
            imeController.switchToSpecificIME(targetIME)
        }
    }
    
    // Helper function for legacy command state
    private func updateLegacyCommandState(modifierKey: ModifierKey, isDown: Bool) {
        switch modifierKey {
        case .leftCommand:
            leftCmdDown = isDown
            if isDown {
                leftCmdDownTime = CFAbsoluteTimeGetCurrent()
            }
        case .rightCommand:
            rightCmdDown = isDown
            if isDown {
                rightCmdDownTime = CFAbsoluteTimeGetCurrent()
            }
        default:
            break
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
        
        Logger.debug("Checking idle timeout: idle for \(idleTime)s, timeout: \(preferences.idleTimeout)s", category: .keyboard)
        
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
}
