import Foundation

/// Simple debounce mechanism for IME switching
class IMEThrottler {
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    private let delay: TimeInterval
    
    init(delay: TimeInterval = 0.05, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    func throttle(action: @escaping () -> Void) {
        // Cancel previous work item
        workItem?.cancel()
        
        // Create new work item
        let newWorkItem = DispatchWorkItem { [weak self] in
            action()
            self?.workItem = nil
        }
        
        workItem = newWorkItem
        queue.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
    
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}