import SwiftUI
import Cocoa

/// Manages application windows (preferences, about, etc.)
class WindowManager {
    private var preferencesWindowController: NSWindowController?
    private var aboutWindowController: NSWindowController?
    private var windowCloseObservers: [NSObjectProtocol] = []
    
    func showPreferences(with preferences: Preferences) {
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
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: preferencesWindowController?.window,
            queue: .main
        ) { _ in
            NSApp.setActivationPolicy(.accessory)
        }
        windowCloseObservers.append(observer)
    }
    
    func showAbout() {
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
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
        
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: aboutWindowController?.window,
            queue: .main
        ) { _ in
            NSApp.setActivationPolicy(.accessory)
        }
        windowCloseObservers.append(observer)
    }
    
    func showDebugInfo(idleOffEnabled: Bool, idleTimeout: Double, timerRunning: Bool, keyMonitorInitialized: Bool) {
        let alert = NSAlert()
        alert.messageText = "Debug Info"
        
        let buildTimestamp = getBuildTimestamp()
        
        alert.informativeText = """
            Idle Auto Switch: \(idleOffEnabled ? "ON" : "OFF")
            Idle Timeout: \(Int(idleTimeout)) seconds
            Timer Running: \(timerRunning ? "YES" : "NO")
            
            KeyMonitor: \(keyMonitorInitialized ? "Initialized" : "Not initialized")
            
            Build Time: \(buildTimestamp)
            """
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func getBuildTimestamp() -> String {
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
    
    deinit {
        windowCloseObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowCloseObservers.removeAll()
    }
}