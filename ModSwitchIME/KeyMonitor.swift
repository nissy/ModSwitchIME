import Foundation
import CoreGraphics
import Carbon

class KeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let imeController = ImeController()
    private let preferences = Preferences()
    private var isRunning = false
    
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
    
    func start() {
        // 既に実行中の場合はスキップ
        if isRunning {
            return
        }
        
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
}
