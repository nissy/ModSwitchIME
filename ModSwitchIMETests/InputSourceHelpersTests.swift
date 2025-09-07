import XCTest
@testable import ModSwitchIME

final class InputSourceHelpersTests: XCTestCase {
    func testIsChildIMEAndParentExtraction() {
        let child1 = "com.apple.inputmethod.Kotoeri.Japanese.Hiragana"
        XCTAssertTrue(InputSourceManager.isChildIME(child1))
        XCTAssertEqual(InputSourceManager.getParentIMEId(child1), "com.apple.inputmethod.Kotoeri.Japanese")

        let child2 = "jp.co.justsystems.inputmethod.atok34.Japanese.FullWidthRoman"
        XCTAssertTrue(InputSourceManager.isChildIME(child2))
        XCTAssertEqual(InputSourceManager.getParentIMEId(child2), "jp.co.justsystems.inputmethod.atok34.Japanese")

        let nonChild = "com.apple.keylayout.US"
        XCTAssertFalse(InputSourceManager.isChildIME(nonChild))
        XCTAssertNil(InputSourceManager.getParentIMEId(nonChild))
    }

    func testLanguageClassification() {
        XCTAssertEqual(InputSourceManager.getInputSourceLanguage("com.google.inputmethod.Japanese"), "Japanese")
        XCTAssertEqual(InputSourceManager.getInputSourceLanguage("com.apple.inputmethod.SCIM.Pinyin"), "Chinese")
        XCTAssertEqual(InputSourceManager.getInputSourceLanguage("com.apple.inputmethod.Korean"), "Korean")
        XCTAssertEqual(InputSourceManager.getInputSourceLanguage("com.apple.keylayout.French"), "European Languages")
        XCTAssertEqual(InputSourceManager.getInputSourceLanguage("com.unknown.vendor"), "English & Others")
    }
}
