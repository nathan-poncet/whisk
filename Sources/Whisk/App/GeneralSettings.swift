import Combine
import Foundation
import ServiceManagement

/// The retention choices offered in Settings, mapped to the kernel's
/// time-based policy.
enum RetentionPeriodOption: String, CaseIterable, Identifiable {
    case forever
    case day
    case week
    case month

    var id: String { rawValue }

    var label: String {
        switch self {
        case .forever: localized("Forever")
        case .day: localized("24 hours")
        case .week: localized("7 days")
        case .month: localized("30 days")
        }
    }

    var maxAge: TimeInterval? {
        switch self {
        case .forever: nil
        case .day: 86_400
        case .week: 604_800
        case .month: 2_592_000
        }
    }
}

/// The three card sizes offered in Settings; the panel's height and the
/// rail's stride follow the side.
enum CardSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: localized("Small")
        case .medium: localized("Medium")
        case .large: localized("Large")
        }
    }

    /// The card's side in points, before the selection zoom.
    var side: CGFloat {
        switch self {
        case .small: 160
        case .medium: 200
        case .large: 250
        }
    }
}

/// An application whose copies are never recorded.
struct ExcludedApp: Codable, Equatable, Identifiable {
    let bundleID: String
    let name: String

    var id: String { bundleID }
}

/// History housekeeping settings, persisted and translated into the
/// kernel's RetentionPolicy.
final class GeneralSettingsStore: ObservableObject {
    /// 0 stands for unlimited.
    static let capacityChoices = [100, 250, 500, 1000, 0]

    static func capacityLabel(_ choice: Int) -> String {
        choice == 0 ? localized("Unlimited") : localized("\(choice) items")
    }

    @Published var retentionPeriod: RetentionPeriodOption {
        didSet { defaults.set(retentionPeriod.rawValue, forKey: "retentionPeriod") }
    }

    @Published var capacity: Int {
        didSet { defaults.set(capacity, forKey: "historyCapacity") }
    }

    @Published var checkForUpdates: Bool {
        didSet { defaults.set(checkForUpdates, forKey: "checkForUpdates") }
    }

    @Published var vimNavigation: Bool {
        didSet { defaults.set(vimNavigation, forKey: "vimNavigation") }
    }

    /// Whether copied links are looked up for their title and image — the
    /// one request that tells a site its address was copied.
    @Published var linkPreviews: Bool {
        didSet { defaults.set(linkPreviews, forKey: "linkPreviews") }
    }

    @Published var cardSize: CardSize {
        didSet { defaults.set(cardSize.rawValue, forKey: "cardSize") }
    }

    @Published var excludedApps: [ExcludedApp] {
        didSet {
            do {
                defaults.set(try JSONEncoder().encode(excludedApps), forKey: "excludedApps")
            } catch {
                logger.log("excluded apps not saved — \(error)")
            }
        }
    }

    private let defaults: UserDefaults
    private let logger: any Logger

    init(defaults: UserDefaults = .standard, logger: any Logger = ConsoleLogger()) {
        self.defaults = defaults
        self.logger = logger
        retentionPeriod = RetentionPeriodOption(rawValue: defaults.string(forKey: "retentionPeriod") ?? "") ?? .forever
        capacity =
            defaults.object(forKey: "historyCapacity") == nil ? 500 : defaults.integer(forKey: "historyCapacity")
        checkForUpdates =
            defaults.object(forKey: "checkForUpdates") == nil ? true : defaults.bool(forKey: "checkForUpdates")
        vimNavigation = defaults.bool(forKey: "vimNavigation")
        linkPreviews = defaults.object(forKey: "linkPreviews") == nil ? true : defaults.bool(forKey: "linkPreviews")
        cardSize = CardSize(rawValue: defaults.string(forKey: "cardSize") ?? "") ?? .medium
        excludedApps = []
        if let data = defaults.data(forKey: "excludedApps") {
            do {
                excludedApps = try JSONDecoder().decode([ExcludedApp].self, from: data)
            } catch {
                logger.log("stored excluded apps unreadable — \(error); none apply")
            }
        }
    }

    var excludedBundleIDs: Set<String> {
        Set(excludedApps.map(\.bundleID))
    }

    var policy: RetentionPolicy {
        RetentionPolicy(
            capacity: capacity == 0 ? .unlimited : (HistoryCapacity(capacity) ?? .standard),
            maxAge: retentionPeriod.maxAge
        )
    }
}

/// Registers the app as a login item. Only works from the installed
/// bundle — the bare debug binary reports the failure instead of crashing.
final class LoginItemManager: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var lastError: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = String(
                format: localized("Launch at login needs the installed Whisk.app: %@"), error.localizedDescription)
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
