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
        case .forever: "Forever"
        case .day: "24 hours"
        case .week: "7 days"
        case .month: "30 days"
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

/// History housekeeping settings, persisted and translated into the
/// kernel's RetentionPolicy.
final class GeneralSettingsStore: ObservableObject {
    static let capacityChoices = [100, 250, 500, 1000]

    @Published var retentionPeriod: RetentionPeriodOption {
        didSet { defaults.set(retentionPeriod.rawValue, forKey: "retentionPeriod") }
    }

    @Published var capacity: Int {
        didSet { defaults.set(capacity, forKey: "historyCapacity") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        retentionPeriod = RetentionPeriodOption(rawValue: defaults.string(forKey: "retentionPeriod") ?? "") ?? .forever
        let stored = defaults.integer(forKey: "historyCapacity")
        capacity = stored > 0 ? stored : 500
    }

    var policy: RetentionPolicy {
        RetentionPolicy(
            capacity: HistoryCapacity(capacity) ?? .standard,
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
            lastError = "Launch at login needs the installed Whisk.app: \(error.localizedDescription)"
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
