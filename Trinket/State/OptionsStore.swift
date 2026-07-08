import SwiftUI
import TrinketDesignSystem

/// Local player preferences. Keys are `@AppStorage`-compatible and stay device-local
/// (not part of `PlayerSave` / CloudKit).
@MainActor
@Observable
final class OptionsStore {
    @ObservationIgnored private var musicVolumeStorage: AppStorage<Double>
    @ObservationIgnored private var effectsVolumeStorage: AppStorage<Double>
    @ObservationIgnored private var hapticsEnabledStorage: AppStorage<Bool>
    @ObservationIgnored private var appearanceStorage: AppStorage<String>

    var musicVolume: Double {
        didSet { musicVolumeStorage.wrappedValue = musicVolume }
    }

    var effectsVolume: Double {
        didSet { effectsVolumeStorage.wrappedValue = effectsVolume }
    }

    var hapticsEnabled: Bool {
        didSet { hapticsEnabledStorage.wrappedValue = hapticsEnabled }
    }

    var appearance: TrinketDesign.AppAppearance {
        didSet { appearanceStorage.wrappedValue = appearance.rawValue }
    }

    static let musicVolumeKey = "options.musicVolume"
    static let effectsVolumeKey = "options.effectsVolume"
    static let hapticsEnabledKey = "options.hapticsEnabled"
    static let appearanceKey = "options.appearance"

    init(defaults: UserDefaults = .standard) {
        musicVolumeStorage = AppStorage(
            wrappedValue: Self.defaultMusicVolume,
            Self.musicVolumeKey,
            store: defaults
        )
        effectsVolumeStorage = AppStorage(
            wrappedValue: 0.85,
            Self.effectsVolumeKey,
            store: defaults
        )
        hapticsEnabledStorage = AppStorage(
            wrappedValue: true,
            Self.hapticsEnabledKey,
            store: defaults
        )
        appearanceStorage = AppStorage(
            wrappedValue: TrinketDesign.AppAppearance.default.rawValue,
            Self.appearanceKey,
            store: defaults
        )

        musicVolume = musicVolumeStorage.wrappedValue
        effectsVolume = effectsVolumeStorage.wrappedValue
        hapticsEnabled = hapticsEnabledStorage.wrappedValue
        appearance = TrinketDesign.AppAppearance(rawValue: appearanceStorage.wrappedValue)
            ?? .default
    }

    private static var defaultMusicVolume: Double {
        #if targetEnvironment(simulator)
        return 0
        #else
        return 0.75
        #endif
    }
}
