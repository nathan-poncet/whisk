import Testing

@testable import Whisk

@Suite struct DistributionRules {
    @Test func only_the_developer_id_build_checks_for_updates() {
        #expect(Distribution.developerID.checksForUpdates)
        #expect(!Distribution.appStore.checksForUpdates)
    }

    @Test func the_test_build_is_the_developer_id_one() {
        #expect(Distribution.current == .developerID)
    }
}
