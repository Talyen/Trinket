import Foundation
import SwiftUI
import TrinketDesignSystem

/// How Ultimate cinematics may be dismissed early.
enum UltimateCinematicSkipPolicy: String, CaseIterable, Identifiable, Sendable {
    case always
    case never
    case afterFirstView

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .always: return "Always"
        case .never: return "Never"
        case .afterFirstView: return "After First View"
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
    @ObservationIgnored private var appearanceStorage: AppStorage<String>
    @ObservationIgnored private var ultimateSkipPolicyStorage: AppStorage<String>
    @ObservationIgnored private var seenUltimateCinematicsStorage: AppStorage<String>

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

    var ultimateCinematicSkipPolicy: UltimateCinematicSkipPolicy {
        didSet { ultimateSkipPolicyStorage.wrappedValue = ultimateCinematicSkipPolicy.rawValue }
    }

    static let musicVolumeKey = "options.musicVolume"
    static let effectsVolumeKey = "options.effectsVolume"
    static let hapticsEnabledKey = "options.hapticsEnabled"
    static let appearanceKey = "options.appearance"
    static let ultimateCinematicSkipPolicyKey = "options.ultimateCinematicSkipPolicy"
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
        appearanceStorage = AppStorage(
            wrappedValue: TrinketDesign.AppAppearance.default.rawValue,
            Self.appearanceKey,
            store: defaults
        )
        ultimateSkipPolicyStorage = AppStorage(
            wrappedValue: UltimateCinematicSkipPolicy.always.rawValue,
            Self.ultimateCinematicSkipPolicyKey,
            store: defaults
        )
        seenUltimateCinematicsStorage = AppStorage(
            wrappedValue: "",
            Self.seenUltimateCinematicsKey,
            store: defaults
        )

        musicVolume = musicVolumeStorage.wrappedValue
        effectsVolume = effectsVolumeStorage.wrappedValue
        hapticsEnabled = hapticsEnabledStorage.wrappedValue
        appearance = TrinketDesign.AppAppearance(rawValue: appearanceStorage.wrappedValue)
            ?? .default
        ultimateCinematicSkipPolicy = UltimateCinematicSkipPolicy(
            rawValue: ultimateSkipPolicyStorage.wrappedValue
        ) ?? .always
    }

    func hasSeenUltimateCinematic(abilityID: String) -> Bool {
        seenUltimateAbilityIDs().contains(abilityID)
    }

    func markUltimateCinematicSeen(abilityID: String) {
        guard !abilityID.isEmpty else { return }
        var seen = seenUltimateAbilityIDs()
        guard seen.insert(abilityID).inserted else { return }
        seenUltimateCinematicsStorage.wrappedValue = seen.sorted().joined(separator: ",")
    }

    func canSkipUltimateCinematic(abilityID: String) -> Bool {
        switch ultimateCinematicSkipPolicy {
        case .always:
            return true
        case .never:
            return false
        case .afterFirstView:
            return hasSeenUltimateCinematic(abilityID: abilityID)
        }
    }

    private func seenUltimateAbilityIDs() -> Set<String> {
        let raw = seenUltimateCinematicsStorage.wrappedValue
        guard !raw.isEmpty else { return [] }
        return Set(raw.split(separator: ",").map(String.init))
    }

    private static var defaultMusicVolume: Double {
        #if targetEnvironment(simulator)
        return 0
        #else
        return 0.75
        #endif
    }
}
