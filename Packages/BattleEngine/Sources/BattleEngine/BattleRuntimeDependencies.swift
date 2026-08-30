import Foundation

@MainActor
public struct BattleRuntimeDependencies {
    public let playSFX: ([String]) -> Void
    public let warmSFX: ([String], Int) -> Void
    public let hapticsEnabled: () -> Bool
    public let effectsVolume: () -> Double
    public let rememberAutoBattlePreference: () -> Bool
    public let autoBattleEnabled: () -> Bool
    public let setAutoBattleEnabled: (Bool) -> Void
    public let shouldAutoSkipUltimateCinematic: (String, Set<String>) -> Bool

    public static let silent = Self(
        playSFX: { _ in },
        warmSFX: { _, _ in },
        hapticsEnabled: { false },
        effectsVolume: { 0 },
        rememberAutoBattlePreference: { false },
        autoBattleEnabled: { false },
        setAutoBattleEnabled: { _ in },
        shouldAutoSkipUltimateCinematic: { _, _ in false },
    )

    public init(
        playSFX: @escaping ([String]) -> Void,
        warmSFX: @escaping ([String], Int) -> Void,
        hapticsEnabled: @escaping () -> Bool,
        effectsVolume: @escaping () -> Double,
        rememberAutoBattlePreference: @escaping () -> Bool = { false },
        autoBattleEnabled: @escaping () -> Bool = { false },
        setAutoBattleEnabled: @escaping (Bool) -> Void = { _ in },
        shouldAutoSkipUltimateCinematic: @escaping (String, Set<String>) -> Bool,
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
