import Foundation
import Observation

public enum UltimateCinematicShowPolicy: String, CaseIterable, Identifiable, Sendable {
    case always
    case never
    case oncePerBattle

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .always: "Always"
        case .never: "Never"
        case .oncePerBattle: "Once Per Battle"
        }
    }
}

@MainActor
@Observable
public final class OptionsStore {
    @ObservationIgnored private let defaults: UserDefaults

    public var musicVolume: Double {
        didSet { defaults.set(musicVolume, forKey: Self.musicVolumeKey) }
    }

    public var effectsVolume: Double {
        didSet { defaults.set(effectsVolume, forKey: Self.effectsVolumeKey) }
    }

    public var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Self.hapticsEnabledKey) }
    }

    public var rememberAutoBattlePreference: Bool {
        didSet {
            defaults.set(rememberAutoBattlePreference, forKey: Self.rememberAutoBattlePreferenceKey)
            synchronizeAutoBattlePreference()
        }
    }

    public var autoBattleEnabled: Bool {
        didSet { defaults.set(autoBattleEnabled, forKey: Self.autoBattleEnabledKey) }
    }

    private func synchronizeAutoBattlePreference() {
        if !rememberAutoBattlePreference, autoBattleEnabled {
            autoBattleEnabled = false
        }
    }

    public var ultimateCinematicShowPolicy: UltimateCinematicShowPolicy {
        didSet { defaults.set(ultimateCinematicShowPolicy.rawValue, forKey: Self.ultimateCinematicShowPolicyKey) }
    }

    static let musicVolumeKey = "options.musicVolume"
    static let effectsVolumeKey = "options.effectsVolume"
    static let hapticsEnabledKey = "options.hapticsEnabled"
    static let rememberAutoBattlePreferenceKey = "options.rememberAutoBattlePreference"
    static let autoBattleEnabledKey = "options.autoBattleEnabled"
    static let ultimateCinematicShowPolicyKey = "options.ultimateCinematicShowPolicy"
    private static let legacyAutoBattleEnabledKey = "battle.autoBattleEnabled"

    static func clearDefaults(from defaults: UserDefaults) {
        defaults.removeObject(forKey: musicVolumeKey)
        defaults.removeObject(forKey: effectsVolumeKey)
        defaults.removeObject(forKey: hapticsEnabledKey)
        defaults.removeObject(forKey: rememberAutoBattlePreferenceKey)
        defaults.removeObject(forKey: autoBattleEnabledKey)
        defaults.removeObject(forKey: legacyAutoBattleEnabledKey)
        defaults.removeObject(forKey: ultimateCinematicShowPolicyKey)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rememberAutoValue = Self.readBool(from: defaults, key: Self.rememberAutoBattlePreferenceKey, default: false)
        let autoBattleValue = rememberAutoValue && Self.readAutoBattleEnabled(from: defaults)

        musicVolume = Self.readDouble(from: defaults, key: Self.musicVolumeKey, default: Self.defaultMusicVolume)
        effectsVolume = Self.readDouble(from: defaults, key: Self.effectsVolumeKey, default: Self.defaultEffectsVolume)
        hapticsEnabled = Self.readBool(from: defaults, key: Self.hapticsEnabledKey, default: Self.defaultHapticsEnabled)
        rememberAutoBattlePreference = rememberAutoValue
        autoBattleEnabled = autoBattleValue
        ultimateCinematicShowPolicy = Self.resolveShowPolicy(from: defaults)

        // Converge the legacy key onto options.* once: persist the migrated value
        // before dropping the legacy key, so a carried-over preference survives
        // a relaunch even if the user never toggles it again.
        if rememberAutoValue,
           defaults.object(forKey: Self.autoBattleEnabledKey) == nil,
           defaults.object(forKey: Self.legacyAutoBattleEnabledKey) != nil {
            defaults.set(autoBattleValue, forKey: Self.autoBattleEnabledKey)
        }
        if !rememberAutoValue {
            defaults.set(false, forKey: Self.autoBattleEnabledKey)
        }
        defaults.removeObject(forKey: Self.legacyAutoBattleEnabledKey)
    }

    public func shouldAutoSkipUltimateCinematic(
        actorID: String,
        actorsWhoPresentedThisBattle: Set<String>,
    ) -> Bool {
        switch ultimateCinematicShowPolicy {
        case .always:
            false
        case .oncePerBattle:
            actorsWhoPresentedThisBattle.contains(actorID)
        case .never:
            true
        }
    }

    private static func resolveShowPolicy(from defaults: UserDefaults) -> UltimateCinematicShowPolicy {
        guard let raw = defaults.string(forKey: ultimateCinematicShowPolicyKey),
              let policy = UltimateCinematicShowPolicy(rawValue: raw)
        else { return .oncePerBattle }
        return policy
    }

    private static func readDouble(from defaults: UserDefaults, key: String, default defaultValue: Double) -> Double {
        defaults.object(forKey: key) != nil ? defaults.double(forKey: key) : defaultValue
    }

    private static func readBool(from defaults: UserDefaults, key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) != nil ? defaults.bool(forKey: key) : defaultValue
    }

    private static func readAutoBattleEnabled(from defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: autoBattleEnabledKey) != nil {
            return defaults.bool(forKey: autoBattleEnabledKey)
        }
        // Legacy key predating the options.* convention.
        return defaults.bool(forKey: legacyAutoBattleEnabledKey)
    }

    private static let defaultEffectsVolume = 0.85
    private static let defaultHapticsEnabled = true

    private static var defaultMusicVolume: Double {
        #if targetEnvironment(simulator)
        return 0
        #else
        return 0.75
        #endif
    }
}
