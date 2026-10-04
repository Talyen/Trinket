import Foundation
import Testing
import TrinketPersistenceTestSupport
@testable import TrinketAppState

@MainActor
struct OptionsStoreTests {
    private let context: OptionsDefaults

    init() throws {
        context = try OptionsDefaults()
    }

    @Test func `saved ultimate show policy replaces the default on reload`() {
        let options = OptionsStore(defaults: context.userDefaults)
        #expect(options.ultimateCinematicShowPolicy == .oncePerBattle)
        options.ultimateCinematicShowPolicy = .always

        #expect(OptionsStore(defaults: context.userDefaults).ultimateCinematicShowPolicy == .always)
    }

    @Test func `once per battle auto skips only actors who already presented`() {
        let options = OptionsStore(defaults: context.userDefaults)
        options.ultimateCinematicShowPolicy = .oncePerBattle

        #expect(!options.shouldAutoSkipUltimateCinematic(actorID: "hero", actorsWhoPresentedThisBattle: []))
        #expect(options.shouldAutoSkipUltimateCinematic(actorID: "hero", actorsWhoPresentedThisBattle: ["hero"]))
        #expect(!options.shouldAutoSkipUltimateCinematic(actorID: "companion", actorsWhoPresentedThisBattle: ["hero"]))
    }

    @Test(arguments: [
        (UltimateCinematicShowPolicy.always, false),
        (.never, true),
    ])
    func `always and never policies control auto skip`(
        policy: UltimateCinematicShowPolicy,
        autoSkips: Bool,
    ) {
        let options = OptionsStore(defaults: context.userDefaults)
        options.ultimateCinematicShowPolicy = policy
        #expect(options.shouldAutoSkipUltimateCinematic(actorID: "hero", actorsWhoPresentedThisBattle: []) == autoSkips)
        #expect(options.shouldAutoSkipUltimateCinematic(actorID: "hero", actorsWhoPresentedThisBattle: ["hero"]) == autoSkips)
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

    @Test func `invalid saved volumes are repaired and stay repaired on relaunch`() {
        let defaults = context.userDefaults
        let fresh = OptionsStore(defaults: defaults)
        let defaultMusicVolume = fresh.musicVolume
        let defaultEffectsVolume = fresh.effectsVolume
        defaults.set(Double.nan, forKey: OptionsStore.musicVolumeKey)
        defaults.set(Double.infinity, forKey: OptionsStore.effectsVolumeKey)

        let repaired = OptionsStore(defaults: defaults)

        #expect(repaired.musicVolume == defaultMusicVolume)
        #expect(repaired.effectsVolume == defaultEffectsVolume)
        #expect(defaults.double(forKey: OptionsStore.musicVolumeKey) == defaultMusicVolume)
        #expect(defaults.double(forKey: OptionsStore.effectsVolumeKey) == defaultEffectsVolume)
        let relaunched = OptionsStore(defaults: defaults)
        #expect(relaunched.musicVolume == defaultMusicVolume)
        #expect(relaunched.effectsVolume == defaultEffectsVolume)
    }

    @Test func `out of range saved volumes are clamped`() {
        let defaults = context.userDefaults
        defaults.set(-0.5, forKey: OptionsStore.musicVolumeKey)
        defaults.set(2.0, forKey: OptionsStore.effectsVolumeKey)

        let store = OptionsStore(defaults: defaults)

        #expect(store.musicVolume == 0)
        #expect(store.effectsVolume == 1)
        #expect(defaults.double(forKey: OptionsStore.musicVolumeKey) == 0)
        #expect(defaults.double(forKey: OptionsStore.effectsVolumeKey) == 1)
    }

    @Test func `assigned volumes are normalized while valid values round trip`() {
        let defaults = context.userDefaults
        let store = OptionsStore(defaults: defaults)
        let defaultMusicVolume = store.musicVolume
        let defaultEffectsVolume = store.effectsVolume
        store.musicVolume = 0.35
        store.effectsVolume = 0.65
        #expect(OptionsStore(defaults: defaults).musicVolume == 0.35)
        #expect(OptionsStore(defaults: defaults).effectsVolume == 0.65)

        store.musicVolume = Double.nan
        store.effectsVolume = Double.infinity
        #expect(store.musicVolume == defaultMusicVolume)
        #expect(store.effectsVolume == defaultEffectsVolume)
        store.musicVolume = 2
        store.effectsVolume = -1
        #expect(store.musicVolume == 1)
        #expect(store.effectsVolume == 0)
        #expect(defaults.double(forKey: OptionsStore.musicVolumeKey) == 1)
        #expect(defaults.double(forKey: OptionsStore.effectsVolumeKey) == 0)
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

private final class OptionsDefaults {
    let suiteName = "OptionsStoreTests.\(UUID().uuidString)"
    let userDefaults: UserDefaults

    init() throws {
        userDefaults = try SaveTestSupport.makeUserDefaults(suiteName: suiteName)
    }

    deinit {
        SaveTestSupport.removeUserDefaults(suiteName: suiteName, defaults: userDefaults)
    }
}
