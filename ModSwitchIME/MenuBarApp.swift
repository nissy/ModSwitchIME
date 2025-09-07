// swiftlint:disable file_length
import SwiftUI
import Cocoa
import ApplicationServices
import ServiceManagement
// Default delay used to debounce icon refresh and wait for TIS state stabilization
private let defaultIconRefreshDelay: TimeInterval = 0.06

// MARK: - Notification Names
extension NSNotification.Name {
    static let screenIsLocked = NSNotification.Name("com.apple.screenIsLocked")
    static let screenIsUnlocked = NSNotification.Name("com.apple.screenIsUnlocked")
}

#if DEBUG
extension MenuBarApp {
    static var debugIconUpdateCount: Int = 0
    static func debugResetIconUpdateCount() { debugIconUpdateCount = 0 }
}
#endif

// swiftlint:disable:next type_body_length
final class MenuBarApp: NSObject, ObservableObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem?
    let preferences = Preferences.shared
    private var preferencesWindowController: NSWindowController?
    private var aboutWindowController: NSWindowController?
    private var keyMonitor: KeyMonitor?
    private var windowCloseObservers: [NSObjectProtocol] = []
    // Cache for IME display names to avoid repeated TIS lookups
    private var imeDisplayNameCache: [String: String] = [:]
    // Debounced icon refresh work item to avoid flicker and race with TIS
    private var iconRefreshWorkItem: DispatchWorkItem?
    
    // Shared ImeController instance to avoid duplication
    // Note: This ImeController will also monitor IME changes for cache updates,
    // which complements our MenuBarApp monitoring for UI updates
    private let imeController = ImeController.shared
    
    // Prevent duplicate permission requests
    private var isShowingPermissionAlert = false
    private var lastPermissionCheckTime = Date(timeIntervalSince1970: 0)
    
    override init() {
        super.init()
        // Ensure UI operations happen on main thread
        // Use async to avoid potential deadlock
        DispatchQueue.main.async { [weak self] in
            self?.initializeComponents()
        }
    }
    
    private func initializeComponents() {
        checkAccessibilityPermissions()
        setupMenuBar()
        setupKeyMonitor()
        updateLaunchAtLoginMenuItem()
        setupSystemNotifications()
        setupIMEStateMonitoring()
    }
    
    private func checkAccessibilityPermissions() {
        // Check permissions (without showing prompt)
        let trusted = AccessibilityManager.shared.hasPermission
        Logger.debug("Accessibility permission status: \(trusted)")
        
        if !trusted {
            Logger.info("Accessibility permission not granted")
            // Don't show alert automatically on startup
        } else {
            Logger.debug("Accessibility permission already granted")
        }
    }
    
    private func showAccessibilityAlert() {
        // Ensure alert is shown on main thread
        DispatchQueue.main.async {
            // Prevent duplicate display
            guard !self.isShowingPermissionAlert else {
                Logger.debug("Permission alert already showing, skipping")
                return
            }
            
            // Prevent consecutive requests within a short time (ignore within 10 seconds)
            let now = Date()
            if now.timeIntervalSince(self.lastPermissionCheckTime) < 10 {
                Logger.debug("Permission alert requested too recently, skipping")
                return
            }
            
            self.isShowingPermissionAlert = true
            self.lastPermissionCheckTime = now
            
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                ModSwitchIME needs Accessibility permission to detect modifier key presses for IME switching.
                
                🔒 Privacy Guarantee:
                • Detects key presses only to distinguish shortcuts from single modifier keys
                • NO text content, keystrokes, or personal data captured
                • NO data stored, logged, or transmitted anywhere
                • All processing happens locally on your Mac
                • Open source code available for security review
                • Permission can be revoked anytime
                
                Please enable ModSwitchIME in:
                System Settings → Privacy & Security → Accessibility
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            
            NSApp.activate(ignoringOtherApps: true)
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open system settings
                AccessibilityManager.openSystemPreferences()
            }
            
            self.isShowingPermissionAlert = false
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    private func setupKeyMonitor() {
        keyMonitor = KeyMonitor()
        
        // Set up error handler
        keyMonitor?.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.handleKeyMonitorError(error)
            }
        }
        
        // Check accessibility permission status
        if AccessibilityManager.shared.hasPermission {
            Logger.debug("Accessibility permission already trusted, starting KeyMonitor immediately")
            keyMonitor?.start()
            updateMenuState(enabled: true)
        } else {
            Logger.info("Accessibility permission not granted, KeyMonitor not started")
            updateMenuState(enabled: false)
        }
    }
    
    private func showPermissionGrantedNotification() {
        // Temporarily change menu bar icon to notify
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusBarItem?.button else { return }
            
            // Save current image
            let originalImage = button.image
            let originalTitle = button.title
            
            // Show checkmark
            if let checkImage = NSImage(systemSymbolName: "checkmark.circle.fill", 
                                        accessibilityDescription: "Permission Granted") {
                checkImage.isTemplate = true
                button.image = checkImage
                button.title = ""
            } else {
                button.image = nil
                button.title = "✓"
            }
            
            // Restore after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard self != nil else { return }
                button.image = originalImage
                button.title = originalTitle
            }
        }
        
        Logger.info("Permission granted notification shown")
    }
    
    @objc private func checkPermission() {
        AccessibilityManager.shared.refreshPermissionStatus()  // Force refresh
        
        if AccessibilityManager.shared.hasPermission {
            // Permission already granted
            keyMonitor?.start()
            updateMenuState(enabled: true)
            showPermissionGrantedNotification()
        } else {
            // No permission
            showAccessibilityAlert()
        }
    }
    
    private func updateMenuState(enabled: Bool) {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            guard let menu = self.statusBarItem?.menu else { return }
            
            // Toggle enable/disable for permission-related menu items
            for item in menu.items {
                switch item.tag {
                case 100: // Grant Permissions
                    // Gray out when permission is granted
                    item.isEnabled = !enabled
                    item.title = enabled ? "Accessibility Granted ✓" : "Permission Not Granted"
                case 101: // Preferences
                    item.isEnabled = enabled
                case 102: // Launch at Login
                    // Launch at Login is always enabled
                    break
                default:
                    // Other menus like Quit are always enabled
                    break
                }
            }
            
            // Also change icon based on permission status
            if let button = self.statusBarItem?.button {
                if enabled {
                    if let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "IME Switcher") {
                        image.isTemplate = true
                        button.image = image
                        button.imagePosition = .imageOnly
                        button.title = ""
                    } else {
                        button.image = nil
                        button.title = "🌐"
                    }
                    // After enabling (and possibly starting KeyMonitor), refresh with actual IME
                    self.refreshIconDebounced()
                } else {
                    if let image = NSImage(
                        systemSymbolName: "globe.badge.chevron.backward",
                        accessibilityDescription: "IME Switcher - Permission Required"
                    ) {
                        image.isTemplate = true
                        button.image = image
                        button.imagePosition = .imageOnly
                        button.title = ""
                    } else {
                        button.image = nil
                        button.title = "🌐❓"
                    }
                }
            }
        }
    }
    
    private func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem?.button {
            // Use SF Symbol for automatic dark mode support
            if let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "IME Switcher") {
                image.isTemplate = true // Enable automatic color adaptation
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                // Fallback to emoji if SF Symbol not available
                button.title = "🌐"
            }
            button.toolTip = "ModSwitchIME - IME Switcher"
        }
        
        let menu = createMenu()
        statusBarItem?.menu = menu
        
        // Set menu delegate for dynamic updates
        menu.delegate = self
    }
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // About
        addMenuItem(to: menu, title: "About ModSwitchIME", action: #selector(showAbout))
        menu.addItem(NSMenuItem.separator())
        
        // Preferences & Permissions
        addMenuItem(to: menu, title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",", tag: 101)
        addMenuItem(to: menu, title: "Grant Permissions...", action: #selector(checkPermission), tag: 100)
        menu.addItem(NSMenuItem.separator())
        
        // Launch at Login
        addMenuItem(to: menu, title: "Launch at Login", action: #selector(toggleLaunchAtLogin), tag: 102)
        menu.addItem(NSMenuItem.separator())
        
        // Restart
        addMenuItem(
            to: menu,
            title: "Restart ModSwitchIME",
            action: #selector(restartApp),
            keyEquivalent: "r",
            tag: 103
        )
        menu.addItem(NSMenuItem.separator())
        
        // Debug menu item (only in debug builds)
        #if DEBUG
        addMenuItem(to: menu, title: "Debug Info", action: #selector(showDebugInfo), keyEquivalent: "d")
        #endif
        
        // Quit
        addMenuItem(to: menu, title: "Quit", action: #selector(quit), keyEquivalent: "q")
        
        return menu
    }
    
    private func addMenuItem(to menu: NSMenu, title: String, action: Selector, keyEquivalent: String = "", tag: Int = 0) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        if tag != 0 {
            item.tag = tag
        }
        menu.addItem(item)
    }
    
    @objc private func showAbout() {
        // Create custom about window
        if aboutWindowController == nil {
            let aboutWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            aboutWindow.center()
            aboutWindow.title = "About ModSwitchIME"
            aboutWindow.isReleasedWhenClosed = false
            
            let hostingController = NSHostingController(rootView: AboutView())
            aboutWindow.contentViewController = hostingController
            
            aboutWindowController = NSWindowController(window: aboutWindow)
        }
        
        // Activate app to bring window to front
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
        
        // Restore activation policy when window closes
        var observerRef: NSObjectProtocol?
        observerRef = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: aboutWindowController?.window,
            queue: .main
        ) { [weak self, weak observerRef] _ in
            NSApp.setActivationPolicy(.accessory)
            // Clean up the observer after it fires
            if let self = self, let observer = observerRef,
               let index = self.windowCloseObservers.firstIndex(where: { $0 === observer }) {
                NotificationCenter.default.removeObserver(self.windowCloseObservers[index])
                self.windowCloseObservers.remove(at: index)
            }
        }
        if let observer = observerRef {
            windowCloseObservers.append(observer)
        }
    }
    
    @objc private func showPreferences() {
        // Create settings window directly
        if preferencesWindowController == nil {
            // Create hosting controller first to get the view
            let hostingController = NSHostingController(rootView: PreferencesView().environmentObject(preferences))
            
            // Create window with automatic sizing
            let preferencesWindow = NSWindow(
                contentViewController: hostingController
            )
            preferencesWindow.styleMask = [.titled, .closable, .miniaturizable]
            preferencesWindow.title = "Preferences"
            preferencesWindow.isReleasedWhenClosed = false
            
            // Center the window
            preferencesWindow.center()
            
            preferencesWindowController = NSWindowController(window: preferencesWindow)
        }
        
        // Activate app (required for LSUIElement apps)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        
        // Restore activation policy when window closes
        var observerRef: NSObjectProtocol?
        observerRef = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: preferencesWindowController?.window,
            queue: .main
        ) { [weak self, weak observerRef] _ in
            NSApp.setActivationPolicy(.accessory)
            // Clean up the observer after it fires
            if let self = self, let observer = observerRef,
               let index = self.windowCloseObservers.firstIndex(where: { $0 === observer }) {
                NotificationCenter.default.removeObserver(self.windowCloseObservers[index])
                self.windowCloseObservers.remove(at: index)
            }
        }
        if let observer = observerRef {
            windowCloseObservers.append(observer)
        }
    }
    
    @objc private func toggleLaunchAtLogin() {
        preferences.launchAtLogin.toggle()
        
        // Use SMAppService API (available in macOS 13.0+)
        do {
            if preferences.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            preferences.launchAtLogin.toggle()
        }
        
        updateLaunchAtLoginMenuItem()
    }
    
    private func updateLaunchAtLoginMenuItem() {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            if let menu = self.statusBarItem?.menu {
                for item in menu.items where item.action == #selector(self.toggleLaunchAtLogin) {
                    item.state = self.preferences.launchAtLogin ? .on : .off
                }
            }
        }
    }
    
    @objc private func quit() {
        cleanup()
        NSApplication.shared.terminate(nil)
    }
    
    private func cleanup() {
        // Stop KeyMonitor
        keyMonitor?.stop()
        keyMonitor = nil
    }
    
    private func showErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Error"
        
        if let modSwitchIMEError = error as? ModSwitchIMEError {
            alert.informativeText = modSwitchIMEError.errorDescription ?? error.localizedDescription
            if let recovery = modSwitchIMEError.recoverySuggestion {
                alert.informativeText += "\n\n\(recovery)"
            }
        } else {
            alert.informativeText = error.localizedDescription
        }
        
        alert.runModal()
    }
    
    private func handleKeyMonitorError(_ error: ModSwitchIMEError) {
        Logger.error("KeyMonitor error: \(error)", category: .keyboard)
        
        switch error {
        case .eventTapCreationFailed:
            // Show error in menu bar temporarily
            if let button = statusBarItem?.button {
                button.title = "⚠️"
                button.image = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    guard let self = self, let button = self.statusBarItem?.button else { return }
                    if let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "IME Switcher") {
                        image.isTemplate = true
                        button.image = image
                        button.title = ""
                    } else {
                        button.image = nil
                        button.title = "🌐"
                    }
                }
            }
            
            // Show alert only for final failure
            if error.errorDescription?.contains("Maximum retries") == true {
                showErrorAlert(error: error)
            }
            
        case .eventTapDisabled(let automatic):
            // Show warning in menu bar
            if let button = statusBarItem?.button {
                button.title = "⚠️"
                button.image = nil
                
                if !automatic {
                    // User input timeout - show brief notification
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        guard let self = self, let button = self.statusBarItem?.button else { return }
                        if let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "IME Switcher") {
                            image.isTemplate = true
                            button.image = image
                            button.title = ""
                        } else {
                            button.image = nil
                            button.title = "🌐"
                        }
                    }
                }
            }
            
        default:
            showErrorAlert(error: error)
        }
    }
    
    private func setupSystemNotifications() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // Listen for sleep notification
        notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        // Listen for wake notification
        notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Listen for screen lock/unlock
        let distributedCenter = DistributedNotificationCenter.default()
        distributedCenter.addObserver(
            self,
            selector: #selector(screenDidLock),
            name: .screenIsLocked,
            object: nil
        )
        
        distributedCenter.addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: .screenIsUnlocked,
            object: nil
        )
    }
    
    // MARK: - IME State Monitoring
    
    private func setupIMEStateMonitoring() {
        // Monitor system IME state changes for real-time icon updates
        // Note: ImeController also monitors this notification for cache updates
        // This creates two observers but serves different purposes:
        // - ImeController: Updates internal cache
        // - MenuBarApp: Updates menu bar icon
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(imeStateChanged),
            name: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil
        )

        // Invalidate display-name cache when enabled input sources change
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(imeEnabledListChanged),
            name: NSNotification.Name("com.apple.Carbon.TISNotifyEnabledKeyboardInputSourcesChanged"),
            object: nil
        )
        
        // Also monitor our internal IME switch notifications for immediate updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInternalIMESwitch),
            name: NSNotification.Name("ModSwitchIME.didSwitchIME"),
            object: nil
        )
        
        // Monitor for UI refresh requests (e.g., after errors)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUIRefreshRequest),
            name: NSNotification.Name("ModSwitchIME.shouldRefreshUI"),
            object: nil
        )
        
        // Initial icon update
        refreshIconDebounced()
    }
    
    @objc private func imeStateChanged(_ notification: Notification) {
        Logger.debug("IME state changed notification received", category: .main)
        refreshIconDebounced()
    }

    @objc private func imeEnabledListChanged(_ notification: Notification) {
        Logger.debug("IME enabled list changed - invalidating display name cache", category: .main)
        // Ensure thread-safety: mutate cache and update UI on main thread
        DispatchQueue.main.async { [weak self] in
            self?.imeDisplayNameCache.removeAll()
            self?.refreshIconDebounced()
        }
    }
    
    @objc private func handleInternalIMESwitch(_ notification: Notification) {
        Logger.debug("Internal IME switch notification received", category: .main)
        // Always refresh based on actual current IME (avoid optimistic UI updates)
        refreshIconDebounced()
    }
    
    @objc private func handleUIRefreshRequest(_ notification: Notification) {
        Logger.debug("UI refresh request received", category: .main)
        // Always update based on actual current IME state
        refreshIconDebounced()
    }
    
    @objc private func systemWillSleep(_ notification: Notification) {
        // System is going to sleep
        Logger.info("System will sleep - stopping KeyMonitor", category: .main)
        keyMonitor?.stop()
    }
    
    @objc private func systemDidWake(_ notification: Notification) {
        // System woke up
        Logger.info("System did wake - restarting KeyMonitor", category: .main)
        
        // Delay restart to ensure system is fully awake
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // Only restart if we have accessibility permission
            if AccessibilityManager.shared.hasPermission {
                self.keyMonitor?.start()
                Logger.info("KeyMonitor restarted after wake", category: .main)
            } else {
                Logger.warning("Cannot restart KeyMonitor - no accessibility permission", category: .main)
            }
        }
    }
    
    @objc private func screenDidLock(_ notification: Notification) {
        // Screen locked
        Logger.info("Screen did lock - pausing KeyMonitor", category: .main)
        // Don't stop KeyMonitor on screen lock, just log the event
        // Some users may want to use modifier keys to unlock
    }
    
    @objc private func screenDidUnlock(_ notification: Notification) {
        // Screen unlocked
        Logger.info("Screen did unlock", category: .main)
        // Ensure KeyMonitor is active if it should be
        if let monitor = keyMonitor, !monitor.isMonitoring, AccessibilityManager.shared.hasPermission {
            monitor.start()
            Logger.info("KeyMonitor restarted after screen unlock", category: .main)
        }
    }
    
    @objc private func restartApp() {
        // Get current application URL
        let appURL = Bundle.main.bundleURL
        
        // Create a separate process to relaunch the app
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", appURL.path]
        
        // Set up the process to run independently
        task.standardOutput = nil
        task.standardError = nil
        task.standardInput = nil
        
        do {
            // Launch the process
            try task.run()
            
            // Wait a moment to ensure the process starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Terminate current app
                NSApplication.shared.terminate(nil)
            }
        } catch {
            Logger.error("Failed to restart app: \(error.localizedDescription)", category: .main)
            
            // Fallback: Try using NSWorkspace
            let workspace = NSWorkspace.shared
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            
            workspace.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error = error {
                    Logger.error("Fallback restart also failed: \(error.localizedDescription)", category: .main)
                } else {
                    // If fallback succeeds, terminate after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }
    
    @objc private func showDebugInfo() {
        let alert = NSAlert()
        alert.messageText = "Debug Info"
        
        let idleEnabled = preferences.idleOffEnabled
        let idleTimeout = preferences.idleTimeout
        let timerRunning = keyMonitor?.isIdleTimerRunning ?? false
        
        // Get build timestamp
        let buildTimestamp = getBuildTimestamp()
        
        alert.informativeText = """
            Idle Auto Switch: \(idleEnabled ? "ON" : "OFF")
            Idle Timeout: \(Int(idleTimeout)) seconds
            Timer Running: \(timerRunning ? "YES" : "NO")
            
            KeyMonitor: \(keyMonitor != nil ? "Initialized" : "Not initialized")
            
            Build Time: \(buildTimestamp)
            """
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func getBuildTimestamp() -> String {
        // Get the app bundle
        guard let executableURL = Bundle.main.executableURL else {
            return "Unknown"
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: executableURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = TimeZone.current
                return formatter.string(from: modificationDate)
            }
        } catch {
            Logger.error("Failed to get build timestamp: \(error)")
        }
        
        return "Unknown"
    }
    
    // MARK: - NSApplicationDelegate
    
    func applicationWillTerminate(_ notification: Notification) {
        Logger.info("Application will terminate")
        cleanup()
    }
    
    deinit {
        keyMonitor?.stop()
        // Cancel any pending icon refresh
        iconRefreshWorkItem?.cancel()
        // Remove all notification observers to prevent memory leaks
        windowCloseObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowCloseObservers.removeAll()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}

// MARK: - IME Icon Management Extension

extension MenuBarApp {
    private func refreshIconDebounced(delay: TimeInterval? = nil) {
        // Coalesce multiple notifications and wait briefly for TIS state to settle
        iconRefreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.updateIconWithCurrentIME()
        }
        iconRefreshWorkItem = item
        let d = delay ?? defaultIconRefreshDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + d, execute: item)
    }

    private func updateIconWithCurrentIME() {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Note: IME state reading doesn't require accessibility permission
            // Only KeyMonitor functionality requires it, but menu bar icon can always be updated
            let currentIME = self.getCurrentIME()
            self.updateIconForIME(currentIME)
        }
    }
    
    private func getCurrentIME() -> String {
        // Use shared ImeController instance to avoid duplication
        return imeController.getCurrentInputSource()
    }
    
    private func updateIconForIME(_ imeId: String) {
        guard let button = statusBarItem?.button else { return }
        // Determine icon using unified helper (Preferences.getInputSourceIcon)
        let emoji = Preferences.getInputSourceIcon(imeId) ?? "⌨️"
        let displayName = getIMEDisplayName(imeId)
        let tooltip = "\(displayName) (\(imeId))"
        if emoji != "⌨️" {
            button.image = nil
            button.title = emoji
        } else {
            if let image = NSImage(systemSymbolName: "globe", accessibilityDescription: tooltip) {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                button.image = nil
                button.title = "🌐"
            }
        }
        button.toolTip = tooltip
        Logger.debug("Updated icon for IME (unified): \(imeId) -> \(emoji)", category: .main)
#if DEBUG
        Self.debugIconUpdateCount += 1
#endif
    }

    private func getIMEDisplayName(_ imeId: String) -> String {
        if let cached = imeDisplayNameCache[imeId] { return cached }
        let sources = Preferences.getAllInputSources(includeDisabled: false)
        if let source = sources.first(where: { $0.sourceId == imeId }) {
            imeDisplayNameCache[imeId] = source.localizedName
            return source.localizedName
        }
        let language = InputSourceManager.getInputSourceLanguage(imeId)
        let name = language.isEmpty ? imeId : language
        imeDisplayNameCache[imeId] = name
        return name
    }
    
    // getIconForIME/IconInfo removed in favor of Preferences.getInputSourceIcon
}

// MARK: - NSMenuDelegate

extension MenuBarApp: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        let wasGranted = keyMonitor?.isMonitoring ?? false
        let isGranted = AXIsProcessTrusted()
        
        // Check if permission was just granted
        if !wasGranted && isGranted && keyMonitor != nil {
            Logger.info("Accessibility permission detected via menu update - starting KeyMonitor")
            keyMonitor?.start()
            updateMenuState(enabled: true)
            showPermissionGrantedNotification()
        }
        
        for item in menu.items {
            switch item.tag {
            case 100: // Grant Permissions
                let hasPermission = AXIsProcessTrusted()
                item.isEnabled = !hasPermission
                item.title = hasPermission ? "Accessibility Granted ✓" : "Permission Not Granted"
            case 102: // Launch at Login
                item.state = preferences.launchAtLogin ? .on : .off
            case 103: // Restart
                // Always show normal restart option
                item.title = "Restart ModSwitchIME"
                item.attributedTitle = nil
            default:
                break
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App icon and name
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                
                Text("ModSwitchIME")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Privacy & Security Notice
            PrivacyNoticeView()
            
            Divider()
            
            // Credits
            VStack(spacing: 5) {
                Text("© 2025 nissy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let url = URL(string: "https://github.com/nissy/ModSwitchIME") {
                    Link("GitHub Repository", destination: url)
                        .font(.caption)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}
