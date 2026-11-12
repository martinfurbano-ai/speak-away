import XCTest
@testable import SpeakAwayCore

final class FieldKindTests: XCTestCase {
    // UIKeyboardType raw values: default 0, asciiCapable 1, numbersAndPunctuation 2, URL 3,
    // numberPad 4, phonePad 5, namePhonePad 6, emailAddress 7, decimalPad 8, twitter 9,
    // webSearch 10, asciiCapableNumberPad 11.

    func testEmailKeyboardIsAnEmailField() {
        XCTAssertEqual(FieldKind(keyboardType: 7, contentType: nil), .email)
    }

    func testEmailContentTypeIsAnEmailFieldEvenWithTheDefaultKeyboard() {
        XCTAssertEqual(FieldKind(keyboardType: 0, contentType: "emailAddress"), .email)
    }

    func testContentTypeMatchingIgnoresCase() {
        XCTAssertEqual(FieldKind(keyboardType: 0, contentType: "EmailAddress"), .email)
        XCTAssertEqual(FieldKind(keyboardType: 0, contentType: "url"), .web)
    }

    func testWebFields() {
        XCTAssertEqual(FieldKind(keyboardType: 3, contentType: nil), .web)
        XCTAssertEqual(FieldKind(keyboardType: 10, contentType: nil), .web)
        XCTAssertEqual(FieldKind(keyboardType: 0, contentType: "URL"), .web)
    }

    func testNumericAndPhoneFields() {
        for raw in [2, 4, 8, 11] {
            XCTAssertEqual(FieldKind(keyboardType: raw, contentType: nil), .numeric, "keyboard \(raw)")
        }
        XCTAssertEqual(FieldKind(keyboardType: 5, contentType: nil), .phone)
        XCTAssertEqual(FieldKind(keyboardType: 6, contentType: nil), .phone)
        XCTAssertEqual(FieldKind(keyboardType: 0, contentType: "telephoneNumber"), .phone)
        XCTAssertEqual(FieldKind(keyboardType: 0, contentType: "oneTimeCode"), .numeric)
    }

    func testOrdinaryTextIsGeneral() {
        XCTAssertEqual(FieldKind(keyboardType: 0, contentType: nil), .general)
        XCTAssertEqual(FieldKind(keyboardType: 1, contentType: nil), .general)
        XCTAssertEqual(FieldKind(keyboardType: 9, contentType: nil), .general)
        XCTAssertEqual(FieldKind(keyboardType: 0, contentType: "name"), .general)
    }

    func testUnknownValuesFallBackToGeneral() {
        XCTAssertEqual(FieldKind(keyboardType: 99, contentType: "somethingNew"), .general)
        XCTAssertEqual(FieldKind(keyboardType: -1, contentType: ""), .general)
    }

    func testContentTypeWinsWhenItIsMoreSpecificThanTheKeyboard() {
        XCTAssertEqual(FieldKind(keyboardType: 1, contentType: "emailAddress"), .email)
        XCTAssertEqual(FieldKind(keyboardType: 7, contentType: "username"), .email)
    }

    // MARK: category

    func testOnlyEmailFieldsUseTheEmailStyle() {
        XCTAssertEqual(FieldKind.email.category, .email)
        for kind in [FieldKind.web, .numeric, .phone, .general] {
            XCTAssertEqual(kind.category, .messages, "\(kind)")
        }
    }

    func testCategoryShortcut() {
        XCTAssertEqual(FieldKind.category(keyboardType: 7, contentType: nil), .email)
        XCTAssertEqual(FieldKind.category(keyboardType: 0, contentType: nil), .messages)
    }

    func testStyleSettingsPicksTheStyleForAField() {
        let settings = StyleSettings().setting(.veryCasual, for: .messages)
        XCTAssertEqual(settings.style(for: FieldKind.category(keyboardType: 0, contentType: nil)), .veryCasual)
        XCTAssertEqual(settings.style(for: FieldKind.category(keyboardType: 7, contentType: nil)), .formal)
    }
}
