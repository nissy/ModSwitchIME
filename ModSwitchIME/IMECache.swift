import Foundation
import Carbon

/// LRU cache for IME information with size limit
class IMECache {
    private struct CachedInputSource {
        let sourceRef: TISInputSource
        let localizedName: String
        let lastAccessTime: Date
    }
    
    private var cache: [String: CachedInputSource] = [:]
    private let maxCacheSize = 100
    private let cacheQueue = DispatchQueue(label: "com.modswitchime.imecache", attributes: .serial)
    
    func get(_ imeId: String) -> (sourceRef: TISInputSource, localizedName: String)? {
        return cacheQueue.sync {
            if let cached = cache[imeId] {
                // Update access time
                cache[imeId] = CachedInputSource(
                    sourceRef: cached.sourceRef,
                    localizedName: cached.localizedName,
                    lastAccessTime: Date()
                )
                return (cached.sourceRef, cached.localizedName)
            }
            return nil
        }
    }
    
    func set(_ imeId: String, sourceRef: TISInputSource, localizedName: String) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Add new entry
            self.cache[imeId] = CachedInputSource(
                sourceRef: sourceRef,
                localizedName: localizedName,
                lastAccessTime: Date()
            )
            
            // Check cache size and evict if necessary
            if self.cache.count > self.maxCacheSize {
                self.evictLeastRecentlyUsed()
            }
        }
    }
    
    func clear() {
        cacheQueue.async { [weak self] in
            self?.cache.removeAll()
        }
    }
    
    func remove(_ imeId: String) {
        cacheQueue.async { [weak self] in
            self?.cache.removeValue(forKey: imeId)
        }
    }
    
    private func evictLeastRecentlyUsed() {
        // Find the least recently used entry
        let sorted = cache.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }
        
        // Remove the first 20% of entries
        let countToRemove = max(1, cache.count / 5)
        for i in 0..<countToRemove {
            if i < sorted.count {
                cache.removeValue(forKey: sorted[i].key)
            }
        }
        
        Logger.debug("Evicted \(countToRemove) entries from IME cache", category: .main)
    }
    
    func validateCache() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            var invalidKeys: [String] = []
            
            for (key, value) in self.cache {
                // Check if the input source is still valid
                if !self.isInputSourceValid(value.sourceRef) {
                    invalidKeys.append(key)
                }
            }
            
            // Remove invalid entries
            for key in invalidKeys {
                self.cache.removeValue(forKey: key)
            }
            
            if !invalidKeys.isEmpty {
                Logger.info("Removed \(invalidKeys.count) invalid entries from IME cache", category: .main)
            }
        }
    }
    
    private func isInputSourceValid(_ source: TISInputSource) -> Bool {
        // Check if the input source is still in the system's list
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return false
        }
        
        for systemSource in sources {
            if let systemID = TISGetInputSourceProperty(systemSource, kTISPropertyInputSourceID),
               let sourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                let systemIDString = Unmanaged<CFString>.fromOpaque(systemID).takeUnretainedValue() as String
                let sourceIDString = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
                if systemIDString == sourceIDString {
                    return true
                }
            }
        }
        
        return false
    }
}