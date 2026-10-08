import Foundation

@MainActor
public struct BattlePresentationDependencies {
    public let playSFX: ([String]) -> Void
    public let warmSFX: ([String], Int) -> Void
    public let hapticsEnabled: () -> Bool
    public let rememberAutoBattlePreference: () -> Bool
    public let autoBattleEnabled: () -> Bool
    public let setAutoBattleEnabled: (Bool) -> Void

    public static let silent = Self(
        playSFX: { _ in },
        warmSFX: { _, _ in },
        hapticsEnabled: { false },
        rememberAutoBattlePreference: { false },
        autoBattleEnabled: { false },
        setAutoBattleEnabled: { _ in },
    )

    public init(
        playSFX: @escaping ([String]) -> Void,
        warmSFX: @escaping ([String], Int) -> Void,
        hapticsEnabled: @escaping () -> Bool,
        rememberAutoBattlePreference: @escaping () -> Bool = { false },
        autoBattleEnabled: @escaping () -> Bool = { false },
        setAutoBattleEnabled: @escaping (Bool) -> Void = { _ in },
    ) {
        self.playSFX = playSFX
        self.warmSFX = warmSFX
        self.hapticsEnabled = hapticsEnabled
        self.rememberAutoBattlePreference = rememberAutoBattlePreference
        self.autoBattleEnabled = autoBattleEnabled
        self.setAutoBattleEnabled = setAutoBattleEnabled
    }
}
