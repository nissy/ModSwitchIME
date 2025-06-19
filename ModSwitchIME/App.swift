import SwiftUI

@main
struct ModSwitchIMEApp: App {
    @StateObject private var menuBarApp = MenuBarApp()
    
    init() {
        Logger.info("ModSwitchIME app initialized")
    }
    
    var body: some Scene {
        // Settingsシーンのみを定義（WindowGroupは不要）
        Settings {
            PreferencesView()
                .environmentObject(menuBarApp.preferences)
        }
    }
}
