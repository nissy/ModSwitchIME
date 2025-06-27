import Foundation

/// Comprehensive error recovery strategy
class ErrorRecoveryStrategy {
    enum RecoveryAction {
        case retry(delay: TimeInterval, maxAttempts: Int)
        case recreate
        case requestPermission
        case notifyUser
        case ignore
        case terminate
    }
    
    private var retryAttempts: [String: Int] = [:]
    
    func determineRecoveryAction(for error: ModSwitchIMEError) -> RecoveryAction {
        switch error {
        case .eventTapCreationFailed:
            let attempts = retryAttempts["eventTap", default: 0]
            if attempts < 3 {
                return .retry(delay: Double(attempts + 1) * 2.0, maxAttempts: 3)
            } else {
                return .notifyUser
            }
            
        case .eventTapDisabled(let automatic):
            if automatic {
                return .recreate
            } else {
                return .retry(delay: 1.0, maxAttempts: 1)
            }
            
        case .accessibilityPermissionDenied:
            return .requestPermission
            
        case .inputSourceNotFound:
            return .retry(delay: 0.5, maxAttempts: 2)
            
        case .imeControllerInitializationFailed:
            return .terminate
            
        case .invalidConfiguration:
            return .notifyUser
            
        case .systemError(let underlyingError):
            // Analyze underlying error
            if (underlyingError as NSError).code == NSFileReadNoSuchFileError {
                return .ignore
            } else {
                return .notifyUser
            }
            
        case .launchAtLoginFailed:
            return .notifyUser
            
        case .invalidInputSource:
            return .retry(delay: 1.0, maxAttempts: 1)
            
        case .inputMethodSwitchFailed:
            return .retry(delay: 0.1, maxAttempts: 2)
        }
    }
    
    func recordRetryAttempt(for identifier: String) {
        retryAttempts[identifier, default: 0] += 1
    }
    
    func resetRetryAttempts(for identifier: String) {
        retryAttempts.removeValue(forKey: identifier)
    }
    
    func executeRecovery(
        action: RecoveryAction,
        identifier: String,
        onRetry: @escaping () -> Void,
        onRecreate: @escaping () -> Void,
        onRequestPermission: @escaping () -> Void,
        onNotifyUser: @escaping (String) -> Void
    ) {
        switch action {
        case .retry(let delay, let maxAttempts):
            recordRetryAttempt(for: identifier)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                onRetry()
            }
            
        case .recreate:
            resetRetryAttempts(for: identifier)
            onRecreate()
            
        case .requestPermission:
            onRequestPermission()
            
        case .notifyUser:
            onNotifyUser("An error occurred that requires your attention.")
            
        case .ignore:
            Logger.debug("Ignoring error for \(identifier)", category: .main)
            
        case .terminate:
            Logger.error("Fatal error, terminating application", category: .main)
            NSApplication.shared.terminate(nil)
        }
    }
}