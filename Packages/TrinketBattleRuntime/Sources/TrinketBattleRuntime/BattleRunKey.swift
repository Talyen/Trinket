/// Opaque prepared-run / origin key.
///
/// Play owns encoding and decoding mode identity. Battle only stores and matches
/// this value while the run is prepared.
public struct BattleRunKey: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
