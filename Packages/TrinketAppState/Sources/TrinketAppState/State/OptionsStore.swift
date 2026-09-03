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
    static let autoBattleEnabledKey = "battle.autoBattleEnabled"
    static let ultimateCinematicShowPolicyKey = "options.ultimateCinematicShowPolicy"

    static func clearDefaults(from defaults: UserDefaults) {
        defaults.removeObject(forKey: musicVolumeKey)
        defaults.removeObject(forKey: effectsVolumeKey)
        defaults.removeObject(forKey: hapticsEnabledKey)
        defaults.removeObject(forKey: rememberAutoBattlePreferenceKey)
        defaults.removeObject(forKey: autoBattleEnabledKey)
        defaults.removeObject(forKey: ultimateCinematicShowPolicyKey)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let musicVolumeValue = defaults.object(forKey: Self.musicVolumeKey) != nil
            ? defaults.double(forKey: Self.musicVolumeKey)
            : Self.defaultMusicVolume
        let effectsVolumeValue = defaults.object(forKey: Self.effectsVolumeKey) != nil
            ? defaults.double(forKey: Self.effectsVolumeKey)
            : 0.85
        let hapticsEnabledValue = defaults.object(forKey: Self.hapticsEnabledKey) != nil
            ? defaults.bool(forKey: Self.hapticsEnabledKey)
            : true
        let rememberAutoValue = defaults.bool(forKey: Self.rememberAutoBattlePreferenceKey)
        let autoBattleValue = rememberAutoValue && defaults.bool(forKey: Self.autoBattleEnabledKey)

        musicVolume = musicVolumeValue
        effectsVolume = effectsVolumeValue
        hapticsEnabled = hapticsEnabledValue
        rememberAutoBattlePreference = rememberAutoValue
        autoBattleEnabled = autoBattleValue
        ultimateCinematicShowPolicy = Self.resolveShowPolicy(from: defaults)

        if !rememberAutoValue {
            defaults.set(false, forKey: Self.autoBattleEnabledKey)
        }
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

    private static var defaultMusicVolume: Double {
        #if targetEnvironment(simulator)
        return 0
        #else
        return 0.75
        #endif
    }
}
