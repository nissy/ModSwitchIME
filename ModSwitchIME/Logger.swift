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
    
    // File logging support
    private static let logFileURL: URL? = {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        guard let documentsPath = documentsPath else { return nil }
        let logPath = (documentsPath as NSString).appendingPathComponent("ModSwitchIME_debug.log")
        return URL(fileURLWithPath: logPath)
    }()
    
    private static let fileHandle: FileHandle? = {
        guard let url = logFileURL else { return nil }
        
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
        
        // Open for writing
        return try? FileHandle(forWritingTo: url)
    }()
    
    private static func writeToFile(_ message: String, level: String, category: Category) {
        guard let handle = fileHandle else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] [\(level)] [\(category)] \(message)\n"
        
        if let data = logLine.data(using: .utf8) {
            handle.seekToEndOfFile()
            handle.write(data)
        }
    }
    
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
    
    // Debug logging - always enabled for troubleshooting
    static func debug(_ message: String, category: Category = .main) {
        category.logger.debug("\(message)")
        writeToFile(message, level: "DEBUG", category: category)
    }
    
    // Info logging - important operational messages
    static func info(_ message: String, category: Category = .main) {
        category.logger.info("\(message)")
        writeToFile(message, level: "INFO", category: category)
    }
    
    // Error logging - always logged
    static func error(_ message: String, category: Category = .main) {
        category.logger.error("\(message)")
        // Only write errors to file
        writeToFile(message, level: "ERROR", category: category)
    }
    
    // Warning logging
    static func warning(_ message: String, category: Category = .main) {
        category.logger.warning("\(message)")
        // Only write warnings to file
        writeToFile(message, level: "WARNING", category: category)
    }
    
    // Get log file path for debugging
    static func getLogFilePath() -> String? {
        return logFileURL?.path
    }
    
    // Read recent log entries (last N lines)
    static func getRecentLogs(lines: Int = 50) -> String {
        guard let logPath = getLogFilePath(),
              FileManager.default.fileExists(atPath: logPath) else {
            return "Log file not found"
        }
        
        do {
            let content = try String(contentsOfFile: logPath)
            let allLines = content.components(separatedBy: .newlines)
            let recentLines = Array(allLines.suffix(lines))
            return recentLines.joined(separator: "\n")
        } catch {
            return "Error reading log file: \(error)"
        }
    }
    
    // Clear log file
    static func clearLogFile() {
        guard let logPath = getLogFilePath() else { return }
        try? "".write(toFile: logPath, atomically: true, encoding: .utf8)
    }
}
