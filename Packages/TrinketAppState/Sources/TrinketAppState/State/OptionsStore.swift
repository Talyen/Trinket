import Foundation
import SwiftUI
import TrinketPersistence

/// How Ultimate cinematics are shown before presentation.
public enum UltimateCinematicShowPolicy: String, CaseIterable, Identifiable, Sendable {
    /// Always present the full-screen Ultimate cinematic.
    case always
    /// Never present the full-screen Ultimate cinematic.
    case never
    /// Show each of Hero and Companion's Ultimate cinematic once per battle; later casts auto-skip.
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

    /// Cases shown in the Options picker.
    public static var pickerCases: [Self] {
        allCases
    }
}

/// Local player preferences. Values persist device-locally in `UserDefaults`
/// (not part of `PlayerSave` / CloudKit).
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

    /// When false (default), Auto starts OFF each battle and is not persisted.
    /// When true, the battle toolbar Auto preference is restored across battles.
    public var rememberAutoBattlePreference: Bool {
        didSet {
            defaults.set(rememberAutoBattlePreference, forKey: Self.rememberAutoBattlePreferenceKey)
            if !rememberAutoBattlePreference, autoBattleEnabled {
                autoBattleEnabled = false
            }
        }
    }

    /// Battle-toolbar Auto preference. Only meaningful when `rememberAutoBattlePreference` is on.
    public var autoBattleEnabled: Bool {
        didSet { defaults.set(autoBattleEnabled, forKey: Self.autoBattleEnabledKey) }
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

    /// Whether a new Ultimate from this actor should skip the full-screen cinematic.
    public func shouldAutoSkipUltimateCinematic(
        actorID: String,
        actorsWhoPresentedThisBattle: Set<String>
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
