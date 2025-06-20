import Foundation
import ApplicationServices
import AppKit

class AccessibilityManager {
    static let shared = AccessibilityManager()
    
    private var lastCheckTime = Date(timeIntervalSince1970: 0)
    private var cachedPermissionStatus: Bool?
    private let cacheValidityDuration: TimeInterval = 1.0
    
    // Thread-safe access to cached data
    private let cacheQueue = DispatchQueue(label: "com.modswitchime.accessibility.cache", attributes: .concurrent)
    
    private init() {}
    
    // Check accessibility permission with caching (thread-safe)
    var hasPermission: Bool {
        return cacheQueue.sync {
            let now = Date()
            
            // Return cached value if still valid
            if let cached = cachedPermissionStatus,
               now.timeIntervalSince(lastCheckTime) < cacheValidityDuration {
                return cached
            }
            
            // Check permission and cache result (must be done synchronously)
            let status = AXIsProcessTrusted()
            
            // Update cache atomically
            cacheQueue.async(flags: .barrier) {
                self.cachedPermissionStatus = status
                self.lastCheckTime = now
            }
            
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
