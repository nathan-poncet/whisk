import AppKit

/// Bundled icons for category chips. The Neovim mark (the code chip) ships
/// in the app resources — logo by Jason Long, CC BY 3.0.
enum CategoryIcons {
    static let neovim: NSImage? = Bundle.module.image(forResource: "nvim")
}
