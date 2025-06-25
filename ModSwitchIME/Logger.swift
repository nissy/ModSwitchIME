import Foundation
import os

struct Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.ModSwitchIME"
    
    // Different categories for different parts of the app
    private static let mainLogger = os.Logger(subsystem: subsystem, category: "main")
    private static let imeLogger = os.Logger(subsystem: subsystem, category: "ime")
    private static let keyLogger = os.Logger(subsystem: subsystem, category: "keyboard")
    private static let preferencesLogger = os.Logger(subsystem: subsystem, category: "preferences")
    private static let testsLogger = os.Logger(subsystem: subsystem, category: "tests")
    
    // File logging removed for privacy - using os.Logger only
    
    enum Category {
        case main
        case ime
        case keyboard
        case preferences
        case tests
        
        var logger: os.Logger {
            switch self {
            case .main: return mainLogger
            case .ime: return imeLogger
            case .keyboard: return keyLogger
            case .preferences: return preferencesLogger
            case .tests: return testsLogger
            }
        }
    }
    
    // Debug logging - only for system events, no user data
    static func debug(_ message: String, category: Category = .main) {
        #if DEBUG
        // Only log to system (Console.app) for debugging
        category.logger.debug("\(message)")
        #endif
    }
    
    // Info logging - important operational messages only
    static func info(_ message: String, category: Category = .main) {
        category.logger.info("\(message)")
    }
    
    // Error logging - system errors only, no user data
    static func error(_ message: String, category: Category = .main) {
        category.logger.error("\(message)")
    }
    
    // Warning logging
    static func warning(_ message: String, category: Category = .main) {
        category.logger.warning("\(message)")
    }
    
    // File logging methods removed - use Console.app to view logs
}
