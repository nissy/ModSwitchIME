import Foundation

enum ModSwitchIMEError: LocalizedError {
    case accessibilityPermissionDenied
    case inputSourceNotFound(String)
    case launchAtLoginFailed(Error)
    case imeControllerInitializationFailed
    case invalidConfiguration
    case systemError(Error)
    case eventTapCreationFailed(reason: String)
    case eventTapDisabled(automatic: Bool)
    
    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required for ModSwitchIME to function properly."
        case .inputSourceNotFound(let id):
            return "Input source '\(id)' was not found on the system."
        case .launchAtLoginFailed(let error):
            return "Failed to update launch at login setting: \(error.localizedDescription)"
        case .imeControllerInitializationFailed:
            return "Failed to initialize IME controller."
        case .invalidConfiguration:
            return "Invalid configuration detected."
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        case .eventTapCreationFailed(let reason):
            return "Failed to create event tap: \(reason)"
        case .eventTapDisabled(let automatic):
            return automatic ? "Event tap was automatically disabled by the system." 
                : "Event tap was disabled due to user input timeout."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Grant permission in System Preferences > Security & Privacy > Privacy > Accessibility."
        case .inputSourceNotFound:
            return "Please select a different input source in preferences."
        case .launchAtLoginFailed:
            return "Try toggling the launch at login setting again."
        case .imeControllerInitializationFailed:
            return "Please restart the application."
        case .invalidConfiguration:
            return "Please reset preferences to default values."
        case .systemError:
            return "Please try again or restart the application."
        case .eventTapCreationFailed:
            return "Check accessibility permissions and try restarting the application."
        case .eventTapDisabled(let automatic):
            return automatic ? "The application will attempt to re-enable monitoring automatically." 
                : "Try clicking slower or check your system's security settings."
        }
    }
}
