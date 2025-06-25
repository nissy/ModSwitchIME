import Foundation
import Carbon
import CoreGraphics

class ImeController: ErrorHandler {
    private let preferences = Preferences.shared
    var onError: ((ModSwitchIMEError) -> Void)?
    
    // Thread-safe cache for input sources
    private var inputSourceCache: [String: TISInputSource] = [:]
    private let cacheQueue = DispatchQueue(label: "com.modswitchime.cache", attributes: .concurrent)
    
    init() {
        // Initialize cache on startup for immediate availability
        initializeCache()
        // Start monitoring for IME changes
        startMonitoringIMEChanges()
    }
    
    private func initializeCache() {
        // Build cache synchronously on initialization for immediate availability
        if Thread.isMainThread {
            buildCacheSync()
        } else {
            DispatchQueue.main.sync {
                buildCacheSync()
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
        
        // Update cache atomically with barrier
        cacheQueue.async(flags: .barrier) { [weak self] in
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
        
        // Direct switch without checking current IME for better performance
        // TIS API handles switching to the same IME efficiently
        do {
            try selectInputSource(imeId)
        } catch {
            let imeError = ModSwitchIMEError.inputSourceNotFound(imeId)
            handleError(imeError)
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
        
        // Thread-safe cache read
        var cachedSource: TISInputSource?
        cacheQueue.sync {
            cachedSource = inputSourceCache[inputSourceID]
        }
        
        if let source = cachedSource {
            let result = TISSelectInputSource(source)
            if result != noErr {
                throw ModSwitchIMEError.inputMethodSwitchFailed("TISSelectInputSource failed with code: \(result)")
            }
            return
        }
        
        // Fallback: Source not in cache (rare case)
        // This might happen if a new IME was installed after app launch
        Logger.warning("IME not found in cache, refreshing: \(inputSourceID)", category: .ime)
        
        // Refresh cache and try again
        initializeCache()
        
        // Try again with thread-safe read
        cacheQueue.sync {
            cachedSource = inputSourceCache[inputSourceID]
        }
        
        if let source = cachedSource {
            let result = TISSelectInputSource(source)
            if result != noErr {
                throw ModSwitchIMEError.inputMethodSwitchFailed("TISSelectInputSource failed with code: \(result)")
            }
            return
        }
        
        throw ModSwitchIMEError.inputSourceNotFound(inputSourceID)
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
    }
    
    @objc private func inputSourcesChanged(_ notification: Notification) {
        Logger.debug("Input sources changed, refreshing cache", category: .ime)
        // Refresh cache when system IMEs change
        refreshInputSourceCache()
    }
    
    // Removed performSwitch and related methods - no longer needed after simplification
    
    func getCurrentInputSource() -> String {
        return ThreadSafetyUtils.executeOnMainThreadWithDefault(
            timeout: 1.0,
            defaultValue: "Unknown",
            execute: { [weak self] in
                self?.getCurrentInputSourceSync() ?? "Unknown"
            }
        )
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
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
