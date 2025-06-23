import XCTest
import CoreGraphics
@testable import ModSwitchIME

class LongSinglePressTest: XCTestCase {
    var keyMonitor: KeyMonitor!
    var mockImeController: FixedMockImeController!
    var preferences: Preferences!
    
    override func setUp() {
        super.setUp()
        preferences = Preferences.createForTesting()
        
        // Setup test IME mappings
        preferences.setIME("com.apple.keylayout.ABC", for: .leftCommand)
        preferences.setKeyEnabled(true, for: .leftCommand)
        
        // Create KeyMonitor with mock ImeController
        keyMonitor = KeyMonitor(preferences: preferences)
        mockImeController = FixedMockImeController()
        #if DEBUG
        keyMonitor.setImeController(mockImeController)
        #endif
    }
    
    override func tearDown() {
        keyMonitor?.stop()
        keyMonitor = nil
        mockImeController = nil
        preferences = nil
        super.tearDown()
    }
    
    func testShortSinglePress() {
        #if DEBUG
        print("\n=== Testing Short Single Press (< 300ms) ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Press and release quickly (short press)
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        
        // Short delay (100ms)
        Thread.sleep(forTimeInterval: 0.1)
        
        let beforeRelease = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        let afterRelease = mockImeController.switchToSpecificIMECalls.count
        
        print("Short press switches: \(afterRelease - beforeRelease)")
        XCTAssertEqual(afterRelease, beforeRelease + 1, "Short single press should trigger IME switch")
        #endif
    }
    
    func testLongSinglePress() {
        #if DEBUG
        print("\n=== Testing Long Single Press (> 300ms) ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Press and hold for long time
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        
        // Long delay (500ms - longer than singleKeyTimeout)
        Thread.sleep(forTimeInterval: 0.5)
        
        let beforeRelease = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        let afterRelease = mockImeController.switchToSpecificIMECalls.count
        
        print("Long press switches: \(afterRelease - beforeRelease)")
        
        // This is currently failing, but should work
        XCTAssertEqual(afterRelease, beforeRelease + 1, "Long single press should ALSO trigger IME switch (this is the bug!)")
        #endif
    }
    
    func testVeryLongSinglePress() {
        #if DEBUG
        print("\n=== Testing Very Long Single Press (> 1000ms) ===")
        
        mockImeController.switchToSpecificIMECalls.removeAll()
        
        // Press and hold for very long time
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: ModifierKey.leftCommand.flagMask)
        
        // Very long delay (1000ms)
        Thread.sleep(forTimeInterval: 1.0)
        
        let beforeRelease = mockImeController.switchToSpecificIMECalls.count
        keyMonitor.simulateFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [])
        let afterRelease = mockImeController.switchToSpecificIMECalls.count
        
        print("Very long press switches: \(afterRelease - beforeRelease)")
        
        // This should also work
        XCTAssertEqual(afterRelease, beforeRelease + 1, "Very long single press should ALSO trigger IME switch")
        #endif
    }
}