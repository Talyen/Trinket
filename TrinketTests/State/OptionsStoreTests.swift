import Testing
@testable import Trinket

@MainActor
struct OptionsStoreTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func defaultsWhenNoStoredValues() {
        let store = OptionsStore(defaults: context.userDefaults)

        #if targetEnvironment(simulator)
        #expect(abs((store.musicVolume) - 0) < 0.001)
        #else
        #expect(abs((store.musicVolume) - 0.75) < 0.001)
        #endif
        #expect(abs((store.effectsVolume) - 0.85) < 0.001)
        #expect(store.hapticsEnabled)
        #expect(store.ultimateCinematicSkipPolicy == .always)
    }

    @Test func loadsPreviouslyStoredValues() {
        context.userDefaults.set(0.4, forKey: "options.musicVolume")
        context.userDefaults.set(0.6, forKey: "options.effectsVolume")
        context.userDefaults.set(false, forKey: "options.hapticsEnabled")
        context.userDefaults.set(
            UltimateCinematicSkipPolicy.never.rawValue,
            forKey: OptionsStore.ultimateCinematicSkipPolicyKey
        )

        let store = OptionsStore(defaults: context.userDefaults)

        #expect(abs((store.musicVolume) - 0.4) < 0.001)
        #expect(abs((store.effectsVolume) - 0.6) < 0.001)
        #expect(!(store.hapticsEnabled))
        #expect(store.ultimateCinematicSkipPolicy == .never)
    }

    @Test func optionValuesPersistOnChange() {
        let store = OptionsStore(defaults: context.userDefaults)
        store.musicVolume = 0.25
        store.effectsVolume = 0.5
        store.hapticsEnabled = false
        store.ultimateCinematicSkipPolicy = .never

        #expect(abs((context.userDefaults.double(forKey: "options.musicVolume")) - 0.25) < 0.001)
        #expect(abs((context.userDefaults.double(forKey: "options.effectsVolume")) - 0.5) < 0.001)
        #expect(!(context.userDefaults.bool(forKey: "options.hapticsEnabled")))
        #expect(
            context.userDefaults.string(forKey: OptionsStore.ultimateCinematicSkipPolicyKey)
                == UltimateCinematicSkipPolicy.never.rawValue
        )

        let reloaded = OptionsStore(defaults: context.userDefaults)
        #expect(abs((reloaded.musicVolume) - 0.25) < 0.001)
        #expect(abs((reloaded.effectsVolume) - 0.5) < 0.001)
        #expect(!reloaded.hapticsEnabled)
        #expect(reloaded.ultimateCinematicSkipPolicy == .never)
    }
}
