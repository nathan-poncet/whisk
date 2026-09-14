extension TextTransform {
    /// The menu entry for the transform.
    var label: String {
        switch self {
        case .uppercase: localized("Uppercase")
        case .lowercase: localized("Lowercase")
        case .trimmed: localized("Trimmed")
        case .singleLine: localized("Single line")
        case .withoutAccents: localized("Without accents")
        case .urlEncoded: localized("URL-encoded")
        case .urlDecoded: localized("URL-decoded")
        case .base64Encoded: localized("Base64-encoded")
        case .base64Decoded: localized("Base64-decoded")
        case .prettyJSON: localized("Formatted JSON")
        }
    }
}
