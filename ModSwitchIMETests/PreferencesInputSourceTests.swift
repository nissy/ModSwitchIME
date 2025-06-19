import XCTest
@testable import ModSwitchIME

class PreferencesInputSourceTests: XCTestCase {
    
    func testGetAvailableInputSources() {
        let sources = Preferences.getAvailableInputSources()
        
        // 少なくとも1つの入力ソースがあることを確認
        XCTAssertGreaterThan(sources.count, 0, "利用可能な入力ソースが見つかりません")
        
        // 各入力ソースにIDと名前があることを確認
        for source in sources {
            XCTAssertFalse(source.id.isEmpty, "入力ソースのIDが空です")
            XCTAssertFalse(source.name.isEmpty, "入力ソースの名前が空です")
        }
    }
    
    func testGetAllInputSources() {
        let enabledSources = Preferences.getAllInputSources(includeDisabled: false)
        let allSources = Preferences.getAllInputSources(includeDisabled: true)
        
        // すべてのソースの数は有効なソースの数以上であるべき
        XCTAssertGreaterThanOrEqual(allSources.count, enabledSources.count)
        
        // 各ソースが有効なプロパティを持つことを確認
        for source in allSources {
            XCTAssertFalse(source.sourceId.isEmpty, "ソースIDが空です")
            XCTAssertFalse(source.localizedName.isEmpty, "ローカライズ名が空です")
        }
    }
    
    func testInputSourceIconMapping() {
        // 日本語
        let jaIcon = Preferences.getInputSourceIcon("com.apple.inputmethod.Kotoeri.Japanese")
        XCTAssertEqual(jaIcon, "🇯🇵")
        
        // 英語
        let enIcon = Preferences.getInputSourceIcon("com.apple.keylayout.ABC")
        XCTAssertEqual(enIcon, "🇺🇸")
        
        // 中国語
        let cnIcon = Preferences.getInputSourceIcon("com.apple.inputmethod.SCIM.ITABC")
        XCTAssertEqual(cnIcon, "🇨🇳")
        
        // 韓国語
        let koIcon = Preferences.getInputSourceIcon("com.apple.inputmethod.Korean.2SetKorean")
        XCTAssertEqual(koIcon, "🇰🇷")
        
        // 不明なソース
        let unknownIcon = Preferences.getInputSourceIcon("unknown.source.id")
        XCTAssertEqual(unknownIcon, "⌨️")
    }
    
    func testInputSourceLanguageDetection() {
        // 日本語の検出
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.apple.inputmethod.Kotoeri.Japanese"), "Japanese")
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.google.inputmethod.Japanese.Hiragana"), "Japanese")
        XCTAssertEqual(Preferences.getInputSourceLanguage("ATOK.Japanese"), "Japanese")
        
        // 中国語の検出
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.apple.inputmethod.SCIM.ITABC"), "Chinese")
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.apple.inputmethod.TCIM.Cangjie"), "Chinese")
        
        // 韓国語の検出
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.apple.inputmethod.Korean.2SetKorean"), "Korean")
        
        // その他
        XCTAssertEqual(Preferences.getInputSourceLanguage("com.apple.keylayout.US"), "English & Others")
        XCTAssertEqual(Preferences.getInputSourceLanguage("unknown.source.id"), "English & Others")
    }
    
    func testInputSourceCategoryClassification() {
        // キーボードレイアウト
        XCTAssertEqual(Preferences.getInputSourceCategory("com.apple.keylayout.ABC"), "Keyboard Layout")
        XCTAssertEqual(Preferences.getInputSourceCategory("com.apple.keylayout.US"), "Keyboard Layout")
        
        // 入力メソッド
        XCTAssertEqual(Preferences.getInputSourceCategory("com.apple.inputmethod.Kotoeri.Japanese"), "Input Method")
        XCTAssertEqual(Preferences.getInputSourceCategory("ATOK.Japanese"), "Input Method")
        XCTAssertEqual(Preferences.getInputSourceCategory("com.google.inputmethod.Japanese"), "Input Method")
        
        // その他
        XCTAssertEqual(Preferences.getInputSourceCategory("unknown.source.id"), "Others")
    }
    
    func testInputSourceFiltering() {
        let availableSources = Preferences.getAvailableInputSources()
        
        // キーボードレイアウトが除外されていることを確認（getAvailableInputSourcesはIMEのみを返す）
        let hasABC = availableSources.contains { $0.id.hasPrefix("com.apple.keylayout.") }
        XCTAssertFalse(hasABC, "キーボードレイアウトは除外されるべきです")
        
        // 代わりに、getAllInputSourcesでキーボードレイアウトが含まれることを確認
        let allSources = Preferences.getAllInputSources()
        let hasABCInAll = allSources.contains { $0.sourceId == "com.apple.keylayout.ABC" }
        // これはシステムによって異なる可能性があります
        
        // IMEが含まれることを確認
        let hasIME = availableSources.contains { 
            $0.id.contains("inputmethod") || $0.id.contains("ATOK") || $0.id.contains("atok") 
        }
        // IMEがインストールされていない可能性もあるため、警告のみ
        if !hasIME {
            print("Warning: No IME found in available sources")
        }
        
        // getAvailableInputSourcesはABCキーボードレイアウトを除外する
        let filteredSources = Preferences.getAvailableInputSources()
        let hasABCInFiltered = filteredSources.contains { $0.id == "com.apple.keylayout.ABC" }
        XCTAssertFalse(hasABCInFiltered, "ABCキーボードレイアウトは除外されるべきです")
    }
}
