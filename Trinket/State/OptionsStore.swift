import Foundation
import SwiftUI
import TrinketPersistence

/// How Ultimate cinematics are shown before presentation.
enum UltimateCinematicShowPolicy: String, CaseIterable, Identifiable {
    /// Always present the full-screen Ultimate cinematic.
    case always
    /// Never present the full-screen Ultimate cinematic.
    case never
    /// Show each of Hero and Companion's Ultimate cinematic once per battle; later casts auto-skip.
    case oncePerBattle
    /// Legacy raw value from an earlier Options label; migrated to `oncePerBattle` on load.
    case afterFirstView

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .always: "Always"
        case .never: "Never"
        case .oncePerBattle, .afterFirstView: "Once Per Battle"
        }
    }

    /// Cases shown in the Options picker (excludes legacy alias).
    static var pickerCases: [Self] {
        [.always, .never, .oncePerBattle]
    }

    var normalized: Self {
        self == .afterFirstView ? .oncePerBattle : self
    }

    /// Maps a value stored under the former "Skip Ultimate Animations" framing.
    static func migratedFromSkipPolicy(_ rawValue: String) -> Self {
        switch Self(rawValue: rawValue)?.normalized {
        case .always:
            // Old "Always" meant always skip → never show.
            .never
        case .never:
            // Old "Never" meant never skip → always show.
            .always
        case .oncePerBattle, .afterFirstView, .none:
            .oncePerBattle
        }
    }
}

/// Local player preferences. Keys are `@AppStorage`-compatible and stay device-local
/// (not part of `PlayerSave` / CloudKit).
@MainActor
@Observable
final class OptionsStore {
    @ObservationIgnored private var musicVolumeStorage: AppStorage<Double>
    @ObservationIgnored private var effectsVolumeStorage: AppStorage<Double>
    @ObservationIgnored private var hapticsEnabledStorage: AppStorage<Bool>
    @ObservationIgnored private var ultimateShowPolicyStorage: AppStorage<String>

    var musicVolume: Double {
        didSet { musicVolumeStorage.wrappedValue = musicVolume }
    }

    var effectsVolume: Double {
        didSet { effectsVolumeStorage.wrappedValue = effectsVolume }
    }

    var hapticsEnabled: Bool {
        didSet { hapticsEnabledStorage.wrappedValue = hapticsEnabled }
    }

    var ultimateCinematicShowPolicy: UltimateCinematicShowPolicy {
        didSet {
            let normalized = ultimateCinematicShowPolicy.normalized
            ultimateShowPolicyStorage.wrappedValue = normalized.rawValue
            if ultimateCinematicShowPolicy != normalized {
                ultimateCinematicShowPolicy = normalized
            }
        }
    }

    static let musicVolumeKey = "options.musicVolume"
    static let effectsVolumeKey = "options.effectsVolume"
    static let hapticsEnabledKey = "options.hapticsEnabled"
    static let ultimateCinematicShowPolicyKey = "options.ultimateCinematicShowPolicy"
    /// Former "Skip Ultimate Animations" key. Cleared after one-shot migration to show framing.
    static let ultimateCinematicSkipPolicyKey = "options.ultimateCinematicSkipPolicy"
    /// Removed: appearance preference. Kept so reset clears any leftover key.
    static let appearanceKey = "options.appearance"
    /// Removed: lifetime seen-ability tracking. Kept so reset clears any leftover key.
    static let seenUltimateCinematicsKey = "options.seenUltimateCinematics"

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

        let resolvedPolicy = Self.resolveShowPolicy(from: defaults)
        ultimateShowPolicyStorage = AppStorage(
            wrappedValue: resolvedPolicy.rawValue,
            Self.ultimateCinematicShowPolicyKey,
            store: defaults
        )

        musicVolume = musicVolumeStorage.wrappedValue
        effectsVolume = effectsVolumeStorage.wrappedValue
        hapticsEnabled = hapticsEnabledStorage.wrappedValue
        ultimateCinematicShowPolicy = resolvedPolicy
        ultimateShowPolicyStorage.wrappedValue = resolvedPolicy.rawValue
    }

    /// Whether a new Ultimate from this actor should skip the full-screen cinematic.
    func shouldAutoSkipUltimateCinematic(
        actorID: String,
        actorsWhoPresentedThisBattle: Set<String>
    ) -> Bool {
        switch ultimateCinematicShowPolicy.normalized {
        case .always:
            false
        case .oncePerBattle, .afterFirstView:
            actorsWhoPresentedThisBattle.contains(actorID)
        case .never:
            true
        }
    }

    private static func resolveShowPolicy(from defaults: UserDefaults) -> UltimateCinematicShowPolicy {
        if let raw = defaults.string(forKey: ultimateCinematicShowPolicyKey),
           let policy = UltimateCinematicShowPolicy(rawValue: raw) {
            return policy.normalized
        }

        if let legacyRaw = defaults.string(forKey: ultimateCinematicSkipPolicyKey) {
            let migrated = UltimateCinematicShowPolicy.migratedFromSkipPolicy(legacyRaw)
            defaults.set(migrated.rawValue, forKey: ultimateCinematicShowPolicyKey)
            defaults.removeObject(forKey: ultimateCinematicSkipPolicyKey)
            return migrated
        }

        return .oncePerBattle
    }

    private static var defaultMusicVolume: Double {
        #if targetEnvironment(simulator)
        return 0
        #else
        return 0.75
        #endif
    }
}
