import Foundation

// Protocol for consistent error handling
protocol ErrorHandler {
    var onError: ((ModSwitchIMEError) -> Void)? { get set }
    func handleError(_ error: ModSwitchIMEError)
}

// Extension providing default implementation
extension ErrorHandler {
    func handleError(_ error: ModSwitchIMEError) {
        logError(error)
        onError?(error)
    }
    
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
        case .invalidInputSource(let message):
            Logger.error("Invalid input source: \(message)", category: category)
        case .inputMethodSwitchFailed(let message):
            Logger.error("Input method switch failed: \(message)", category: category)
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

/// Unified error handling utility
enum ErrorHandlingUtils {
    /// Execute a throwing function and handle errors uniformly
    static func executeWithErrorHandling<T>(
        operation: () throws -> T,
        errorHandler: ErrorHandler? = nil,
        defaultValue: T,
        category: Logger.Category = .main
    ) -> T {
        do {
            return try operation()
        } catch let error as ModSwitchIMEError {
            Logger.error(error.localizedDescription, category: category)
            errorHandler?.handleError(error)
            return defaultValue
        } catch {
            let wrappedError = ModSwitchIMEError.systemError(error)
            Logger.error(wrappedError.localizedDescription, category: category)
            errorHandler?.handleError(wrappedError)
            return defaultValue
        }
    }
}
