import Foundation
import ApplicationServices
import AppKit

class AccessibilityManager {
    static let shared = AccessibilityManager()
    
    private var lastCheckTime = Date(timeIntervalSince1970: 0)
    private var cachedPermissionStatus: Bool?
    private let cacheValidityDuration: TimeInterval = 1.0
    
    private init() {}
    
    // Check accessibility permission with caching
    var hasPermission: Bool {
        let now = Date()
        
        // Return cached value if still valid
        if let cached = cachedPermissionStatus,
           now.timeIntervalSince(lastCheckTime) < cacheValidityDuration {
            return cached
        }
        
        // Check permission and cache result
        let status = AXIsProcessTrusted()
        cachedPermissionStatus = status
        lastCheckTime = now
        
        Logger.debug("Accessibility permission checked: \(status)", category: .keyboard)
        return status
    }
    
    // Force refresh the cache
    func refreshPermissionStatus() {
        cachedPermissionStatus = nil
        lastCheckTime = Date(timeIntervalSince1970: 0)
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
