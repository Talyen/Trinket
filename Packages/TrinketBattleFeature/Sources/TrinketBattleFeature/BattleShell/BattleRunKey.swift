import Foundation

/// Opaque prepared-run / origin key. Battle stores and matches keys; it never
/// interprets play-mode identity. AppState owns encode/decode via `PlayBattleOrigin`.
public struct BattleRunKey: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
