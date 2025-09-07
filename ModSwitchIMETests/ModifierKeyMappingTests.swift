import XCTest
import CoreGraphics
@testable import ModSwitchIME

final class ModifierKeyMappingTests: XCTestCase {
    func testModifierKeyFromKeyCode() {
        XCTAssertEqual(ModifierKey.from(keyCode: ModifierKey.leftCommand.keyCode), .leftCommand)
        XCTAssertEqual(ModifierKey.from(keyCode: ModifierKey.rightCommand.keyCode), .rightCommand)
        XCTAssertEqual(ModifierKey.from(keyCode: ModifierKey.leftOption.keyCode), .leftOption)
        XCTAssertEqual(ModifierKey.from(keyCode: ModifierKey.rightOption.keyCode), .rightOption)
    }

    func testFlagMasksAreGroupedCorrectly() {
        // Left/Right variants share same mask per modifier
        XCTAssertEqual(ModifierKey.leftCommand.flagMask, ModifierKey.rightCommand.flagMask)
        XCTAssertEqual(ModifierKey.leftShift.flagMask, ModifierKey.rightShift.flagMask)
        XCTAssertEqual(ModifierKey.leftOption.flagMask, ModifierKey.rightOption.flagMask)
        XCTAssertEqual(ModifierKey.leftControl.flagMask, ModifierKey.rightControl.flagMask)
    }
}
