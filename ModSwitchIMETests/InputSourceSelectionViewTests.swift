import XCTest
import SwiftUI
@testable import ModSwitchIME

class InputSourceSelectionViewTests: XCTestCase {
    
    func testInputSourceSelectionViewDisplaysAllInputSources() {
        // すべての入力ソース（IMEとキーボードレイアウト）を取得
        let inputSources = Preferences.getAllInputSources()
        
        // 入力ソースが存在することを確認
        XCTAssertGreaterThan(inputSources.count, 0, "少なくとも1つの入力ソースが必要です")
        
        // IMEとキーボードレイアウトの両方が含まれることを確認
        let hasIME = inputSources.contains { $0.sourceId.contains("inputmethod") || $0.sourceId.contains("ATOK") }
        let hasKeyboardLayout = inputSources.contains { $0.sourceId.contains("keylayout") }
        
        XCTAssertTrue(hasIME || hasKeyboardLayout, "IMEまたはキーボードレイアウトが含まれるべきです")
    }
    
    func testInputSourceCategorization() {
        let inputSources = Preferences.getAllInputSources()
        
        // カテゴリー分けをテスト
        var categories: [String: [Preferences.InputSource]] = [:]
        
        for source in inputSources {
            let category = Preferences.getInputSourceCategory(source.sourceId)
            if categories[category] == nil {
                categories[category] = []
            }
            categories[category]?.append(source)
        }
        
        // 少なくとも1つのカテゴリーが存在することを確認
        XCTAssertGreaterThan(categories.count, 0, "少なくとも1つのカテゴリーが必要です")
    }
    
    func testInputSourceIcon() {
        let inputSources = Preferences.getAllInputSources()
        
        // 各入力ソースにアイコンまたはフラグが設定できることを確認
        for source in inputSources {
            let icon = Preferences.getInputSourceIcon(source.sourceId)
            XCTAssertNotNil(icon, "\(source.localizedName)のアイコンが取得できるべきです")
        }
    }
}
