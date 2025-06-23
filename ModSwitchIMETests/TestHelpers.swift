import Foundation
import CoreGraphics
@testable import ModSwitchIME

// Common type alias to avoid conflicts
typealias ModSwitchIMELogger = ModSwitchIME.Logger

// Shared Mock ImeController for testing
class FixedMockImeController: ImeController {
    var switchToSpecificIMECalls: [(ime: String, time: CFAbsoluteTime)] = []
    private var currentIME: String = "com.apple.keylayout.US"  // Different from test IMEs
    
    override func switchToSpecificIME(_ targetIMEId: String) {
        switchToSpecificIMECalls.append((ime: targetIMEId, time: CFAbsoluteTimeGetCurrent()))
        currentIME = targetIMEId
        // Mock switching to \(targetIMEId)
    }
    
    override func getCurrentInputSource() -> String {
        return currentIME
    }
}
