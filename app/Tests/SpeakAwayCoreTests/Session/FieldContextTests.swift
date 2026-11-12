import XCTest
@testable import SpeakAwayCore

final class FieldContextTests: XCTestCase {
    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: encoder.encode(value))
    }

    // MARK: Building a context from a field

    func testEmailKeyboardMakesAnEmailContext() {
        let field = FieldContext(keyboardType: 7, contentType: nil)
        XCTAssertEqual(field.kind, .email)
        XCTAssertEqual(field.category, .email)
        XCTAssertNil(field.styleOverride)
    }

    func testContentTypeWinsOverTheKeyboardType() {
        XCTAssertEqual(FieldContext(keyboardType: 0, contentType: "emailAddress").kind, .email)
        XCTAssertEqual(FieldContext(keyboardType: 7, contentType: "URL").kind, .web)
    }

    func testPlainFieldIsGeneralAndCountsAsAMessage() {
        let field = FieldContext(keyboardType: 0, contentType: nil)
        XCTAssertEqual(field, .general)
        XCTAssertEqual(field.category, .messages)
    }

    // MARK: Which style applies

    func testWithoutAnOverrideTheCategoryStyleApplies() {
        XCTAssertEqual(FieldContext(kind: .email).style(in: StyleSettings()), .formal)
        XCTAssertEqual(FieldContext(kind: .general).style(in: StyleSettings()), .casual)
    }

    func testTheOverrideBeatsTheCategoryStyle() {
        let field = FieldContext(kind: .email, styleOverride: .veryCasual)
        XCTAssertEqual(field.style(in: StyleSettings()), .veryCasual)
    }

    func testTheOverrideBeatsTheUsersOwnStyleSettings() {
        let settings = StyleSettings().setting(.formal, for: .messages)
        XCTAssertEqual(FieldContext(kind: .general).style(in: settings), .formal)
        XCTAssertEqual(FieldContext(kind: .general, styleOverride: .casual).style(in: settings), .casual)
    }

    func testChangingTheOverrideReturnsANewContext() {
        let original = FieldContext(kind: .web)
        let changed = original.withStyleOverride(.formal)
        XCTAssertNil(original.styleOverride)
        XCTAssertEqual(changed.styleOverride, .formal)
        XCTAssertEqual(changed.kind, .web)
    }

    // MARK: Coding

    func testContextSurvivesARoundTrip() throws {
        for field in [FieldContext.general, FieldContext(kind: .email, styleOverride: .veryCasual), FieldContext(kind: .phone)] {
            XCTAssertEqual(try roundTrip(field), field)
        }
    }

    func testKindIsStoredAsAReadableWord() throws {
        let data = try JSONEncoder().encode(FieldContext(kind: .email, styleOverride: .formal))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["kind"] as? String, "email")
        XCTAssertEqual(object["styleOverride"] as? String, "formal")
    }

    // MARK: The request a keyboard builds

    func testRequestBuiltFromTheFieldCarriesTheContext() throws {
        let id = UUID()
        let sent = Date(timeIntervalSince1970: 1_800_000_000)
        let request = SessionRequest.make(.start, keyboardType: 7, contentType: nil, styleOverride: .casual, id: id, sentAt: sent)
        XCTAssertEqual(request.id, id)
        XCTAssertEqual(request.sentAt, sent)
        XCTAssertEqual(request.message, .start)
        XCTAssertEqual(request.field, FieldContext(kind: .email, styleOverride: .casual))
        XCTAssertEqual(try roundTrip(request), request)
    }

    func testRequestWithoutAFieldKeyDecodesAsGeneral() throws {
        let json = #"{"id":"2F4C7D4E-0000-4000-8000-000000000001","sentAt":"2027-01-15T08:00:00Z","message":{"type":"stop"}}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let request = try decoder.decode(SessionRequest.self, from: Data(json.utf8))
        XCTAssertEqual(request.message, .stop)
        XCTAssertEqual(request.field, .general)
    }

    func testDefaultRequestStillUsesAGeneralField() {
        XCTAssertEqual(SessionRequest(message: .start).field, .general)
    }

    func testStartCommandMessageKeepsTheTargetText() throws {
        let message = SessionMessage.startCommand(on: "hey, send me the file")
        XCTAssertEqual(try roundTrip(message), message)
        let data = try JSONEncoder().encode(message)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "startCommand")
        XCTAssertEqual(object["text"] as? String, "hey, send me the file")
    }
}
