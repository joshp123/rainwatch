import Foundation

/// A word or phrase in the wearer's language. Every word the app and the face show goes through here, so
/// they are all in one catalogue: `Localizable.xcstrings` beside this file, English and Dutch.
public func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
