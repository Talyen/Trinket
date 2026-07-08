import Testing
import TrinketDesignSystem
@testable import Trinket

@Suite @MainActor
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
        #expect(store.appearance == .system)
    }

    @Test func loadsPreviouslyStoredValues() {
        context.userDefaults.set(0.4, forKey: "options.musicVolume")
        context.userDefaults.set(0.6, forKey: "options.effectsVolume")
        context.userDefaults.set(false, forKey: "options.hapticsEnabled")
        context.userDefaults.set(TrinketDesign.AppAppearance.dark.rawValue, forKey: "options.appearance")

        let store = OptionsStore(defaults: context.userDefaults)

        #expect(abs((store.musicVolume) - 0.4) < 0.001)
        #expect(abs((store.effectsVolume) - 0.6) < 0.001)
        #expect(!(store.hapticsEnabled))
        #expect(store.appearance == .dark)
    }

    @Test func musicVolumePersistsOnChange() {
        let store = OptionsStore(defaults: context.userDefaults)
        store.musicVolume = 0.25

        #expect(abs((context.userDefaults.double(forKey: "options.musicVolume")) - 0.25) < 0.001)
        #expect(abs((OptionsStore(defaults: context.userDefaults).musicVolume) - 0.25) < 0.001)
    }

    @Test func effectsVolumePersistsOnChange() {
        let store = OptionsStore(defaults: context.userDefaults)
        store.effectsVolume = 0.5

        #expect(abs((context.userDefaults.double(forKey: "options.effectsVolume")) - 0.5) < 0.001)
        #expect(abs((OptionsStore(defaults: context.userDefaults).effectsVolume) - 0.5) < 0.001)
    }

    @Test func hapticsEnabledPersistsOnChange() {
        let store = OptionsStore(defaults: context.userDefaults)
        store.hapticsEnabled = false

        #expect(!(context.userDefaults.bool(forKey: "options.hapticsEnabled")))
        #expect(!OptionsStore(defaults: context.userDefaults).hapticsEnabled)
    }

    @Test func appearancePersistsOnChange() {
        let store = OptionsStore(defaults: context.userDefaults)
        store.appearance = .dark

        #expect(context.userDefaults.string(forKey: "options.appearance") == TrinketDesign.AppAppearance.dark.rawValue)
        #expect(OptionsStore(defaults: context.userDefaults).appearance == .dark)
    }
}
