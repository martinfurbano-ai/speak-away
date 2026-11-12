import Foundation

/// What kind of text field the keyboard is typing into, from the field's traits.
/// It takes raw values (`UIKeyboardType.rawValue`, `UITextContentType.rawValue`) so this file
/// stays Foundation only and can be tested on the Mac.
public enum FieldKind: Equatable, Sendable {
    case email
    case web
    case numeric
    case phone
    case general

    public init(keyboardType: Int, contentType: String?) {
        // The content type says more than the keyboard when both are set.
        if let kind = FieldKind.kind(forContentType: contentType) {
            self = kind
        } else {
            self = FieldKind.kind(forKeyboardType: keyboardType)
        }
    }

    /// The writing-style category: email fields use the email style, everything else is a message.
    public var category: AppCategory {
        self == .email ? .email : .messages
    }

    public static func category(keyboardType: Int, contentType: String?) -> AppCategory {
        FieldKind(keyboardType: keyboardType, contentType: contentType).category
    }

    // UIKeyboardType raw values.
    private static func kind(forKeyboardType raw: Int) -> FieldKind {
        switch raw {
        case 7: return .email                      // emailAddress
        case 3, 10: return .web                    // URL, webSearch
        case 2, 4, 8, 11: return .numeric          // numbersAndPunctuation, numberPad, decimalPad, asciiCapableNumberPad
        case 5, 6: return .phone                   // phonePad, namePhonePad
        default: return .general
        }
    }

    // UITextContentType raw values, compared without case.
    private static func kind(forContentType raw: String?) -> FieldKind? {
        switch (raw ?? "").lowercased() {
        case "emailaddress": return .email
        case "url": return .web
        case "telephonenumber": return .phone
        case "onetimecode", "creditcardnumber", "postalcode": return .numeric
        default: return nil
        }
    }
}
