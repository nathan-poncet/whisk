/// How this build reaches the user, decided at compile time. The
/// Developer ID build from GitHub and Homebrew looks after its own
/// updates; the App Store build leaves that to the store, whose rules
/// forbid an updater of its own.
enum Distribution: Equatable {
    case developerID
    case appStore

    /// Whether the app may look for a newer version and point to it.
    var checksForUpdates: Bool {
        switch self {
        case .developerID: true
        case .appStore: false
        }
    }

    static var current: Distribution {
        #if APP_STORE
            .appStore
        #else
            .developerID
        #endif
    }
}
