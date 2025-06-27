import Foundation
import Cocoa

/// Manages accessibility permission handling and UI
class PermissionManager {
    private weak var appState: AppState?
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func checkAndRequestPermission() {
        AccessibilityManager.shared.refreshPermissionStatus()
        
        if AccessibilityManager.shared.hasPermission {
            appState?.hasAccessibilityPermission = true
            NotificationCenter.default.post(name: .permissionGranted, object: nil)
        } else {
            showAccessibilityAlert()
        }
    }
    
    func showAccessibilityAlert() {
        guard let appState = appState,
              appState.shouldShowPermissionAlert() else { return }
        
        appState.markPermissionAlertShown()
        
        DispatchQueue.main.async {
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
                AccessibilityManager.openSystemPreferences()
            }
            
            appState.markPermissionAlertDismissed()
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

extension NSNotification.Name {
    static let permissionGranted = NSNotification.Name("com.modswitchime.permissionGranted")
}