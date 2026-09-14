import Foundation

/// User-visible strings resolve through the module's catalogs —
/// `Resources/*.lproj/Localizable.strings`, plural forms in the
/// `.stringsdict` next to it; English is the development language, French
/// ships alongside.
func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
