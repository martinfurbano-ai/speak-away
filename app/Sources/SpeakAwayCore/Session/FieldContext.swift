import Foundation

/// What the keyboard tells the app about the field it types into. It travels with every request.
public struct FieldContext: Codable, Equatable, Sendable {
    public let kind: FieldKind
    /// The style picked with the keyboard's chip for this field. `nil`: the style of the field's category.
    public let styleOverride: WritingStyle?

    public static let general = FieldContext()

    public init(kind: FieldKind = .general, styleOverride: WritingStyle? = nil) {
        self.kind = kind
        self.styleOverride = styleOverride
    }

    /// From the traits of a text field: `UIKeyboardType.rawValue` and `UITextContentType.rawValue`.
    public init(keyboardType: Int, contentType: String?, styleOverride: WritingStyle? = nil) {
        self.init(kind: FieldKind(keyboardType: keyboardType, contentType: contentType), styleOverride: styleOverride)
    }

    public var category: AppCategory { kind.category }

    /// The style to write in: the override when there is one, else what the user set for this kind of field.
    public func style(in settings: StyleSettings) -> WritingStyle {
        styleOverride ?? settings.style(for: category)
    }

    /// A new context with the override changed.
    public func withStyleOverride(_ style: WritingStyle?) -> FieldContext {
        FieldContext(kind: kind, styleOverride: style)
    }
}

/// The keyboard's style chip: tap to move through the styles, then back to automatic.
public enum StyleOverride {
    public static func next(after current: WritingStyle?) -> WritingStyle? {
        switch current {
        case nil: return .formal
        case .formal?: return .casual
        case .casual?: return .veryCasual
        case .veryCasual?: return nil
        }
    }

    public static func title(_ style: WritingStyle) -> String {
        switch style {
        case .formal: return "Formal"
        case .casual: return "Casual"
        case .veryCasual: return "Very casual"
        }
    }

    /// "Auto: Casual" while the style follows the field, "Casual" once the user picked it.
    public static func chipText(override: WritingStyle?, effective: WritingStyle) -> String {
        override == nil ? "Auto: \(title(effective))" : title(effective)
    }
}
