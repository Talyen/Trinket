import Foundation
import SwiftUI

/// How Ultimate cinematics may be dismissed or limited.
enum UltimateCinematicSkipPolicy: String, CaseIterable, Identifiable {
    case always
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
        case .oncePerBattle, .afterFirstView: "Show Once Per Battle"
        }
    }

    /// Cases shown in the Options picker (excludes legacy alias).
    static var pickerCases: [UltimateCinematicSkipPolicy] {
        [.always, .never, .oncePerBattle]
    }

    var normalized: UltimateCinematicSkipPolicy {
        self == .afterFirstView ? .oncePerBattle : self
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
    @ObservationIgnored private var ultimateSkipPolicyStorage: AppStorage<String>

    var musicVolume: Double {
        didSet { musicVolumeStorage.wrappedValue = musicVolume }
    }

    var effectsVolume: Double {
        didSet { effectsVolumeStorage.wrappedValue = effectsVolume }
    }

    var hapticsEnabled: Bool {
        didSet { hapticsEnabledStorage.wrappedValue = hapticsEnabled }
    }

    var ultimateCinematicSkipPolicy: UltimateCinematicSkipPolicy {
        didSet {
            let normalized = ultimateCinematicSkipPolicy.normalized
            ultimateSkipPolicyStorage.wrappedValue = normalized.rawValue
            if ultimateCinematicSkipPolicy != normalized {
                ultimateCinematicSkipPolicy = normalized
            }
        }
    }

    static let musicVolumeKey = "options.musicVolume"
    static let effectsVolumeKey = "options.effectsVolume"
    static let hapticsEnabledKey = "options.hapticsEnabled"
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
        ultimateSkipPolicyStorage = AppStorage(
            wrappedValue: UltimateCinematicSkipPolicy.always.rawValue,
            Self.ultimateCinematicSkipPolicyKey,
            store: defaults
        )

        musicVolume = musicVolumeStorage.wrappedValue
        effectsVolume = effectsVolumeStorage.wrappedValue
        hapticsEnabled = hapticsEnabledStorage.wrappedValue
        let loadedPolicy = UltimateCinematicSkipPolicy(
            rawValue: ultimateSkipPolicyStorage.wrappedValue
        ) ?? .always
        ultimateCinematicSkipPolicy = loadedPolicy.normalized
        if loadedPolicy != ultimateCinematicSkipPolicy {
            ultimateSkipPolicyStorage.wrappedValue = ultimateCinematicSkipPolicy.rawValue
        }
    }

    /// Whether the player may tap-to-skip the cinematic currently on screen.
    func canSkipUltimateCinematic() -> Bool {
        switch ultimateCinematicSkipPolicy.normalized {
        case .always, .oncePerBattle, .afterFirstView:
            true
        case .never:
            false
        }
    }

    /// Whether a new Ultimate from this actor should skip the full-screen cinematic
    /// under the once-per-battle policy (Hero and Companion each get one show per battle).
    func shouldAutoSkipUltimateCinematic(
        actorID: String,
        actorsWhoPresentedThisBattle: Set<String>
    ) -> Bool {
        switch ultimateCinematicSkipPolicy.normalized {
        case .oncePerBattle, .afterFirstView:
            actorsWhoPresentedThisBattle.contains(actorID)
        case .always, .never:
            false
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
