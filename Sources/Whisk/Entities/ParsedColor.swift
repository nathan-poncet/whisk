import Foundation

/// A color a payload spells out, normalized to sRGB components in 0...1.
struct ParsedColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

extension ParsedColor {
    /// Recognizes the common ways text encodes a color: hex — #RGB, #RGBA,
    /// #RRGGBB, #RRGGBBAA, the hash optional on the 6- and 8-digit forms —
    /// and the CSS functions rgb()/rgba(), hsl()/hsla() and hsv()/hsb(),
    /// with comma or modern space/slash syntax, percentages, and degree
    /// suffixes. Values clamp the way CSS clamps.
    static func parse(_ text: String) -> ParsedColor? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return parseHex(trimmed) ?? parseFunction(trimmed)
    }

    // MARK: Hex

    private static func parseHex(_ text: String) -> ParsedColor? {
        let hadHash = text.hasPrefix("#")
        let digits = hadHash ? String(text.dropFirst()) : text
        guard !digits.isEmpty, digits.allSatisfy(\.isHexDigit) else { return nil }
        switch digits.count {
        // Bare 3- and 4-digit strings ("abc", "beef") are everyday words —
        // the short forms demand the hash.
        case 3 where hadHash, 4 where hadHash:
            let channels = digits.compactMap { UInt8(String($0), radix: 16) }
            guard channels.count == digits.count else { return nil }
            let unit = channels.map { Double($0) / 15 }
            return ParsedColor(red: unit[0], green: unit[1], blue: unit[2], alpha: unit.count == 4 ? unit[3] : 1)
        case 6, 8:
            var channels: [Double] = []
            var index = digits.startIndex
            while index < digits.endIndex {
                let next = digits.index(index, offsetBy: 2)
                guard let value = UInt8(digits[index..<next], radix: 16) else { return nil }
                channels.append(Double(value) / 255)
                index = next
            }
            return ParsedColor(
                red: channels[0], green: channels[1], blue: channels[2],
                alpha: channels.count == 4 ? channels[3] : 1
            )
        default:
            return nil
        }
    }

    // MARK: CSS functions

    private static func parseFunction(_ text: String) -> ParsedColor? {
        let lowered = text.lowercased()
        guard let open = lowered.firstIndex(of: "("), lowered.hasSuffix(")") else { return nil }
        let name = String(lowered[..<open]).trimmingCharacters(in: .whitespaces)
        let inside = lowered[lowered.index(after: open)..<lowered.index(before: lowered.endIndex)]
        let tokens =
            inside
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .split(separator: " ")
            .map(String.init)
        guard tokens.count == 3 || tokens.count == 4 else { return nil }
        guard let alpha = tokens.count == 4 ? fraction(tokens[3]) : 1 else { return nil }
        switch name {
        case "rgb", "rgba":
            guard let red = channel(tokens[0]),
                let green = channel(tokens[1]),
                let blue = channel(tokens[2])
            else { return nil }
            return ParsedColor(red: red, green: green, blue: blue, alpha: alpha)
        case "hsl", "hsla":
            guard let hue = hue(tokens[0]),
                let saturation = percentage(tokens[1]),
                let lightness = percentage(tokens[2])
            else { return nil }
            return fromHSL(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
        case "hsv", "hsb":
            guard let hue = hue(tokens[0]),
                let saturation = percentage(tokens[1]),
                let value = percentage(tokens[2])
            else { return nil }
            return fromHSV(hue: hue, saturation: saturation, value: value, alpha: alpha)
        default:
            return nil
        }
    }

    /// An rgb() channel: 0...255, or a percentage.
    private static func channel(_ token: String) -> Double? {
        if token.hasSuffix("%") {
            guard let value = Double(token.dropLast()) else { return nil }
            return clamped(value / 100)
        }
        guard let value = Double(token) else { return nil }
        return clamped(value / 255)
    }

    /// An alpha: 0...1, or a percentage.
    private static func fraction(_ token: String) -> Double? {
        if token.hasSuffix("%") {
            guard let value = Double(token.dropLast()) else { return nil }
            return clamped(value / 100)
        }
        guard let value = Double(token) else { return nil }
        return clamped(value)
    }

    /// A saturation/lightness/value: percentage, the % sign optional.
    private static func percentage(_ token: String) -> Double? {
        let raw = token.hasSuffix("%") ? String(token.dropLast()) : token
        guard let value = Double(raw) else { return nil }
        return clamped(value / 100)
    }

    /// A hue in degrees, the "deg" suffix optional, wrapped into 0..<360.
    private static func hue(_ token: String) -> Double? {
        let raw = token.hasSuffix("deg") ? String(token.dropLast(3)) : token
        guard let value = Double(raw) else { return nil }
        let wrapped = value.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func fromHSL(
        hue: Double, saturation: Double, lightness: Double, alpha: Double
    ) -> ParsedColor {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let match = lightness - chroma / 2
        return fromHueChroma(hue: hue, chroma: chroma, match: match, alpha: alpha)
    }

    private static func fromHSV(
        hue: Double, saturation: Double, value: Double, alpha: Double
    ) -> ParsedColor {
        let chroma = value * saturation
        let match = value - chroma
        return fromHueChroma(hue: hue, chroma: chroma, match: match, alpha: alpha)
    }

    private static func fromHueChroma(
        hue: Double, chroma: Double, match: Double, alpha: Double
    ) -> ParsedColor {
        let sector = hue / 60
        let secondary = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let (red, green, blue): (Double, Double, Double) =
            switch Int(sector) {
            case 0: (chroma, secondary, 0)
            case 1: (secondary, chroma, 0)
            case 2: (0, chroma, secondary)
            case 3: (0, secondary, chroma)
            case 4: (secondary, 0, chroma)
            default: (chroma, 0, secondary)
            }
        return ParsedColor(red: red + match, green: green + match, blue: blue + match, alpha: alpha)
    }
}
