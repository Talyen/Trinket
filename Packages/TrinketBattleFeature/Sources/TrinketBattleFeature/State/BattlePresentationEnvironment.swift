import Foundation

/// App-provided presentation behavior required by Battle without exposing app-owned stores.
@MainActor
public struct BattlePresentationEnvironment {
    public var playSFX: ([String]) -> Void
    public var warmSFX: ([String], Int) -> Void
    public var hapticsEnabled: () -> Bool
    public var effectsVolume: () -> Double
    public var rememberAutoBattlePreference: () -> Bool
    public var autoBattleEnabled: () -> Bool
    public var setAutoBattleEnabled: (Bool) -> Void
    public var shouldAutoSkipUltimateCinematic: (String, Set<String>) -> Bool

    public static let silent = Self(
        playSFX: { _ in },
        warmSFX: { _, _ in },
        hapticsEnabled: { false },
        effectsVolume: { 0 },
        rememberAutoBattlePreference: { false },
        autoBattleEnabled: { false },
        setAutoBattleEnabled: { _ in },
        shouldAutoSkipUltimateCinematic: { _, _ in false }
    )

    public init(
        playSFX: @escaping ([String]) -> Void,
        warmSFX: @escaping ([String], Int) -> Void,
        hapticsEnabled: @escaping () -> Bool,
        effectsVolume: @escaping () -> Double,
        rememberAutoBattlePreference: @escaping () -> Bool = { false },
        autoBattleEnabled: @escaping () -> Bool = { false },
        setAutoBattleEnabled: @escaping (Bool) -> Void = { _ in },
        shouldAutoSkipUltimateCinematic: @escaping (String, Set<String>) -> Bool
    ) {
        self.playSFX = playSFX
        self.warmSFX = warmSFX
        self.hapticsEnabled = hapticsEnabled
        self.effectsVolume = effectsVolume
        self.rememberAutoBattlePreference = rememberAutoBattlePreference
        self.autoBattleEnabled = autoBattleEnabled
        self.setAutoBattleEnabled = setAutoBattleEnabled
        self.shouldAutoSkipUltimateCinematic = shouldAutoSkipUltimateCinematic
    }
}
