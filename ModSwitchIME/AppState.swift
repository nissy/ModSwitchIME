import Foundation
import Combine

/// Centralized application state management
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var currentIME: String = ""
    @Published var isMonitoring: Bool = false
    @Published var hasAccessibilityPermission: Bool = false
    @Published var isShowingPermissionAlert: Bool = false
    @Published var lastPermissionCheckTime = Date(timeIntervalSince1970: 0)
    @Published var keyMonitorError: ModSwitchIMEError?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Monitor accessibility permission changes
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateAccessibilityPermission()
            }
            .store(in: &cancellables)
    }
    
    func updateAccessibilityPermission() {
        let newStatus = AccessibilityManager.shared.hasPermission
        if newStatus != hasAccessibilityPermission {
            hasAccessibilityPermission = newStatus
            Logger.info("Accessibility permission changed to: \(newStatus)", category: .main)
        }
    }
    
    func setMonitoringState(_ monitoring: Bool) {
        isMonitoring = monitoring
    }
    
    func setCurrentIME(_ ime: String) {
        currentIME = ime
    }
    
    func handleError(_ error: ModSwitchIMEError) {
        keyMonitorError = error
        Logger.error("App state error: \(error)", category: .main)
    }
    
    func clearError() {
        keyMonitorError = nil
    }
    
    func shouldShowPermissionAlert() -> Bool {
        guard !isShowingPermissionAlert else { return false }
        
        let now = Date()
        if now.timeIntervalSince(lastPermissionCheckTime) < 10 {
            return false
        }
        
        return true
    }
    
    func markPermissionAlertShown() {
        isShowingPermissionAlert = true
        lastPermissionCheckTime = Date()
    }
    
    func markPermissionAlertDismissed() {
        isShowingPermissionAlert = false
    }
}