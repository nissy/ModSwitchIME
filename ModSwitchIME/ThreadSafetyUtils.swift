import Foundation

/// Utility functions for thread-safe operations
enum ThreadSafetyUtils {
    /// Execute a function on the main thread, handling both test and production environments
    /// - Parameters:
    ///   - timeout: Maximum time to wait for completion (default 2 seconds)
    ///   - execute: The function to execute on main thread
    /// - Returns: The result of the function
    static func executeOnMainThread<T>(timeout: TimeInterval = 2.0, execute: @escaping () -> T) -> T? {
        if Thread.isMainThread {
            // Already on main thread, execute directly
            return execute()
        } else {
            // Use async dispatch to avoid potential deadlocks
            var result: T?
            let semaphore = DispatchSemaphore(value: 0)
            
            DispatchQueue.main.async {
                result = execute()
                semaphore.signal()
            }
            
            // Wait with timeout to prevent infinite wait
            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                Logger.error("Critical: Timeout executing on main thread - returning nil to prevent crash", category: .main)
                return nil
            }
            
            return result
        }
    }
    
    /// Execute a function on the main thread with error handling
    /// - Parameters:
    ///   - timeout: Maximum time to wait for completion
    ///   - defaultValue: Default value to return on timeout
    ///   - execute: The function to execute
    /// - Returns: Result or default value on timeout
    static func executeOnMainThreadWithDefault<T>(
        timeout: TimeInterval = 2.0,
        defaultValue: T,
        execute: @escaping () -> T
    ) -> T {
        if Thread.isMainThread {
            return execute()
        } else {
            var result: T = defaultValue
            let semaphore = DispatchSemaphore(value: 0)
            
            DispatchQueue.main.async {
                result = execute()
                semaphore.signal()
            }
            
            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                Logger.warning("Timeout executing on main thread, returning default value", category: .main)
                return defaultValue
            }
            
            return result
        }
    }
}