import SwiftUI

@Observable
final class OptionsStore {
    var musicVolume: Double = 0.75
    var effectsVolume: Double = 0.85
    var hapticsEnabled = true
    var theme: TrinketDesign.AppTheme = .system

    private let defaults = UserDefaults.standard

    init() {
        musicVolume = defaults.object(forKey: "options.musicVolume") as? Double ?? 0.75
        effectsVolume = defaults.object(forKey: "options.effectsVolume") as? Double ?? 0.85
        hapticsEnabled = defaults.object(forKey: "options.hapticsEnabled") as? Bool ?? true
        if let raw = defaults.string(forKey: "options.theme"),
           let t = TrinketDesign.AppTheme(rawValue: raw) {
            theme = t
        }
    }

    func persist() {
        defaults.set(musicVolume, forKey: "options.musicVolume")
        defaults.set(effectsVolume, forKey: "options.effectsVolume")
        defaults.set(hapticsEnabled, forKey: "options.hapticsEnabled")
        defaults.set(theme.rawValue, forKey: "options.theme")
    }
}
