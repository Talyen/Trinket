import Foundation

enum BattleRNGSeed {
    static func fresh() -> UInt64 {
        UInt64.random(in: UInt64.min ... UInt64.max)
    }
}
