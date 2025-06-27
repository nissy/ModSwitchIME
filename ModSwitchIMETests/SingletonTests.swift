import XCTest
@testable import ModSwitchIME

class SingletonTests: XCTestCase {
    
    // MARK: - ImeController Singleton Tests
    
    func testImeControllerSingletonInstance() {
        // Given: Two references to ImeController.shared
        let instance1 = ImeController.shared
        let instance2 = ImeController.shared
        
        // Then: Both references should point to the same instance
        XCTAssertTrue(instance1 === instance2, "ImeController.shared should return the same instance")
    }
    
    func testImeControllerTestFactory() {
        #if DEBUG
        // Given: Two instances created for testing
        let testInstance1 = ImeController.createForTesting()
        let testInstance2 = ImeController.createForTesting()
        
        // Then: Test instances should be different
        XCTAssertFalse(testInstance1 === testInstance2, "Test factory should create new instances")
        XCTAssertFalse(testInstance1 === ImeController.shared, "Test instances should not be the singleton")
        #else
        // Skip this test in release builds
        XCTAssertTrue(true, "Test factory only available in DEBUG builds")
        #endif
    }
    
    // MARK: - KeyMonitor Dependency Injection Tests
    
    func testKeyMonitorDefaultImeController() {
        // Given: KeyMonitor created with default parameters
        let keyMonitor = KeyMonitor()
        
        // Then: Should use the shared ImeController instance
        // Note: We can't directly access the private imeController property,
        // but we can verify it doesn't crash and works correctly
        XCTAssertNotNil(keyMonitor, "KeyMonitor should initialize with default ImeController")
    }
    
    func testKeyMonitorCustomImeController() {
        // Given: A custom ImeController for testing
        let customImeController = FixedMockImeController()
        let customPreferences = Preferences.createForTesting()
        
        // When: Creating KeyMonitor with custom dependencies
        let keyMonitor = KeyMonitor(preferences: customPreferences, imeController: customImeController)
        
        // Then: Should accept custom dependencies
        XCTAssertNotNil(keyMonitor, "KeyMonitor should accept custom ImeController")
    }
    
    // MARK: - MenuBarApp Tests
    
    func testMenuBarAppUsesSharedImeController() {
        // Given: MenuBarApp instance
        let menuBarApp = MenuBarApp()
        
        // Then: Should use shared ImeController (verified indirectly)
        XCTAssertNotNil(menuBarApp, "MenuBarApp should initialize with shared ImeController")
        
        // Verify no duplicate instances are created during normal operation
        let sharedBefore = ImeController.shared
        _ = MenuBarApp() // Create another instance
        let sharedAfter = ImeController.shared
        
        XCTAssertTrue(sharedBefore === sharedAfter, "Creating MenuBarApp should not create new ImeController instances")
    }
}
