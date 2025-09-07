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

// swiftlint:disable:next type_body_length
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
    
    // Track last switch time for chattering prevention
    private var lastSwitchTime: CFAbsoluteTime = 0
    private let switchTimeQueue = DispatchQueue(label: "com.modswitchime.switchtime", attributes: .concurrent)
    
    // Removed throttling - redundant with getCurrentInputSource() check
    
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
            // For test environments, wait for cache to be built
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.main.async { [weak self] in
                self?.buildCacheSync()
                semaphore.signal()
            }
            // Wait with timeout to prevent deadlock
            _ = semaphore.wait(timeout: .now() + 2.0)
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
    
    func forceAscii(fromUser: Bool = true) {
        let englishSources = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]
        
        // Try to switch to the first available English source
        // Don't check immediately as the switch is asynchronous
        for sourceID in englishSources {
            // Check if this source exists in our cache
            var sourceExists = false
            cacheQueue.sync {
                sourceExists = inputSourceCache[sourceID] != nil
            }
            
            if sourceExists {
                // Use switchToSpecificIME
                switchToSpecificIME(sourceID, fromUser: fromUser)
                return  // Don't check immediately, trust the switch will work
            }
        }
        
        // If we get here, no English sources are available
        let error = ModSwitchIMEError.inputSourceNotFound("English input source")
        handleError(error)
    }
    
    // Wrapper for compatibility
    func forceAscii() {
        forceAscii(fromUser: true)
    }
    
    // Removed toggleByCmd - no longer used after architecture changes
    
    func switchToSpecificIME(_ imeId: String, fromUser: Bool = true) {
        // Validate IME ID
        guard isValidIMEId(imeId) else {
            Logger.warning("Invalid IME ID provided: \(imeId)", category: .ime)
            handleError(ModSwitchIMEError.invalidConfiguration)
            return
        }
        
        let currentIME = getCurrentInputSource()
        let now = CFAbsoluteTimeGetCurrent()
        
        if fromUser {
            // User operation
            // Prevent rapid switching for same IME only (chattering prevention)
            let lastTime = switchTimeQueue.sync { lastSwitchTime }
            if currentIME == imeId && (now - lastTime) < 0.1 {
                Logger.debug("Skipping rapid duplicate switch (chattering prevention)", category: .ime)
                // Ensure UI reflects the current state even when we skip
                postUIRefreshNotification()
                return
            }
            // No alternate/fallback selection: selecting a different IME temporarily
            // caused unintended final states in rapid sequences. We only re-select
            // the requested IME (even if it matches current) and refresh UI.
        } else {
            // Internal operation
            // Skip if already on target IME (performance optimization)
            if currentIME == imeId {
                Logger.debug("Already on target IME (internal): \(imeId)", category: .ime)
                return
            }
        }
        
        // Record switch time synchronously to ensure consistency
        // Using barrier for exclusive write access
        switchTimeQueue.sync(flags: .barrier) {
            self.lastSwitchTime = now
        }
        
        // Execute IME switch
        do {
            try selectInputSource(imeId)
        } catch {
            let imeError = ModSwitchIMEError.inputSourceNotFound(imeId)
            handleError(imeError)
            // Refresh UI to show actual state on error
            postUIRefreshNotification()
        }
    }
    
    // Wrapper method for protocol compatibility
    func switchToSpecificIME(_ imeId: String) {
        switchToSpecificIME(imeId, fromUser: true)
    }
    
    private func isValidIMEId(_ imeId: String) -> Bool {
        // Check if empty
        guard !imeId.isEmpty else { return false }
        
        // Check for reasonable length (typical IME IDs are under 200 characters)
        guard imeId.count < 200 else { return false }
        
        // Check for valid characters (alphanumeric, dots, hyphens, underscores)
        let validCharacterSet = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"
        )
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

    // Choose an alternate IME to force a visible state change before selecting the target again.
    private func chooseAlternateIME(for target: String) -> String? {
        var cache: [String: TISInputSource] = [:]
        cacheQueue.sync { cache = inputSourceCache }
        let englishCandidates = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]
        let available = englishCandidates.filter { cache[$0] != nil }
        guard !available.isEmpty else { return nil }
        if target == "com.apple.keylayout.ABC" {
            return available.first { $0 == "com.apple.keylayout.US" } ?? available.first
        }
        if target == "com.apple.keylayout.US" {
            return available.first { $0 == "com.apple.keylayout.ABC" } ?? available.first
        }
        return available.first
    }
    
    func selectInputSource(_ inputSourceID: String) throws {
        // Validate input
        guard isValidIMEId(inputSourceID) else {
            throw ModSwitchIMEError.invalidInputSource("Invalid IME ID format: \(inputSourceID)")
        }
        
        // Get current IME before switching
        let currentIME = getCurrentInputSource()
        Logger.debug("Switching IME: \(currentIME) -> \(inputSourceID)", category: .ime)
        
        // Resolve input source from cache, optionally refreshing
        if let (source, refreshed) = getInputSourceFromCacheOrRefresh(inputSourceID) {
            try selectWithRetries(source: source,
                                  expectedIME: inputSourceID,
                                  currentIME: currentIME,
                                  refreshed: refreshed)
            return
        }
        throw ModSwitchIMEError.inputSourceNotFound(inputSourceID)
    }

    // Resolve input source from cache; if missing, refresh synchronously and retry lookup.
    private func getInputSourceFromCacheOrRefresh(_ id: String) -> (TISInputSource, Bool)? {
        var cached: TISInputSource?
        cacheQueue.sync { cached = inputSourceCache[id] }
        if let s = cached {
            return (s, false)
        }
        Logger.warning("IME not found in cache, refreshing: \(id)", category: .ime)
        refreshCacheSync()
        cacheQueue.sync { cached = inputSourceCache[id] }
        if let s = cached {
            return (s, true)
        }
        return nil
    }

    // Try selecting the given source up to 3 times with small backoff.
    private func selectWithRetries(
        source: TISInputSource,
        expectedIME: String,
        currentIME: String,
        refreshed: Bool
    ) throws {
        var lastError: Error?
        for attempt in 0..<3 {
            let result = TISSelectInputSource(source)
            if result == noErr {
                performHybridIMESwitch(expectedIME: expectedIME, currentIME: currentIME)
                setLastSwitchedIME(expectedIME)
                return
            }
            lastError = ModSwitchIMEError.inputMethodSwitchFailed(
                "TISSelectInputSource failed with code: \(result)"
            )
            let ctx = refreshed ? "fresh source" : "cached source"
            Logger.warning("IME switch (\(ctx)) attempt \(attempt + 1) failed with code: \(result)", category: .ime)
            if attempt < 2 {
                let delay = Double(attempt + 1) * 0.1
                Thread.sleep(forTimeInterval: delay)
            }
        }
        throw lastError ?? ModSwitchIMEError.inputMethodSwitchFailed("Unknown error")
    }
    
    private func performHybridIMESwitch(expectedIME: String, currentIME: String) {
        // Hybrid approach: Check actual switch after a short delay before notifying
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self = self else { return }
            
            let actualIME = self.getCurrentInputSource()
            
            if actualIME == expectedIME {
                // Success - notify UI update
                Logger.debug("IME switch confirmed: \(currentIME) -> \(actualIME)", category: .ime)
                self.postIMESwitchNotification(expectedIME)
                
                // Schedule additional verification for edge cases
                self.scheduleAdditionalVerification(expectedIME: expectedIME, delay: 0.05)
            } else if actualIME == currentIME {
                // Not switched yet - schedule another check
                Logger.debug("IME not switched yet, scheduling verification", category: .ime)
                // Prevent infinite recursion by limiting retry depth
                self.verifyIMESwitchWithLimit(expectedIME: expectedIME, currentIME: currentIME, retryCount: 1)
            } else {
                // Switched to unexpected IME
                Logger.warning(
                    "IME switched to unexpected: \(actualIME) (expected: \(expectedIME))",
                    category: .ime
                )
                // Notify UI with actual state
                self.postUIRefreshNotification()
            }
        }
    }
    
    private func scheduleAdditionalVerification(expectedIME: String, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            let actualIME = self.getCurrentInputSource()
            if actualIME != expectedIME {
                Logger.warning("Additional verification: IME mismatch detected",
                                category: .ime)
                // Correct the UI state
                self.postUIRefreshNotification()
            }
        }
    }
    
    private func verifyIMESwitch(expectedIME: String, currentIME: String) {
        verifyIMESwitchWithLimit(expectedIME: expectedIME, currentIME: currentIME, retryCount: 1)
    }
    
    private func verifyIMESwitchWithLimit(expectedIME: String, currentIME: String, retryCount: Int) {
        guard retryCount <= 3 else {
            Logger.warning("Max retry attempts reached for IME switch verification", category: .ime)
            postUIRefreshNotification()
            return
        }
        
        // Verify the switch after a short delay (reduced from 0.1 to 0.05)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            let newIME = self.getCurrentInputSource()
            
            if newIME == expectedIME {
                Logger.debug("IME switch verified: \(currentIME) -> \(newIME)", category: .ime)
                // Check if notification already sent to prevent duplicates
                var needsNotification = false
                self.notificationQueue.sync {
                    needsNotification = self.lastNotifiedIME != expectedIME
                }
                if needsNotification {
                    self.postIMESwitchNotification(expectedIME)
                }
            } else if newIME == currentIME {
                Logger.warning("IME switch may have failed: still at current IME", category: .ime)
                // Retry with incremented count
                if retryCount < 3 {
                    self.retryIMESwitchWithLimit(targetIME: expectedIME, retryCount: retryCount + 1, fromUser: false)
                } else {
                    self.postUIRefreshNotification()
                }
            } else {
                Logger.warning("IME switched to unexpected: \(newIME) (expected: \(expectedIME))", category: .ime)
                // Refresh UI with actual state
                self.postUIRefreshNotification()
            }
        }
    }
    
    private func retryIMESwitch(targetIME: String) {
        retryIMESwitchWithLimit(targetIME: targetIME, retryCount: 1, fromUser: false)
    }
    
    private func retryIMESwitchWithLimit(targetIME: String, retryCount: Int, fromUser: Bool = false) {
        guard retryCount <= 3 else {
            Logger.warning("Max retry attempts reached for IME switch", category: .ime)
            postUIRefreshNotification()
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Use switchToSpecificIME with fromUser parameter for retry
            self.switchToSpecificIME(targetIME, fromUser: fromUser)
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
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
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
            Logger.warning(
                "IME state mismatch after app switch: expected=\(expected), actual=\(actualIME)",
                category: .ime
            )
            
            // Optionally refresh cache to ensure accuracy
            refreshInputSourceCache()
            
            // Request UI to refresh to reflect the actual current IME
            // Do not force switch (some apps intentionally change IME)
            postUIRefreshNotification()
        } else {
            Logger.debug("IME state verified after app switch: \(actualIME)", category: .ime)
        }
    }
    
    private func setLastSwitchedIME(_ imeId: String) {
        lastSwitchedIMEQueue.sync { [weak self] in
            self?.lastSwitchedIME = imeId
        }
    }
    
    private func getLastSwitchedIME() -> String? {
        return lastSwitchedIMEQueue.sync { lastSwitchedIME }
    }
    
    // MARK: - Thread-safe Notification Helpers
    
    // Track last notified IME to prevent duplicates
    private var lastNotifiedIME: String = ""
    private let notificationQueue = DispatchQueue(label: "com.modswitchime.notification")
    
    private func postIMESwitchNotification(_ imeId: String, isRetry: Bool = false) {
        // Prevent duplicate notifications
        var shouldNotify = false
        let currentIME = isRetry ? getCurrentInputSource() : "" // Get current IME outside of sync block
        
        notificationQueue.sync {
            if lastNotifiedIME != imeId {
                lastNotifiedIME = imeId
                shouldNotify = true
            } else if isRetry && currentIME == imeId {
                // Allow retry notification if actually switched
                shouldNotify = true
            }
        }
        
        guard shouldNotify else {
            Logger.debug("Skipping duplicate notification for: \(imeId)", category: .ime)
            return
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("ModSwitchIME.didSwitchIME"),
                object: nil,
                userInfo: ["imeId": imeId]
            )
        }
    }
    
    private func postUIRefreshNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("ModSwitchIME.shouldRefreshUI"),
                object: nil
            )
        }
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
