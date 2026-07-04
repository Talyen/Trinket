import TrinketDesignSystem
import XCTest
@testable import Trinket

final class OptionsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "OptionsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsWhenNoStoredValues() {
        let store = OptionsStore(defaults: defaults)

        #if targetEnvironment(simulator)
        XCTAssertEqual(store.musicVolume, 0, accuracy: 0.001)
        #else
        XCTAssertEqual(store.musicVolume, 0.75, accuracy: 0.001)
        #endif
        XCTAssertEqual(store.effectsVolume, 0.85, accuracy: 0.001)
        XCTAssertTrue(store.hapticsEnabled)
        XCTAssertEqual(store.theme, .dark)
    }

    func testLoadsPreviouslyStoredValues() {
        defaults.set(0.4, forKey: "options.musicVolume")
        defaults.set(0.6, forKey: "options.effectsVolume")
        defaults.set(false, forKey: "options.hapticsEnabled")
        defaults.set(TrinketDesign.AppTheme.light.rawValue, forKey: "options.theme")

        let store = OptionsStore(defaults: defaults)

        XCTAssertEqual(store.musicVolume, 0.4, accuracy: 0.001)
        XCTAssertEqual(store.effectsVolume, 0.6, accuracy: 0.001)
        XCTAssertFalse(store.hapticsEnabled)
        XCTAssertEqual(store.theme, .light)
    }

    func testMusicVolumePersistsOnChange() {
        let store = OptionsStore(defaults: defaults)
        store.musicVolume = 0.25

        XCTAssertEqual(defaults.double(forKey: "options.musicVolume"), 0.25, accuracy: 0.001)
        XCTAssertEqual(OptionsStore(defaults: defaults).musicVolume, 0.25, accuracy: 0.001)
    }

    func testEffectsVolumePersistsOnChange() {
        let store = OptionsStore(defaults: defaults)
        store.effectsVolume = 0.5

        XCTAssertEqual(defaults.double(forKey: "options.effectsVolume"), 0.5, accuracy: 0.001)
        XCTAssertEqual(OptionsStore(defaults: defaults).effectsVolume, 0.5, accuracy: 0.001)
    }

    func testHapticsEnabledPersistsOnChange() {
        let store = OptionsStore(defaults: defaults)
        store.hapticsEnabled = false

        XCTAssertFalse(defaults.bool(forKey: "options.hapticsEnabled"))
        XCTAssertFalse(OptionsStore(defaults: defaults).hapticsEnabled)
    }

    func testThemePersistsOnChange() {
        let store = OptionsStore(defaults: defaults)
        store.theme = .system

        XCTAssertEqual(defaults.string(forKey: "options.theme"), TrinketDesign.AppTheme.system.rawValue)
        XCTAssertEqual(OptionsStore(defaults: defaults).theme, .system)
    }
}
