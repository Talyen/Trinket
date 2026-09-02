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

    @Test func `clearDefaults removes all options keys`() {
        let defaults = context.userDefaults
        defaults.set(0.25, forKey: OptionsStore.musicVolumeKey)
        defaults.set(0.5, forKey: OptionsStore.effectsVolumeKey)
        defaults.set(false, forKey: OptionsStore.hapticsEnabledKey)
        defaults.set(true, forKey: OptionsStore.rememberAutoBattlePreferenceKey)
        defaults.set(true, forKey: OptionsStore.autoBattleEnabledKey)
        defaults.set(UltimateCinematicShowPolicy.never.rawValue, forKey: OptionsStore.ultimateCinematicShowPolicyKey)

        OptionsStore.clearDefaults(from: defaults)

        #expect(defaults.object(forKey: OptionsStore.musicVolumeKey) == nil)
        #expect(defaults.object(forKey: OptionsStore.effectsVolumeKey) == nil)
        #expect(defaults.object(forKey: OptionsStore.hapticsEnabledKey) == nil)
        #expect(defaults.object(forKey: OptionsStore.rememberAutoBattlePreferenceKey) == nil)
        #expect(defaults.object(forKey: OptionsStore.autoBattleEnabledKey) == nil)
        #expect(defaults.object(forKey: OptionsStore.ultimateCinematicShowPolicyKey) == nil)
    }
}
