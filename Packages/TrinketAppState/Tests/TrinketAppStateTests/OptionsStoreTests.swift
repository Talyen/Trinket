import Testing
import TrinketBattleFeature
import TrinketFeatureSupport
@testable import TrinketAppState

@MainActor
struct OptionsStoreTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func `clears stale auto battle when remember is off on load`() {
        context.userDefaults.set(true, forKey: OptionsStore.autoBattleEnabledKey)

        let store = OptionsStore(defaults: context.userDefaults)

        #expect(!store.rememberAutoBattlePreference)
        #expect(!store.autoBattleEnabled)
        #expect(!context.userDefaults.bool(forKey: OptionsStore.autoBattleEnabledKey))
    }

    @Test func `turning remember off clears auto battle`() {
        let store = OptionsStore(defaults: context.userDefaults)
        store.rememberAutoBattlePreference = true
        store.autoBattleEnabled = true

        store.rememberAutoBattlePreference = false

        #expect(!store.autoBattleEnabled)
        #expect(!context.userDefaults.bool(forKey: OptionsStore.autoBattleEnabledKey))
    }
}
