import Foundation

/// Enhanced error with context information
struct ErrorContext {
    let error: ModSwitchIMEError
    let timestamp: Date
    let stackTrace: [String]
    let context: [String: Any]
    let file: String
    let function: String
    let line: Int
    
    init(
        error: ModSwitchIMEError,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.error = error
        self.timestamp = Date()
        self.stackTrace = Thread.callStackSymbols
        self.context = context
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.function = function
        self.line = line
    }
    
    var detailedDescription: String {
        return """
        Error: \(error.localizedDescription)
        Location: \(file):\(line) in \(function)
        Timestamp: \(timestamp)
        Context: \(context)
        Stack Trace:
        \(stackTrace.prefix(10).joined(separator: "\n"))
        """
    }
    
    func log(category: Logger.Category = .main) {
        Logger.error(detailedDescription, category: category)
    }
}

/// Enhanced error handler with context preservation
protocol ContextualErrorHandler: ErrorHandler {
    func handleError(_ errorContext: ErrorContext)
}

extension ContextualErrorHandler {
    func handleError(_ error: ModSwitchIMEError, context: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        let errorContext = ErrorContext(
            error: error,
            context: context,
            file: file,
            function: function,
            line: line
        )
        handleError(errorContext)
    }
}