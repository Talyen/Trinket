import SwiftUI
import TrinketDesignSystem

@MainActor
@Observable
final class OptionsStore {
    private let defaults: UserDefaults

    var musicVolume: Double {
        didSet { defaults.set(musicVolume, forKey: Self.musicVolumeKey) }
    }

    var effectsVolume: Double {
        didSet { defaults.set(effectsVolume, forKey: Self.effectsVolumeKey) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Self.hapticsEnabledKey) }
    }

    var appearance: TrinketDesign.AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    static let musicVolumeKey = "options.musicVolume"
    static let effectsVolumeKey = "options.effectsVolume"
    static let hapticsEnabledKey = "options.hapticsEnabled"
    static let appearanceKey = "options.appearance"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        musicVolume = defaults.object(forKey: Self.musicVolumeKey) as? Double ?? Self.defaultMusicVolume
        effectsVolume = defaults.object(forKey: Self.effectsVolumeKey) as? Double ?? 0.85
        hapticsEnabled = defaults.object(forKey: Self.hapticsEnabledKey) as? Bool ?? true

        if let raw = defaults.string(forKey: Self.appearanceKey),
           let resolved = TrinketDesign.AppAppearance(rawValue: raw) {
            appearance = resolved
        } else {
            appearance = .default
        }
    }

    private static var defaultMusicVolume: Double {
        #if targetEnvironment(simulator)
        return 0
        #else
        return 0.75
        #endif
    }
}
