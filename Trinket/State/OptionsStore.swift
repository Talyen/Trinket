import SwiftUI
import TrinketDesignSystem

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

    var theme: TrinketDesign.AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Self.themeKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        musicVolume = defaults.object(forKey: Self.musicVolumeKey) as? Double ?? Self.defaultMusicVolume
        effectsVolume = defaults.object(forKey: Self.effectsVolumeKey) as? Double ?? 0.85
        hapticsEnabled = defaults.object(forKey: Self.hapticsEnabledKey) as? Bool ?? true
        if let raw = defaults.string(forKey: Self.themeKey),
           let resolved = TrinketDesign.AppTheme(rawValue: raw) {
            theme = resolved
        } else {
            theme = .dark
        }
    }

    private static let musicVolumeKey = "options.musicVolume"
    private static let effectsVolumeKey = "options.effectsVolume"
    private static let hapticsEnabledKey = "options.hapticsEnabled"
    private static let themeKey = "options.theme"

    private static var defaultMusicVolume: Double {
        #if targetEnvironment(simulator)
        return 0
        #else
        return 0.75
        #endif
    }
}
