import Foundation
import CoreGraphics

/// Manages CGEventTap lifecycle with proper state management
class EventTapManager {
    enum State {
        case stopped
        case starting
        case running
        case stopping
        case recreating
    }
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var state: State = .stopped
    private let stateQueue = DispatchQueue(label: "com.modswitchime.eventtap.state", attributes: .serial)
    private var retryCount = 0
    private let maxRetries = 3
    
    weak var delegate: EventTapManagerDelegate?
    
    func start() -> Bool {
        return stateQueue.sync {
            guard state == .stopped else {
                Logger.warning("EventTap start requested but state is \(state)", category: .keyboard)
                return false
            }
            
            state = .starting
            let success = createEventTap()
            state = success ? .running : .stopped
            return success
        }
    }
    
    func stop() {
        stateQueue.sync {
            guard state == .running else {
                Logger.warning("EventTap stop requested but state is \(state)", category: .keyboard)
                return
            }
            
            state = .stopping
            removeEventTap()
            state = .stopped
        }
    }
    
    func recreate() -> Bool {
        return stateQueue.sync {
            guard state == .running else {
                Logger.warning("EventTap recreate requested but state is \(state)", category: .keyboard)
                return false
            }
            
            state = .recreating
            removeEventTap()
            
            let success = createEventTap()
            state = success ? .running : .stopped
            
            if !success {
                retryCount += 1
                if retryCount < maxRetries {
                    delegate?.eventTapManagerShouldRetry(self, attempt: retryCount)
                } else {
                    delegate?.eventTapManager(self, didFailWithError: .eventTapCreationFailed(reason: "Maximum retries exceeded"))
                }
            } else {
                retryCount = 0
            }
            
            return success
        }
    }
    
    private func createEventTap() -> Bool {
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.error("Failed to create event tap", category: .keyboard)
            return false
        }
        
        self.eventTap = eventTap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            Logger.info("Event tap created and enabled", category: .keyboard)
            return true
        }
        
        return false
    }
    
    private func removeEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        Logger.info("Event tap removed", category: .keyboard)
    }
    
    var isRunning: Bool {
        return stateQueue.sync { state == .running }
    }
    
    deinit {
        stop()
    }
}

// MARK: - Event Tap Callback

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let manager = refcon else { return Unmanaged.passRetained(event) }
    
    let eventTapManager = Unmanaged<EventTapManager>.fromOpaque(manager).takeUnretainedValue()
    
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        eventTapManager.delegate?.eventTapManager(eventTapManager, wasDisabledByType: type)
        return Unmanaged.passRetained(event)
    }
    
    // Delegate actual event processing to avoid heavy processing in callback
    DispatchQueue.main.async {
        eventTapManager.delegate?.eventTapManager(eventTapManager, didReceiveEvent: event)
    }
    
    return Unmanaged.passRetained(event)
}

// MARK: - Delegate Protocol

protocol EventTapManagerDelegate: AnyObject {
    func eventTapManager(_ manager: EventTapManager, didReceiveEvent event: CGEvent)
    func eventTapManager(_ manager: EventTapManager, wasDisabledByType type: CGEventType)
    func eventTapManager(_ manager: EventTapManager, didFailWithError error: ModSwitchIMEError)
    func eventTapManagerShouldRetry(_ manager: EventTapManager, attempt: Int)
}