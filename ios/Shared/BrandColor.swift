import SwiftUI
import UIKit

/// The red of the Speak Away icon: one token with a light and a dark value. The app's `Theme.accent` and the
/// keyboard's mic key both read it, so it lives here, where the app and the keyboard extension can both see it.
enum BrandColor {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.96, green: 0.33, blue: 0.35, alpha: 1)
            : UIColor(red: 0.86, green: 0.23, blue: 0.25, alpha: 1)
    })
}
