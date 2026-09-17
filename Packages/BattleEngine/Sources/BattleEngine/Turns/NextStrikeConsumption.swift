import TrinketContent
import TrinketCore

/// One-shot strike preparations consumed by the next qualifying damage component.
/// Computed once per component so the holy-before-double priority and the consumed
/// effect kinds cannot drift apart.
package struct NextStrikeConsumption: OptionSet {
    package let rawValue: UInt8

    package init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    package static let holyStrike = Self(rawValue: 1 << 0)
    package static let double = Self(rawValue: 1 << 1)
    package static let critical = Self(rawValue: 1 << 2)
    package static let leech = Self(rawValue: 1 << 3)
    package static let burnBonus = Self(rawValue: 1 << 4)

    package var consumedKinds: Set<EffectKind> {
        var kinds = Set<EffectKind>()
        if contains(.holyStrike) {
            kinds.insert(.nextHolyStrike)
        }
        if contains(.double) {
            kinds.insert(.nextStrikeDouble)
        }
        if contains(.critical) {
            kinds.insert(.nextStrikeCritical)
        }
        if contains(.leech) {
            kinds.insert(.nextStrikeLeech)
        }
        if contains(.burnBonus) {
            kinds.insert(.nextBurnBonus)
        }
        return kinds
    }
}
