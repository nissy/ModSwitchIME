import Foundation
import Carbon
import CoreGraphics
import Cocoa

// Protocol for testable IME controller
protocol IMEControlling {
    func switchToSpecificIME(_ targetIMEId: String)
    func getCurrentInputSource() -> String
    func forceAscii()
}

final class ImeController: ErrorHandler, IMEControlling {
    // Singleton instance
    static let shared = ImeController()
    
    // Factory method for testing
    #if DEBUG
    static func createForTesting() -> ImeController {
        return ImeController()
    }
    #endif
    
    private let preferences = Preferences.shared
    var onError: ((ModSwitchIMEError) -> Void)?
    
    // Thread-safe cache for input sources
    private var inputSourceCache: [String: TISInputSource] = [:]
    private let cacheQueue = DispatchQueue(label: "com.modswitchime.cache")
    
    // Track last switched IME for app focus verification
    private var lastSwitchedIME: String?
    private let lastSwitchedIMEQueue = DispatchQueue(label: "com.modswitchime.lastIME")
    
    // Throttling for IME switch requests
    private var lastSwitchTime: CFAbsoluteTime = 0
    private var lastSwitchIME: String?
    private let throttleInterval: TimeInterval = 0.05 // 50ms
    private let throttleQueue = DispatchQueue(label: "com.modswitchime.throttle")
    
    private init() {
        // Initialize cache on startup for immediate availability
        initializeCache()
        // Start monitoring for IME changes
        startMonitoringIMEChanges()
        // Start monitoring for app focus changes
        startMonitoringApplicationFocus()
    }
    
    private func initializeCache() {
        // Build cache synchronously on initialization for immediate availability
        if Thread.isMainThread {
            buildCacheSync()
        } else {
            // Use async dispatch to avoid potential deadlock
            DispatchQueue.main.async { [weak self] in
                self?.buildCacheSync()
            }
        }
    }
    
    private func buildCacheSync() {
        guard let cfInputSources = TISCreateInputSourceList(nil, false) else {
            Logger.error("TISCreateInputSourceList returned nil", category: .ime)
            return
        }
        
        let inputSources = cfInputSources.takeRetainedValue() as? [TISInputSource] ?? []
        
        if inputSources.isEmpty {
            Logger.warning("No input sources found", category: .ime)
            return
        }
        
        var newCache: [String: TISInputSource] = [:]
        
        for inputSource in inputSources {
            if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
                
                // Cache all input sources, not just enabled ones
                // This allows switching to disabled IMEs if needed
                newCache[id] = inputSource
            }
        }
        
        // Update cache atomically
        cacheQueue.async { [weak self] in
            self?.inputSourceCache = newCache
        }
        Logger.debug("IME cache initialized with \(newCache.count) input sources", category: .ime)
    }
    
    private func refreshInputSourceCache() {
        // Refresh cache in background
        DispatchQueue.main.async { [weak self] in
            self?.buildCacheSync()
        }
    }
    
    private func switchToEnglish() {
        let englishSources = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]
        
        for sourceID in englishSources {
            do {
                try selectInputSource(sourceID)
                return
            } catch {
                // Try next
            }
        }
        
        let error = ModSwitchIMEError.inputSourceNotFound("English input source")
        handleError(error)
    }
    
    func forceAscii() {
        switchToEnglish()
    }
    
    // Removed toggleByCmd - no longer used after architecture changes
    
    func switchToSpecificIME(_ imeId: String) {
        // Validate IME ID
        guard isValidIMEId(imeId) else {
            Logger.warning("Invalid IME ID provided: \(imeId)", category: .ime)
            handleError(ModSwitchIMEError.invalidConfiguration)
            return
        }
        
        let now = CFAbsoluteTimeGetCurrent()
        
        // Thread-safe throttling check
        var shouldSwitch = false
        throttleQueue.sync {
            // Check if enough time has passed since last switch
            let timeSinceLastSwitch = now - lastSwitchTime
            
            // Skip if:
            // 1. Same IME requested within throttle interval
            // 2. Any switch happened within throttle interval (except first switch)
            if lastSwitchIME == imeId && timeSinceLastSwitch < throttleInterval {
                Logger.debug("Throttling duplicate IME switch request for: \(imeId)", category: .ime)
                return
            }
            
            if lastSwitchTime > 0 && timeSinceLastSwitch < throttleInterval {
                Logger.debug("Throttling IME switch request (too soon): \(imeId)", category: .ime)
                return
            }
            
            // Update throttle state
            lastSwitchTime = now
            lastSwitchIME = imeId
            shouldSwitch = true
        }
        
        // Execute immediately if throttle check passed
        if shouldSwitch {
            do {
                try selectInputSource(imeId)
            } catch {
                let imeError = ModSwitchIMEError.inputSourceNotFound(imeId)
                handleError(imeError)
            }
        }
    }
    
    private func isValidIMEId(_ imeId: String) -> Bool {
        // Check if empty
        guard !imeId.isEmpty else { return false }
        
        // Check for reasonable length (typical IME IDs are under 200 characters)
        guard imeId.count < 200 else { return false }
        
        // Check for valid characters (alphanumeric, dots, hyphens, underscores)
        let validCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        let imeCharacterSet = CharacterSet(charactersIn: imeId)
        guard imeCharacterSet.isSubset(of: validCharacterSet) else { return false }
        
        // Check for known prefixes (most system IMEs start with these)
        let knownPrefixes = ["com.apple.", "com.google.", "jp.co.", "com.", "org.", "net."]
        let hasKnownPrefix = knownPrefixes.contains { imeId.hasPrefix($0) }
        
        // If it doesn't have a known prefix, at least check it has some structure
        if !hasKnownPrefix {
            // Should contain at least one dot (reverse domain notation)
            guard imeId.contains(".") else { return false }
        }
        
        return true
    }
    
    func selectInputSource(_ inputSourceID: String) throws {
        // Validate input
        guard isValidIMEId(inputSourceID) else {
            throw ModSwitchIMEError.invalidInputSource("Invalid IME ID format: \(inputSourceID)")
        }
        
        // Get current IME before switching
        let currentIME = getCurrentInputSource()
        Logger.debug("Switching IME: \(currentIME) -> \(inputSourceID)", category: .ime)
        
        // Thread-safe cache read
        var cachedSource: TISInputSource?
        cacheQueue.sync {
            cachedSource = inputSourceCache[inputSourceID]
        }
        
        // Try with cached source first
        if let source = cachedSource {
            // Retry mechanism with exponential backoff
            var lastError: Error?
            for attempt in 0..<3 {
                let result = TISSelectInputSource(source)
                if result == noErr {
                    // Success - verify the switch after a short delay
                    verifyIMESwitch(expectedIME: inputSourceID, currentIME: currentIME)
                    // Track successful switch
                    setLastSwitchedIME(inputSourceID)
                    return
                }
                
                // Failed - wait before retry with exponential backoff
                lastError = ModSwitchIMEError.inputMethodSwitchFailed("TISSelectInputSource failed with code: \(result)")
                Logger.warning("IME switch attempt \(attempt + 1) failed with code: \(result)", category: .ime)
                
                if attempt < 2 {
                    let delay = Double(attempt + 1) * 0.1 // 0.1s, 0.2s
                    Thread.sleep(forTimeInterval: delay)
                }
            }
            
            // All retries failed
            throw lastError ?? ModSwitchIMEError.inputMethodSwitchFailed("Unknown error")
        }
        
        // Source not in cache - refresh and retry
        Logger.warning("IME not found in cache, refreshing: \(inputSourceID)", category: .ime)
        
        // Refresh cache synchronously
        refreshCacheSync()
        
        // Try again with refreshed cache
        cacheQueue.sync {
            cachedSource = inputSourceCache[inputSourceID]
        }
        
        if let source = cachedSource {
            // Retry with fresh source
            for attempt in 0..<3 {
                let result = TISSelectInputSource(source)
                if result == noErr {
                    verifyIMESwitch(expectedIME: inputSourceID, currentIME: currentIME)
                    // Track successful switch
                    setLastSwitchedIME(inputSourceID)
                    return
                }
                
                Logger.warning("IME switch with fresh source attempt \(attempt + 1) failed", category: .ime)
                if attempt < 2 {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
            
            throw ModSwitchIMEError.inputMethodSwitchFailed("Failed after cache refresh")
        }
        
        throw ModSwitchIMEError.inputSourceNotFound(inputSourceID)
    }
    
    private func verifyIMESwitch(expectedIME: String, currentIME: String) {
        // Verify the switch after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let newIME = self?.getCurrentInputSource() ?? "Unknown"
            
            if newIME == expectedIME {
                Logger.debug("IME switch verified: \(currentIME) -> \(newIME)", category: .ime)
            } else if newIME == currentIME {
                Logger.warning("IME switch may have failed: still at \(currentIME)", category: .ime)
                // Retry once more
                self?.retryIMESwitch(targetIME: expectedIME)
            } else {
                Logger.warning("IME switched to unexpected: \(newIME) (expected: \(expectedIME))", category: .ime)
            }
        }
    }
    
    private func retryIMESwitch(targetIME: String) {
        DispatchQueue.main.async { [weak self] in
            // Find fresh source directly
            if let freshSource = self?.findFreshInputSource(targetIME) {
                let result = TISSelectInputSource(freshSource)
                if result == noErr {
                    Logger.info("Retry IME switch successful", category: .ime)
                    self?.setLastSwitchedIME(targetIME)
                } else {
                    Logger.error("Retry IME switch failed with code: \(result)", category: .ime)
                }
            }
        }
    }
    
    private func findFreshInputSource(_ inputSourceID: String) -> TISInputSource? {
        guard let cfInputSources = TISCreateInputSourceList(nil, false) else {
            return nil
        }
        
        let inputSources = cfInputSources.takeRetainedValue() as? [TISInputSource] ?? []
        
        for inputSource in inputSources {
            if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
                if id == inputSourceID {
                    return inputSource
                }
            }
        }
        
        return nil
    }
    
    private func refreshCacheSync() {
        // Synchronous cache refresh for critical operations
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async { [weak self] in
            self?.buildCacheSync()
            semaphore.signal()
        }
        
        // Wait for cache refresh to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 1.0)
    }
    
    // MARK: - IME Change Monitoring
    
    private func startMonitoringIMEChanges() {
        // Monitor for input source changes (removed NSTextInputContext - not available)
        
        // Also monitor for system notifications about input method changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourcesChanged),
            name: NSNotification.Name("com.apple.Carbon.TISNotifyEnabledKeyboardInputSourcesChanged"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourcesChanged),
            name: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil
        )
        
        // Monitor system sleep/wake events
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    @objc private func inputSourcesChanged(_ notification: Notification) {
        Logger.debug("Input sources changed, refreshing cache", category: .ime)
        // Refresh cache when system IMEs change
        refreshInputSourceCache()
    }
    
    @objc private func systemWillSleep(_ notification: Notification) {
        Logger.info("System will sleep - preparing IME cache", category: .ime)
        // Cache might become stale during sleep, mark for refresh
    }
    
    @objc private func systemDidWake(_ notification: Notification) {
        Logger.info("System did wake - refreshing IME cache", category: .ime)
        
        // Delay cache refresh to ensure system is fully awake
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshInputSourceCache()
            Logger.debug("IME cache refreshed after system wake", category: .ime)
        }
    }
    
    // MARK: - Application Focus Monitoring
    
    private func startMonitoringApplicationFocus() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        
        let appName = app.localizedName ?? "Unknown"
        Logger.debug("Application activated: \(appName)", category: .ime)
        
        // Verify IME state after a short delay to ensure app is fully focused
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.verifyIMEStateAfterAppSwitch()
        }
    }
    
    private func verifyIMEStateAfterAppSwitch() {
        let actualIME = getCurrentInputSource()
        
        // Get expected IME from last switch
        let expectedIME = lastSwitchedIMEQueue.sync { lastSwitchedIME }
        
        if let expected = expectedIME, actualIME != expected {
            Logger.warning("IME state mismatch after app switch: expected=\(expected), actual=\(actualIME)", category: .ime)
            
            // Optionally refresh cache to ensure accuracy
            refreshInputSourceCache()
            
            // Log for debugging but don't force switch
            // Some apps intentionally change IME and we should respect that
        } else {
            Logger.debug("IME state verified after app switch: \(actualIME)", category: .ime)
        }
    }
    
    private func setLastSwitchedIME(_ imeId: String) {
        lastSwitchedIMEQueue.async { [weak self] in
            self?.lastSwitchedIME = imeId
        }
    }
    
    private func getLastSwitchedIME() -> String? {
        return lastSwitchedIMEQueue.sync { lastSwitchedIME }
    }
    
    // Removed performSwitch and related methods - no longer needed after simplification
    
    func getCurrentInputSource() -> String {
        if Thread.isMainThread {
            return getCurrentInputSourceSync()
        } else {
            var result = "Unknown"
            DispatchQueue.main.sync {
                result = getCurrentInputSourceSync()
            }
            return result
        }
    }
    
    private func getCurrentInputSourceSync() -> String {
        guard let currentSource = TISCopyCurrentKeyboardInputSource() else {
            return "Unknown"
        }
        
        let source = currentSource.takeRetainedValue()
        
        if let sourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
            let cfString = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue()
            return cfString as String
        }
        
        return "Unknown"
    }
    
    // MARK: - ErrorHandler
    
    func handleError(_ error: ModSwitchIMEError) {
        logError(error, category: .ime)
        onError?(error)
    }
    
    deinit {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
