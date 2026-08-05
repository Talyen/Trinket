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

/// Local player preferences. Keys are `@AppStorage`-compatible and stay device-local
/// (not part of `PlayerSave` / CloudKit).
@MainActor
@Observable
public final class OptionsStore {
    @ObservationIgnored private var musicVolumeStorage: AppStorage<Double>
    @ObservationIgnored private var effectsVolumeStorage: AppStorage<Double>
    @ObservationIgnored private var hapticsEnabledStorage: AppStorage<Bool>
    @ObservationIgnored private var rememberAutoBattlePreferenceStorage: AppStorage<Bool>
    @ObservationIgnored private var autoBattleEnabledStorage: AppStorage<Bool>
    @ObservationIgnored private var ultimateShowPolicyStorage: AppStorage<String>

    public var musicVolume: Double {
        didSet { musicVolumeStorage.wrappedValue = musicVolume }
    }

    public var effectsVolume: Double {
        didSet { effectsVolumeStorage.wrappedValue = effectsVolume }
    }

    public var hapticsEnabled: Bool {
        didSet { hapticsEnabledStorage.wrappedValue = hapticsEnabled }
    }

    /// When false (default), Auto starts OFF each battle and is not persisted.
    /// When true, the battle toolbar Auto preference is restored across battles.
    public var rememberAutoBattlePreference: Bool {
        didSet {
            rememberAutoBattlePreferenceStorage.wrappedValue = rememberAutoBattlePreference
            if !rememberAutoBattlePreference, autoBattleEnabled {
                autoBattleEnabled = false
            }
        }
    }

    /// Battle-toolbar Auto preference. Only meaningful when `rememberAutoBattlePreference` is on.
    public var autoBattleEnabled: Bool {
        didSet { autoBattleEnabledStorage.wrappedValue = autoBattleEnabled }
    }

    public var ultimateCinematicShowPolicy: UltimateCinematicShowPolicy {
        didSet { ultimateShowPolicyStorage.wrappedValue = ultimateCinematicShowPolicy.rawValue }
    }

    static let musicVolumeKey = "options.musicVolume"
    static let effectsVolumeKey = "options.effectsVolume"
    static let hapticsEnabledKey = "options.hapticsEnabled"
    static let rememberAutoBattlePreferenceKey = "options.rememberAutoBattlePreference"
    static let autoBattleEnabledKey = "battle.autoBattleEnabled"
    static let ultimateCinematicShowPolicyKey = "options.ultimateCinematicShowPolicy"

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
        rememberAutoBattlePreferenceStorage = AppStorage(
            wrappedValue: false,
            Self.rememberAutoBattlePreferenceKey,
            store: defaults
        )
        autoBattleEnabledStorage = AppStorage(
            wrappedValue: false,
            Self.autoBattleEnabledKey,
            store: defaults
        )

        let resolvedPolicy = Self.resolveShowPolicy(from: defaults)
        ultimateShowPolicyStorage = AppStorage(
            wrappedValue: resolvedPolicy.rawValue,
            Self.ultimateCinematicShowPolicyKey,
            store: defaults
        )

        musicVolume = musicVolumeStorage.wrappedValue
        effectsVolume = effectsVolumeStorage.wrappedValue
        hapticsEnabled = hapticsEnabledStorage.wrappedValue
        rememberAutoBattlePreference = rememberAutoBattlePreferenceStorage.wrappedValue
        autoBattleEnabled = autoBattleEnabledStorage.wrappedValue
        ultimateCinematicShowPolicy = resolvedPolicy

        // First assignments in init do not run didSet; clear stale ON after full init.
        if !rememberAutoBattlePreference, autoBattleEnabled {
            autoBattleEnabled = false
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
