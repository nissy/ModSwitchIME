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
    let preferences = Preferences()
    private var preferencesWindowController: NSWindowController?
    private var keyMonitor: KeyMonitor?
    
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
        let trusted = AXIsProcessTrusted()
        Logger.debug("Accessibility permission status: \(trusted)")
        
        if !trusted {
            Logger.info("Accessibility permission not granted")
        } else {
            Logger.debug("Accessibility permission already granted")
        }
    }
    
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        alert.informativeText = """
            ModSwitchIME needs permission to detect modifier key presses.
            
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
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupKeyMonitor() {
        keyMonitor = KeyMonitor()
        
        // Check accessibility permission status
        if AXIsProcessTrusted() {
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
        if AXIsProcessTrusted() {
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
        guard let menu = statusBarItem?.menu else { return }
        
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
        
        // Also change icon
        statusBarItem?.button?.title = enabled ? "⌘" : "⌘?"
    }
    
    private func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem?.button {
            button.title = "⌘"
            button.toolTip = "ModSwitchIME - IME Switcher"
        }
        
        let menu = NSMenu()
        
        let aboutItem = NSMenuItem(title: "About ModSwitchIME", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let preferencesItem = NSMenuItem(
            title: "Preferences...", 
            action: #selector(showPreferences), 
            keyEquivalent: ","
        )
        preferencesItem.target = self
        preferencesItem.tag = 101
        menu.addItem(preferencesItem)
        
        let permissionItem = NSMenuItem(
            title: "Grant Permissions...", 
            action: #selector(checkPermission), 
            keyEquivalent: ""
        )
        permissionItem.target = self
        permissionItem.tag = 100
        menu.addItem(permissionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login", 
            action: #selector(toggleLaunchAtLogin), 
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.tag = 102
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add restart item if needed
        let restartItem = NSMenuItem(
            title: "Restart ModSwitchIME",
            action: #selector(restartApp),
            keyEquivalent: "r"
        )
        restartItem.target = self
        restartItem.tag = 103
        menu.addItem(restartItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusBarItem?.menu = menu
        
        // Set menu delegate for dynamic updates
        menu.delegate = self
    }
    
    @objc private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }
    
    @objc private func showPreferences() {
        // Create settings window directly
        if preferencesWindowController == nil {
            let preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 700),
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
        if let menu = statusBarItem?.menu {
            for item in menu.items where item.action == #selector(toggleLaunchAtLogin) {
                item.state = preferences.launchAtLogin ? .on : .off
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
        // Get current application path
        let appPath = Bundle.main.bundleURL.path
        
        // Script to restart the app
        let script = """
            sleep 0.5
            open '\(appPath)'
        """
        
        // Execute script in background
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]
        task.launch()
        
        // Terminate current app
        NSApplication.shared.terminate(nil)
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
