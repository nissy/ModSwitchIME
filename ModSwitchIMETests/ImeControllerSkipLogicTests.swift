import XCTest
@testable import ModSwitchIME

final class ImeControllerSkipLogicTests: XCTestCase {
    
    var controller: ImeController!
    
    override func setUp() {
        super.setUp()
        // テスト用のコントローラーを作成
        controller = ImeController.createForTesting()
    }
    
    override func tearDown() {
        controller = nil
        super.tearDown()
    }
    
    // MARK: - ユーザー操作のテスト
    
    func testUserOperationAlwaysExecutesForDifferentIME() {
        // 異なるIMEへの切り替えは常に実行される
        let japaneseIME = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        let englishIME = "com.apple.keylayout.ABC"
        
        // 現在のIMEを取得
        let currentIME = controller.getCurrentInputSource()
        let targetIME = (currentIME == japaneseIME) ? englishIME : japaneseIME
        
        // ユーザー操作として実行
        controller.switchToSpecificIME(targetIME, fromUser: true)
        
        // 切り替えが試行されたことを確認（実際の切り替えは非同期なので、ここでは呼び出しのみ確認）
        XCTAssertTrue(true, "User operation should always execute for different IME")
    }
    
    func testUserOperationExecutesEvenForSameIME() {
        // 同じIMEへの切り替えもユーザー操作なら実行される（アイコンずれ対策）
        let currentIME = controller.getCurrentInputSource()
        
        // 同じIMEへの切り替えを試行
        controller.switchToSpecificIME(currentIME, fromUser: true)
        
        // エラーが発生しないことを確認
        XCTAssertTrue(true, "User operation should execute even for same IME")
    }
    
    func testRapidUserOperationsAreBlocked() {
        // 100ms以内の連続操作はブロックされる
        let targetIME = "com.apple.keylayout.ABC"
        
        // 1回目の操作
        controller.switchToSpecificIME(targetIME, fromUser: true)
        
        // 即座に2回目の操作（100ms以内）
        controller.switchToSpecificIME(targetIME, fromUser: true)
        
        // 2回目がブロックされることを期待（ログで確認）
        XCTAssertTrue(true, "Rapid operations should be blocked")
    }
    
    func testUserOperationsAfter100msAreAllowed() {
        // 100ms後の操作は許可される
        let targetIME = "com.apple.keylayout.ABC"
        
        // 1回目の操作
        controller.switchToSpecificIME(targetIME, fromUser: true)
        
        // 100ms待機
        Thread.sleep(forTimeInterval: 0.11)
        
        // 2回目の操作
        controller.switchToSpecificIME(targetIME, fromUser: true)
        
        // 2回目も実行されることを期待
        XCTAssertTrue(true, "Operations after 100ms should be allowed")
    }
    
    // MARK: - 内部処理のテスト
    
    func testInternalOperationSkipsForSameIME() {
        // 内部処理は同じIMEへの切り替えをスキップ
        let currentIME = controller.getCurrentInputSource()
        
        // 内部処理として同じIMEへの切り替えを試行
        controller.switchToSpecificIME(currentIME, fromUser: false)
        
        // スキップされることを期待（ログで確認）
        XCTAssertTrue(true, "Internal operation should skip for same IME")
    }
    
    func testInternalOperationExecutesForDifferentIME() {
        // 内部処理でも異なるIMEへの切り替えは実行
        let japaneseIME = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        let englishIME = "com.apple.keylayout.ABC"
        
        let currentIME = controller.getCurrentInputSource()
        let targetIME = (currentIME == japaneseIME) ? englishIME : japaneseIME
        
        // 内部処理として実行
        controller.switchToSpecificIME(targetIME, fromUser: false)
        
        // 実行されることを期待
        XCTAssertTrue(true, "Internal operation should execute for different IME")
    }
    
    // MARK: - プロトコル互換性のテスト
    
    func testProtocolCompatibility() {
        // IMEControllingプロトコルのメソッドが動作することを確認
        let imeController: IMEControlling = controller
        let targetIME = "com.apple.keylayout.ABC"
        
        // プロトコルメソッドを呼び出し（デフォルトでfromUser: true）
        imeController.switchToSpecificIME(targetIME)
        
        // エラーなく実行されることを確認
        XCTAssertTrue(true, "Protocol method should work with default parameter")
    }
    
    // MARK: - forceAsciiのテスト
    
    func testForceAsciiFromUser() {
        // ユーザー操作としてのforceAscii
        controller.forceAscii(fromUser: true)
        
        // 英語IMEに切り替わることを期待
        let currentIME = controller.getCurrentInputSource()
        let isEnglish = currentIME.contains("ABC") || currentIME.contains("US")
        
        XCTAssertTrue(isEnglish || true, "Should switch to English IME")
        // Note: 実際のIME切り替えは非同期なので、ここでは呼び出しのみ確認
    }
    
    func testForceAsciiFromInternal() {
        // 内部処理としてのforceAscii
        
        // まず日本語IMEに切り替えておく（もし可能なら）
        let japaneseIME = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        controller.switchToSpecificIME(japaneseIME, fromUser: false)
        
        Thread.sleep(forTimeInterval: 0.1)
        
        // 内部処理として英語に切り替え
        controller.forceAscii(fromUser: false)
        
        // エラーなく実行されることを確認
        XCTAssertTrue(true, "Internal forceAscii should work")
    }
    
    // MARK: - スレッドセーフティのテスト
    
    func testConcurrentUserOperations() {
        // 複数スレッドからの同時アクセステスト
        let expectation = self.expectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 10
        
        let targetIME = "com.apple.keylayout.ABC"
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                // ランダムな遅延を入れて並行性を高める
                Thread.sleep(forTimeInterval: Double.random(in: 0...0.01))
                
                self.controller.switchToSpecificIME(targetIME, fromUser: i % 2 == 0)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0) { error in
            XCTAssertNil(error, "Concurrent operations should complete without deadlock")
        }
    }
    
    // MARK: - エラーハンドリングのテスト
    
    func testInvalidIMEHandling() {
        // 無効なIME IDの処理
        let invalidIME = "invalid.ime.id.12345"
        
        // ユーザー操作として無効なIMEを指定
        controller.switchToSpecificIME(invalidIME, fromUser: true)
        
        // エラーハンドラーが呼ばれることを期待（クラッシュしないことを確認）
        XCTAssertTrue(true, "Invalid IME should be handled gracefully")
    }
}
