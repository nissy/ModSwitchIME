import SwiftUI
import Cocoa
import ApplicationServices
import ServiceManagement

// MARK: - Notification Names
extension NSNotification.Name {
    static let screenIsLocked = NSNotification.Name("com.apple.screenIsLocked")
    static let screenIsUnlocked = NSNotification.Name("com.apple.screenIsUnlocked")
}

class MenuBarApp: NSObject, ObservableObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem?
    let preferences = Preferences.shared
    private var preferencesWindowController: NSWindowController?
    private var aboutWindowController: NSWindowController?
    private var keyMonitor: KeyMonitor?
    
    // 権限要求の重複防止用
    private var isShowingPermissionAlert = false
    private var lastPermissionCheckTime = Date(timeIntervalSince1970: 0)
    
    override init() {
        super.init()
        // Ensure UI operations happen on main thread
        if Thread.isMainThread {
            initializeComponents()
        } else {
            DispatchQueue.main.sync {
                initializeComponents()
            }
        }
    }
    
    private func initializeComponents() {
        checkAccessibilityPermissions()
        setupMenuBar()
        setupKeyMonitor()
        updateLaunchAtLoginMenuItem()
        setupSystemNotifications()
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
            // 重複表示を防ぐ
            guard !self.isShowingPermissionAlert else {
                Logger.debug("Permission alert already showing, skipping")
                return
            }
            
            // 短時間内の連続要求を防ぐ（10秒以内は無視）
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
                ModSwitchIME needs permission to detect modifier key presses.
                
                ⚠️ Important Privacy Information:
                • ONLY modifier keys (⌘, ⇧, ⌃, ⌥) are monitored
                • NO text input or regular keystrokes are captured
                • NO data is stored or transmitted
                • All processing happens locally on your Mac
                • You can revoke access anytime in System Settings
                
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
            self?.statusBarItem?.button?.title = "✓"
            
            // Restore after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self?.statusBarItem?.button?.title = "⌘"
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
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: aboutWindowController?.window,
            queue: .main
        ) { _ in
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    @objc private func showPreferences() {
        // Create settings window directly
        if preferencesWindowController == nil {
            let preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            preferencesWindow.center()
            preferencesWindow.title = "Preferences"
            preferencesWindow.isReleasedWhenClosed = false
            
            let hostingController = NSHostingController(rootView: PreferencesView().environmentObject(preferences))
            preferencesWindow.contentViewController = hostingController
            
            preferencesWindowController = NSWindowController(window: preferencesWindow)
        }
        
        // Activate app (required for LSUIElement apps)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        
        // Restore activation policy when window closes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: preferencesWindowController?.window,
            queue: .main
        ) { _ in
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    @objc private func toggleLaunchAtLogin() {
        preferences.launchAtLogin.toggle()
        
        // Use SMAppService API (available in macOS 13.0+, we're targeting macOS 15.0)
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
            statusBarItem?.button?.title = "⚠️"
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.statusBarItem?.button?.title = "⌘"
            }
            
            // Show alert only for final failure
            if error.errorDescription?.contains("Maximum retries") == true {
                showErrorAlert(error: error)
            }
            
        case .eventTapDisabled(let automatic):
            // Show warning in menu bar
            statusBarItem?.button?.title = "⚠️"
            
            if !automatic {
                // User input timeout - show brief notification
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.statusBarItem?.button?.title = "⌘"
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
    
    @objc private func systemWillSleep(_ notification: Notification) {
        // System is going to sleep
        Logger.debug("System will sleep")
    }
    
    @objc private func systemDidWake(_ notification: Notification) {
        // System woke up
        Logger.debug("System did wake")
    }
    
    @objc private func screenDidLock(_ notification: Notification) {
        // Screen locked
        Logger.debug("Screen did lock")
    }
    
    @objc private func screenDidUnlock(_ notification: Notification) {
        // Screen unlocked - no action needed
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
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
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
                
                Link("GitHub Repository", destination: URL(string: "https://github.com/nissy/ModSwitchIME")!)
                    .font(.caption)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}
