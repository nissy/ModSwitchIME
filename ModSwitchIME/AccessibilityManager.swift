import Foundation
import ApplicationServices
import AppKit

final class AccessibilityManager {
    static let shared = AccessibilityManager()
    
    private var lastCheckTime = Date(timeIntervalSince1970: 0)
    private var cachedPermissionStatus: Bool?
    private let cacheValidityDuration: TimeInterval = 1.0
    
    // Thread-safe access to cached data
    private let cacheQueue = DispatchQueue(label: "com.modswitchime.accessibility.cache", attributes: .concurrent)
    
    private init() {}
    
    // Check accessibility permission with caching (thread-safe)
    var hasPermission: Bool {
        // First, try to read cached value without blocking
        var cachedValue: (status: Bool, time: Date)?
        cacheQueue.sync {
            if let status = cachedPermissionStatus {
                cachedValue = (status, lastCheckTime)
            }
        }
        
        // Check if cached value is still valid
        if let cached = cachedValue {
            let now = Date()
            if now.timeIntervalSince(cached.time) < cacheValidityDuration {
                return cached.status
            }
        }
        
        // Need to refresh - use barrier to ensure exclusive access
        return cacheQueue.sync(flags: .barrier) {
            // Double-check in case another thread just updated
            let now = Date()
            if let cached = cachedPermissionStatus,
               now.timeIntervalSince(lastCheckTime) < cacheValidityDuration {
                return cached
            }
            
            // Check permission and update cache synchronously
            let status = AXIsProcessTrusted()
            cachedPermissionStatus = status
            lastCheckTime = now
            
            Logger.debug("Accessibility permission checked: \(status)", category: .keyboard)
            return status
        }
    }
    
    // Force refresh the cache (thread-safe)
    func refreshPermissionStatus() {
        cacheQueue.async(flags: .barrier) {
            self.cachedPermissionStatus = nil
            self.lastCheckTime = Date(timeIntervalSince1970: 0)
        }
    }
    
    // Request permission with options
    func requestPermission() -> Bool {
        if hasPermission {
            return true
        }
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    // Open system preferences
    static func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
