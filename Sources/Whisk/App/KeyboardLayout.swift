import Carbon

/// Resolves the virtual key code that produces a given character under the
/// keyboard layout currently active, by translating every virtual key code
/// through the layout. Shortcuts then follow the printed character (Dvorak,
/// AZERTY, Colemak, …) instead of the physical ANSI position.
enum KeyboardLayout {
    static func keyCode(for character: Character) -> CGKeyCode? {
        let wanted = Character(String(character).lowercased())
        return characterMap()[wanted]
    }

    private static func characterMap() -> [Character: CGKeyCode] {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return [:] }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data

        var map: [Character: CGKeyCode] = [:]
        layoutData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let base = buffer.baseAddress else { return }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            for code: UInt16 in 0..<128 {
                guard let character = character(for: code, in: layout) else { continue }
                // Ascending key codes keep the primary key (letter row over
                // keypad) when two keys print the same character.
                if map[character] == nil {
                    map[character] = CGKeyCode(code)
                }
            }
        }
        return map
    }

    private static func character(for code: UInt16, in layout: UnsafePointer<UCKeyboardLayout>) -> Character? {
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            layout,
            code,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length).lowercased().first
    }
}
