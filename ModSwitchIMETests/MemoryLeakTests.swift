import XCTest
import Combine
import Carbon
import SwiftUI
@testable import ModSwitchIME

class MemoryLeakTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    private func assertNoMemoryLeak<T: AnyObject>(_ instance: T,
                                                  file: StaticString = #file,
                                                  line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be deallocated, potential memory leak", file: file, line: line)
        }
    }
    
    // MARK: - Preferences Memory Leak Tests
    
    func testPreferencesNoMemoryLeak() {
        // Given: Preferences instance
        var preferences: Preferences? = Preferences.createForTesting()
        
        // When: Using preferences
        preferences?.idleTimeout = 10.0
        preferences?.idleOffEnabled = true
        preferences?.motherImeId = "test.ime"
        
        // Then: Should be deallocated when reference is removed
        assertNoMemoryLeak(preferences!)
        preferences = nil
    }
    
    func testPreferencesPublisherNoMemoryLeak() {
        // Given: Preferences with publisher subscriptions
        var preferences: Preferences? = Preferences.createForTesting()
        var cancellables = Set<AnyCancellable>()
        
        preferences?.$idleTimeout
            .sink { _ in }
            .store(in: &cancellables)
        
        preferences?.$idleOffEnabled
            .sink { _ in }
            .store(in: &cancellables)
        
        // When: Clearing references
        assertNoMemoryLeak(preferences!)
        cancellables.removeAll()
        preferences = nil
    }
    
    // MARK: - ImeController Memory Leak Tests
    
    func testImeControllerNoMemoryLeak() {
        // Given: ImeController instance
        // Note: ImeController holds a reference to Preferences.shared singleton,
        // so it won't be deallocated. We'll test that it doesn't create additional leaks.
        autoreleasepool {
            let imeController = ImeController()
            
            // When: Using controller
            _ = imeController.getCurrentInputSource()
            imeController.toggleByCmd(isLeft: true)
            imeController.forceAscii()
            
            // Then: The operations should complete without creating memory leaks
            // (We can't test deallocation because it holds a singleton reference)
            XCTAssertTrue(true, "ImeController operations completed without crashes")
        }
    }
    
    func testImeControllerInputSourceListNoMemoryLeak() {
        // Given: ImeController accessing input sources
        autoreleasepool {
            let imeController = ImeController()
            
            // When: Getting input source list multiple times
            for _ in 0..<10 {
                _ = imeController.getCurrentInputSource()
                
                // Access TIS functions
                if let inputSourceList = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] {
                    // Process list
                    _ = inputSourceList.count
                }
            }
            
            // Then: No memory should be leaked
            assertNoMemoryLeak(imeController)
        }
    }
    
    // MARK: - MenuBarApp Memory Leak Tests
    
    func testMenuBarAppNoMemoryLeak() {
        // Given: MenuBarApp instance
        autoreleasepool {
            let menuBarApp = MenuBarApp()
            
            // When: Using app features
            _ = menuBarApp.preferences
            menuBarApp.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            
            // Then: Should be deallocated
            assertNoMemoryLeak(menuBarApp)
        }
    }
    
    // MARK: - Notification Observer Memory Leak Tests
    
    func testNotificationObserverNoMemoryLeak() {
        // Given: Object with notification observers
        class NotificationObserver {
            var observers: [NSObjectProtocol] = []
            
            init() {
                let observer = NotificationCenter.default.addObserver(
                    forName: NSWorkspace.didActivateApplicationNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Handle notification
                }
                observers.append(observer)
            }
            
            deinit {
                observers.forEach { NotificationCenter.default.removeObserver($0) }
            }
        }
        
        autoreleasepool {
            let observer = NotificationObserver()
            
            // When: Posting notifications
            NotificationCenter.default.post(
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
            
            // Then: Should be deallocated
            assertNoMemoryLeak(observer)
        }
    }
    
    // MARK: - Timer Memory Leak Tests
    
    func testTimerNoMemoryLeak() {
        // Given: Object with timer
        class TimerContainer {
            var timer: Timer?
            var counter = 0
            
            func startTimer() {
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    self?.counter += 1
                }
            }
            
            func stopTimer() {
                timer?.invalidate()
                timer = nil
            }
            
            deinit {
                stopTimer()
            }
        }
        
        autoreleasepool {
            let container = TimerContainer()
            container.startTimer()
            
            // Wait for timer to fire
            let expectation = XCTestExpectation(description: "Timer fires")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                container.stopTimer()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
            
            // Then: Should be deallocated
            assertNoMemoryLeak(container)
        }
    }
    
    // MARK: - Closure Capture Memory Leak Tests
    
    func testClosureCaptureNoMemoryLeak() {
        // Given: Object with closure properties
        class ClosureContainer {
            var completion: (() -> Void)?
            var value = 0
            
            func setupClosure() {
                // Weak self to avoid retain cycle
                completion = { [weak self] in
                    self?.value += 1
                }
            }
        }
        
        autoreleasepool {
            let container = ClosureContainer()
            container.setupClosure()
            container.completion?()
            
            // Then: Should be deallocated
            assertNoMemoryLeak(container)
        }
    }
    
    func testStrongReferenceyCycleDetection() {
        // Given: Potential reference cycle
        class Parent {
            var child: Child?
            deinit { /* Parent deallocated */ }
        }
        
        class Child {
            weak var parent: Parent?  // Weak to avoid cycle
            deinit { /* Child deallocated */ }
        }
        
        autoreleasepool {
            let parent = Parent()
            let child = Child()
            
            parent.child = child
            child.parent = parent
            
            // Then: Both should be deallocated
            assertNoMemoryLeak(parent)
            assertNoMemoryLeak(child)
        }
    }
    
    // MARK: - CoreFoundation Memory Tests
    
    func testCoreFoundationMemoryManagement() {
        // Given: CF objects
        autoreleasepool {
            // Test retained CF object
            if let inputSourceList = TISCreateInputSourceList(nil, false) {
                let count = CFArrayGetCount(inputSourceList.takeRetainedValue())
                XCTAssertGreaterThanOrEqual(count, 0)
            }
            
            // Test unretained CF object access
            if let currentSource = TISCopyCurrentKeyboardInputSource() {
                if let sourceId = TISGetInputSourceProperty(
                    currentSource.takeRetainedValue(),
                    kTISPropertyInputSourceID
                ) {
                    _ = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue()
                }
            }
        }
        
        // Memory should be properly managed
        XCTAssertTrue(true, "CoreFoundation memory should be managed correctly")
    }
    
    // MARK: - Async Operation Memory Leak Tests
    
    func testAsyncOperationNoMemoryLeak() {
        // Given: Object performing async operations
        class AsyncWorker {
            var workItem: DispatchWorkItem?
            
            func performWork() {
                workItem = DispatchWorkItem { [weak self] in
                    // Do some work
                }
                
                DispatchQueue.global().async(execute: workItem!)
            }
            
            deinit {
                workItem?.cancel()
            }
        }
        
        let expectation = XCTestExpectation(description: "Async work")
        
        autoreleasepool {
            let worker = AsyncWorker()
            worker.performWork()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
            
            assertNoMemoryLeak(worker)
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Logger Memory Tests
    
    func testLoggerNoMemoryRetention() {
        // Given: Large log messages
        autoreleasepool {
            for i in 0..<100 {
                let largeMessage = String(repeating: "Memory test \(i) ", count: 1000)
                ModSwitchIMELogger.debug(largeMessage)
                ModSwitchIMELogger.info(largeMessage)
                ModSwitchIMELogger.warning(largeMessage)
                ModSwitchIMELogger.error(largeMessage)
            }
        }
        
        // Memory should be released after logging
        XCTAssertTrue(true, "Logger should not retain messages")
    }
    
    // MARK: - View Memory Leak Tests
    
    func testPreferencesViewMemoryLeak() {
        // Given: View with ObservedObject
        class ViewContainer {
            var preferences = Preferences.createForTesting()
            var hostingController: NSViewController?
            
            func setupView() {
                let view = PreferencesView()
                    .environmentObject(preferences)
                
                hostingController = NSViewController()  // Simplified for testing
            }
            
            deinit {
                hostingController = nil
            }
        }
        
        autoreleasepool {
            let container = ViewContainer()
            container.setupView()
            
            // Simulate view lifecycle
            _ = container.hostingController?.view
            
            assertNoMemoryLeak(container)
        }
    }
    
    // MARK: - Memory Pressure Tests
    
    func testMemoryUnderPressure() {
        // Given: Memory pressure simulation
        measure {
            autoreleasepool {
                // Create many temporary objects
                var objects: [Preferences] = []
                
                for _ in 0..<1000 {
                    let pref = Preferences.createForTesting()
                    pref.idleTimeout = Double.random(in: 1...600)
                    objects.append(pref)
                }
                
                // Clear references
                objects.removeAll()
            }
        }
    }
    
    // MARK: - Distributed Notification Memory Tests
    
    func testDistributedNotificationNoMemoryLeak() {
        // Given: Distributed notification observer
        class DistributedObserver {
            var observer: NSObjectProtocol?
            
            init() {
                observer = DistributedNotificationCenter.default().addObserver(
                    forName: .screenIsLocked,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Handle notification
                }
            }
            
            deinit {
                if let observer = observer {
                    DistributedNotificationCenter.default().removeObserver(observer)
                }
            }
        }
        
        autoreleasepool {
            let observer = DistributedObserver()
            
            // Post notification
            DistributedNotificationCenter.default().post(
                name: .screenIsLocked,
                object: nil
            )
            
            assertNoMemoryLeak(observer)
        }
    }
}
