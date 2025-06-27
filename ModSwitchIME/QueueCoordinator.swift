import Foundation

/// Coordinates multiple queues to prevent dependency issues
class QueueCoordinator {
    static let shared = QueueCoordinator()
    
    // Queue hierarchy
    let mainQueue = DispatchQueue.main
    let cacheQueue = DispatchQueue(label: "com.modswitchime.cache", attributes: .serial)
    let eventProcessingQueue = DispatchQueue(label: "com.modswitchime.event", attributes: .serial, qos: .userInteractive)
    let backgroundQueue = DispatchQueue(label: "com.modswitchime.background", attributes: .concurrent, qos: .background)
    
    private init() {}
    
    /// Execute cache operation ensuring proper ordering
    func performCacheOperation<T>(_ operation: @escaping () throws -> T, completion: @escaping (Result<T, Error>) -> Void) {
        cacheQueue.async {
            do {
                let result = try operation()
                self.mainQueue.async {
                    completion(.success(result))
                }
            } catch {
                self.mainQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Execute event processing with high priority
    func processEvent(_ operation: @escaping () -> Void) {
        eventProcessingQueue.async(execute: operation)
    }
    
    /// Execute background task
    func performBackgroundTask(_ operation: @escaping () -> Void) {
        backgroundQueue.async(execute: operation)
    }
    
    /// Execute on main thread if needed
    func ensureMainThread(_ operation: @escaping () -> Void) {
        if Thread.isMainThread {
            operation()
        } else {
            mainQueue.async(execute: operation)
        }
    }
}