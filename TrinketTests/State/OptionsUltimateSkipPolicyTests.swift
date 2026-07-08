import Foundation
import Testing
@testable import Trinket

@MainActor
struct OptionsUltimateSkipPolicyTests {
    @Test func afterFirstViewAllowsSkipOnlyOnceSeen() {
        let defaults = UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.\(UUID().uuidString)")!
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicSkipPolicy = .afterFirstView

        #expect(options.canSkipUltimateCinematic(abilityID: "bloodthorn") == false)
        options.markUltimateCinematicSeen(abilityID: "bloodthorn")
        #expect(options.canSkipUltimateCinematic(abilityID: "bloodthorn"))
        #expect(options.canSkipUltimateCinematic(abilityID: "faustian-bargain") == false)
    }

    @Test func neverPolicyBlocksSkip() {
        let defaults = UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.never.\(UUID().uuidString)")!
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicSkipPolicy = .never
        options.markUltimateCinematicSeen(abilityID: "bloodthorn")
        #expect(options.canSkipUltimateCinematic(abilityID: "bloodthorn") == false)
    }

    @Test func alwaysPolicyAllowsSkip() {
        let defaults = UserDefaults(suiteName: "OptionsUltimateSkipPolicyTests.always.\(UUID().uuidString)")!
        let options = OptionsStore(defaults: defaults)
        options.ultimateCinematicSkipPolicy = .always
        #expect(options.canSkipUltimateCinematic(abilityID: "bloodthorn"))
    }
}
