import XCTest
@testable import ModSwitchIME

final class IconMappingTests: XCTestCase {
    func testUSAndABCReturnUSFlag() {
        XCTAssertEqual(Preferences.getInputSourceIcon("com.apple.keylayout.US"), "🇺🇸")
        XCTAssertEqual(Preferences.getInputSourceIcon("com.apple.keylayout.ABC"), "🇺🇸")
    }

    func testJapaneseVendorsReturnJPFlag() {
        // Google Japanese Input
        XCTAssertEqual(Preferences.getInputSourceIcon("com.google.inputmethod.Japanese"), "🇯🇵")
        XCTAssertEqual(Preferences.getInputSourceIcon("com.google.inputmethod.japanese.Hiragana"), "🇯🇵")

        // ATOK
        XCTAssertEqual(Preferences.getInputSourceIcon("jp.co.justsystems.inputmethod.atok34.Japanese"), "🇯🇵")

        // Apple Kotoeri
        XCTAssertEqual(Preferences.getInputSourceIcon("com.apple.inputmethod.Kotoeri.Japanese"), "🇯🇵")
    }

    func testChineseVariantsReturnCNFlag() {
        XCTAssertEqual(Preferences.getInputSourceIcon("com.apple.inputmethod.SCIM.Pinyin"), "🇨🇳")
        XCTAssertEqual(Preferences.getInputSourceIcon("com.apple.inputmethod.TCIM.Cangjie"), "🇨🇳")
        XCTAssertEqual(Preferences.getInputSourceIcon("com.apple.inputmethod.Shuangpin"), "🇨🇳")
    }

    func testKoreanVietnameseThaiReturnFlags() {
        XCTAssertEqual(Preferences.getInputSourceIcon("com.apple.inputmethod.Korean.Hangul"), "🇰🇷")
        XCTAssertEqual(Preferences.getInputSourceIcon("com.example.vietnamese.Telex"), "🇻🇳")
        XCTAssertEqual(Preferences.getInputSourceIcon("com.apple.inputmethod.Thai"), "🇹🇭")
    }

    func testUnknownReturnsKeyboard() {
        XCTAssertEqual(Preferences.getInputSourceIcon("com.example.unknown.input"), "⌨️")
    }
}
