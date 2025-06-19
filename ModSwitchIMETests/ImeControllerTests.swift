import XCTest
@testable import ModSwitchIME

class ImeControllerTests: XCTestCase {
    var imeController: ImeController!
    
    override func setUp() {
        super.setUp()
        imeController = ImeController()
    }
    
    override func tearDown() {
        imeController = nil
        super.tearDown()
    }
    
    // 右cmdを2回押した場合のテスト
    func testRightCmdDoublePress() {
        // 初期状態: 英語
        // 1回目の右cmd: 設定されたIMEに切り替え
        // 2回目の右cmd: 同じIMEのまま（英字モードに切り替わらない）
        
        // Given: 英語入力の状態
        imeController.forceAscii()
        
        // When: 右cmdを押す（1回目）
        imeController.toggleByCmd(isLeft: false)
        let firstPressResult = imeController.getCurrentInputSource()
        
        // Then: 英語以外のIMEに切り替わっている
        XCTAssertFalse(firstPressResult.contains("ABC") || firstPressResult.contains("U.S."))
        
        // When: 右cmdを押す（2回目）
        imeController.toggleByCmd(isLeft: false)
        let secondPressResult = imeController.getCurrentInputSource()
        
        // Then: 同じIMEのまま（英語に戻らない）
        XCTAssertEqual(firstPressResult, secondPressResult)
        XCTAssertFalse(secondPressResult.contains("ABC") || secondPressResult.contains("U.S."))
    }
    
    // 左cmd→右cmdの通常動作テスト
    func testNormalToggleBehavior() {
        // Given: IME入力の状態
        imeController.toggleByCmd(isLeft: false)
        
        // When: 左cmdを押す
        imeController.toggleByCmd(isLeft: true)
        let leftCmdResult = imeController.getCurrentInputSource()
        
        // Then: 英語に切り替わる
        XCTAssertTrue(leftCmdResult.contains("ABC") || leftCmdResult.contains("U.S."))
        
        // When: 右cmdを押す
        imeController.toggleByCmd(isLeft: false)
        let rightCmdResult = imeController.getCurrentInputSource()
        
        // Then: 英語以外のIMEに切り替わる
        XCTAssertFalse(rightCmdResult.contains("ABC") || rightCmdResult.contains("U.S."))
    }
    
    // アイドルタイムアウトのテスト
    func testIdleTimeout() {
        // Given: IME入力の状態
        imeController.toggleByCmd(isLeft: false)
        
        // When: アイドルタイムアウトが発生
        imeController.forceAscii()
        let result = imeController.getCurrentInputSource()
        
        // Then: 英語に切り替わる
        XCTAssertTrue(result.contains("ABC") || result.contains("U.S."))
    }
}
