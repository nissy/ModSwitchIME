import Foundation

// Protocol for consistent error handling
protocol ErrorHandler {
    func handleError(_ error: ModSwitchIMEError)
}

// Extension providing default implementation
extension ErrorHandler {
    func logError(_ error: ModSwitchIMEError, category: Logger.Category = .main) {
        switch error {
        case .accessibilityPermissionDenied:
            Logger.error("Accessibility permission denied", category: category)
        case .inputSourceNotFound(let id):
            Logger.error("Input source not found: \(id)", category: category)
        case .launchAtLoginFailed(let underlyingError):
            Logger.error("Launch at login failed: \(underlyingError)", category: category)
        case .imeControllerInitializationFailed:
            Logger.error("IME controller initialization failed", category: category)
        case .invalidConfiguration:
            Logger.error("Invalid configuration detected", category: category)
        case .systemError(let underlyingError):
            Logger.error("System error: \(underlyingError)", category: category)
        case .eventTapCreationFailed(let reason):
            Logger.error("Event tap creation failed: \(reason)", category: category)
        case .eventTapDisabled(let automatic):
            Logger.error("Event tap disabled (automatic: \(automatic))", category: category)
        }
    }
    
    func shouldShowAlert(for error: ModSwitchIMEError) -> Bool {
        switch error {
        case .eventTapDisabled(let automatic):
            return !automatic  // Only show alert for user-triggered disables
        case .eventTapCreationFailed(let reason):
            return reason.contains("Maximum retries")  // Only show for final failure
        default:
            return true
        }
    }
    
    func shouldRetry(for error: ModSwitchIMEError) -> Bool {
        switch error {
        case .eventTapCreationFailed, .eventTapDisabled(automatic: true):
            return true
        default:
            return false
        }
    }
}
