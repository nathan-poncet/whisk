import Foundation

/// User-visible strings resolve through the module's string catalog
/// (`Resources/Localizable.xcstrings`); English is the development
/// language, French ships alongside.
func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
