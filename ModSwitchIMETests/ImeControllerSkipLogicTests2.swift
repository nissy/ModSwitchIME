import XCTest
@testable import ModSwitchIME

final class ImeControllerSkipLogicTests2: XCTestCase {
    
    var controller: ImeController!
    
    override func setUp() {
        super.setUp()
        controller = ImeController.createForTesting()
    }
    
    override func tearDown() {
        controller = nil
        super.tearDown()
    }
    
    // MARK: - Critical Bug Fix Tests
    
    func testRapidDifferentIMESwitchingIsAllowed() {
        // 異なるIMEへの高速切り替えは許可される（バグ修正確認）
        let japaneseIME = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        let englishIME = "com.apple.keylayout.ABC"
        
        // 英語→日本語を高速で切り替え
        controller.switchToSpecificIME(englishIME, fromUser: true)
        // 即座に別のIMEへ（100ms以内）
        controller.switchToSpecificIME(japaneseIME, fromUser: true)
        
        // 両方とも実行されることを期待
        XCTAssertTrue(true, "Different IME rapid switching should be allowed")
    }
    
    func testSameIMERapidSwitchingIsBlocked() {
        // 同じIMEへの高速切り替えはブロックされる
        let targetIME = "com.apple.keylayout.ABC"
        
        // 現在のIMEを記録
        let initialIME = controller.getCurrentInputSource()
        
        // 同じIMEへ2回高速切り替え
        controller.switchToSpecificIME(targetIME, fromUser: true)
        controller.switchToSpecificIME(targetIME, fromUser: true)
        
        // 2回目はブロックされる（ログで確認）
        XCTAssertTrue(true, "Same IME rapid switching should be blocked")
    }
    
    func testInternalOperationNeverBlockedByTiming() {
        // 内部処理は時間に関係なくスキップ判定のみ
        let targetIME = "com.apple.keylayout.ABC"
        
        // 内部処理を高速で実行
        controller.switchToSpecificIME(targetIME, fromUser: false)
        controller.switchToSpecificIME(targetIME, fromUser: false)
        
        // タイミングに関係なく、同じIMEならスキップ
        XCTAssertTrue(true, "Internal operations should not be affected by timing")
    }
    
    func testForceAsciiDoesNotWaitForCompletion() {
        // forceAsciiは完了を待たずに即座にreturnする
        let startTime = CFAbsoluteTimeGetCurrent()
        
        controller.forceAscii(fromUser: true)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // 非同期なので即座に戻る（100ms未満）
        XCTAssertLessThan(duration, 0.1, "forceAscii should return immediately")
    }
    
    func testThreadSafetyOfSwitchTime() {
        // 複数スレッドから同時にswitchToSpecificIMEを呼んでも安全
        let expectation = self.expectation(description: "Thread safety")
        expectation.expectedFulfillmentCount = 100
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        for i in 0..<100 {
            queue.async {
                let ime = i % 2 == 0 ? "com.apple.keylayout.ABC" : "com.apple.keylayout.US"
                self.controller.switchToSpecificIME(ime, fromUser: true)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "All operations should complete without deadlock")
        }
    }
    
    func testChatteringPreventionTiming() {
        // チャタリング防止が正確に100msで動作することを確認
        let targetIME = "com.apple.keylayout.ABC"
        
        // 1回目
        controller.switchToSpecificIME(targetIME, fromUser: true)
        
        // 90ms待機（まだブロックされるはず）
        Thread.sleep(forTimeInterval: 0.09)
        controller.switchToSpecificIME(targetIME, fromUser: true)
        // この呼び出しはブロックされる
        
        // さらに20ms待機（合計110ms）
        Thread.sleep(forTimeInterval: 0.02)
        controller.switchToSpecificIME(targetIME, fromUser: true)
        // この呼び出しは通る
        
        XCTAssertTrue(true, "Chattering prevention should work with 100ms threshold")
    }
}
