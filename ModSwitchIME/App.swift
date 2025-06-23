import SwiftUI

@main
struct ModSwitchIMEApp: App {
    @StateObject private var menuBarApp = MenuBarApp()
    
    init() {
        Logger.info("ModSwitchIME app initialized")
    }
    
    var body: some Scene {
        // Define only Settings scene (WindowGroup is not needed)
        Settings {
            PreferencesView()
                .environmentObject(menuBarApp.preferences)
        }
    }
}
