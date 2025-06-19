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
        
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        
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
        lastActivityTime = CFAbsoluteTimeGetCurrent()
        
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
        case .keyDown:
            // Check if any modifier key is down
            let anyModifierDown = modifierKeyStates.values.contains { $0.isDown }
            if anyModifierDown || leftCmdDown || rightCmdDown {
                otherKeyPressed = true
                Logger.debug("Other key pressed while modifier is down", category: .keyboard)
            }
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
        
        if isKeyDown && !currentState.isDown {
            // Key pressed down
            modifierKeyStates[modifierKey] = (isDown: true, downTime: CFAbsoluteTimeGetCurrent())
            otherKeyPressed = false
            Logger.debug("\(modifierKey.displayName) down", category: .keyboard)
            
            // Update legacy state for command keys
            if modifierKey == .leftCommand {
                leftCmdDown = true
                leftCmdDownTime = CFAbsoluteTimeGetCurrent()
            } else if modifierKey == .rightCommand {
                rightCmdDown = true
                rightCmdDownTime = CFAbsoluteTimeGetCurrent()
            }
        } else if !isKeyDown && currentState.isDown {
            // Key released
            modifierKeyStates[modifierKey] = (isDown: false, downTime: 0)
            
            if !otherKeyPressed {
                if preferences.cmdKeyTimeoutEnabled {
                    let elapsed = CFAbsoluteTimeGetCurrent() - currentState.downTime
                    if elapsed < preferences.cmdKeyTimeout {
                        Logger.debug("\(modifierKey.displayName) triggered (elapsed: \(elapsed)s)", category: .keyboard)
                        imeController.switchToSpecificIME(targetIME)
                    }
                } else {
                    Logger.debug("\(modifierKey.displayName) triggered (instant)", category: .keyboard)
                    imeController.switchToSpecificIME(targetIME)
                }
            }
            
            // Update legacy state for command keys
            if modifierKey == .leftCommand {
                leftCmdDown = false
            } else if modifierKey == .rightCommand {
                rightCmdDown = false
            }
        }
    }
    
    // MARK: - アイドルタイマー関連
    
    private func startIdleTimer() {
        guard preferences.idleOffEnabled else {
            return
        }
        
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkIdleTimeout()
        }
    }
    
    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
    
    private func checkIdleTimeout() {
        guard preferences.idleOffEnabled else {
            stopIdleTimer()
            return
        }
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        let idleTime = currentTime - lastActivityTime
        
        if idleTime >= preferences.idleTimeout {
            if let idleIME = preferences.idleReturnIME {
                Logger.info("Idle timeout reached, switching to configured IME", category: .keyboard)
                imeController.switchToSpecificIME(idleIME)
            } else {
                Logger.info("Idle timeout reached, switching to English", category: .keyboard)
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
