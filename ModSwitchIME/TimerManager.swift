import Foundation

/// Centralized timer management to prevent conflicts and improve efficiency
class TimerManager {
    private var timers: [String: Timer] = [:]
    private let queue = DispatchQueue(label: "com.modswitchime.timermanager", attributes: .serial)
    
    func schedule(identifier: String, interval: TimeInterval, repeats: Bool = false, action: @escaping () -> Void) {
        cancel(identifier: identifier)
        
        queue.async { [weak self] in
            let timer = Timer(timeInterval: interval, repeats: repeats) { _ in
                action()
            }
            
            self?.timers[identifier] = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func cancel(identifier: String) {
        queue.async { [weak self] in
            if let timer = self?.timers.removeValue(forKey: identifier) {
                timer.invalidate()
            }
        }
    }
    
    func cancelAll() {
        queue.async { [weak self] in
            self?.timers.values.forEach { $0.invalidate() }
            self?.timers.removeAll()
        }
    }
    
    func isTimerActive(identifier: String) -> Bool {
        return queue.sync {
            return timers[identifier]?.isValid ?? false
        }
    }
    
    deinit {
        cancelAll()
    }
}

// Timer identifiers
extension TimerManager {
    enum TimerIdentifier {
        static let idle = "idle"
        static let retry = "retry"
        static let health = "health"
        static let modifierKeyTimeout = "modifierKeyTimeout"
    }
}