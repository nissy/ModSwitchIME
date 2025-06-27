import Foundation
import CoreGraphics
@testable import ModSwitchIME

// Common type alias to avoid conflicts
typealias ModSwitchIMELogger = ModSwitchIME.Logger

// ImeController already conforms to IMEControlling protocol defined in main app

// Shared Mock ImeController for testing
class FixedMockImeController: IMEControlling {
    var switchToSpecificIMECalls: [(ime: String, time: CFAbsoluteTime)] = []
    private var currentIME: String = "com.apple.keylayout.US"  // Different from test IMEs
    
    func switchToSpecificIME(_ targetIMEId: String) {
        switchToSpecificIMECalls.append((ime: targetIMEId, time: CFAbsoluteTimeGetCurrent()))
        currentIME = targetIMEId
    }
    
    func getCurrentInputSource() -> String {
        return currentIME
    }
    
    func forceAscii() {
        switchToSpecificIME("com.apple.keylayout.ABC")
    }
}
