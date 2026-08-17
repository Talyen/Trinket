import Foundation
import TrinketCore

/// The `onHit` trigger family of `CombatTraitTriggers`.
public struct OnHitTriggers: Equatable, Hashable, Sendable {
    public var onHitAttackerBurn: Int = 0
    public var onHitAttackerFreezeBuildup: Int = 0
    public var onHitAttackerPoison: Int = 0
    public var onHitAttackerBleedPotency: Int = 0
    public var onHitAttackerBleedTurns: Int = 0
    public var onHitAttackerHoly: Int = 0
    public var shieldErosionKeyword: Keyword?
    public var shieldErosionTicks: Int = 0
    public var mitigationShredKeyword: Keyword?
    public var mitigationShredMultiplier: Double = 0
    public var mitigationShredDurationTurns: Int = 0

    public init(
        onHitAttackerBurn: Int = 0,
        onHitAttackerFreezeBuildup: Int = 0,
        onHitAttackerPoison: Int = 0,
        onHitAttackerBleedPotency: Int = 0,
        onHitAttackerBleedTurns: Int = 0,
        onHitAttackerHoly: Int = 0,
        shieldErosionKeyword: Keyword? = nil,
        shieldErosionTicks: Int = 0,
        mitigationShredKeyword: Keyword? = nil,
        mitigationShredMultiplier: Double = 0,
        mitigationShredDurationTurns: Int = 0
    ) {
        self.onHitAttackerBurn = onHitAttackerBurn
        self.onHitAttackerFreezeBuildup = onHitAttackerFreezeBuildup
        self.onHitAttackerPoison = onHitAttackerPoison
        self.onHitAttackerBleedPotency = onHitAttackerBleedPotency
        self.onHitAttackerBleedTurns = onHitAttackerBleedTurns
        self.onHitAttackerHoly = onHitAttackerHoly
        self.shieldErosionKeyword = shieldErosionKeyword
        self.shieldErosionTicks = shieldErosionTicks
        self.mitigationShredKeyword = mitigationShredKeyword
        self.mitigationShredMultiplier = mitigationShredMultiplier
        self.mitigationShredDurationTurns = mitigationShredDurationTurns
    }
}

extension OnHitTriggers {
    mutating func merge(_ other: Self) {
        onHitAttackerBurn += other.onHitAttackerBurn
        onHitAttackerFreezeBuildup += other.onHitAttackerFreezeBuildup
        onHitAttackerPoison += other.onHitAttackerPoison
        onHitAttackerBleedPotency += other.onHitAttackerBleedPotency
        onHitAttackerBleedTurns = max(onHitAttackerBleedTurns, other.onHitAttackerBleedTurns)
        onHitAttackerHoly += other.onHitAttackerHoly
        shieldErosionKeyword = other.shieldErosionKeyword ?? shieldErosionKeyword
        shieldErosionTicks += other.shieldErosionTicks
        mitigationShredKeyword = other.mitigationShredKeyword ?? mitigationShredKeyword
        mitigationShredMultiplier = max(mitigationShredMultiplier, other.mitigationShredMultiplier)
        mitigationShredDurationTurns = max(mitigationShredDurationTurns, other.mitigationShredDurationTurns)
    }
}

extension OnHitTriggers {
    /// Decodes this family's flat trigger keys.
    init(from values: DefaultingTriggerDecoder, legacyAffix _: DefaultingTriggerDecoder?) throws {
        try self.init(
            onHitAttackerBurn: values.decode(Int.self, "onHitAttackerBurn", default: 0),
            onHitAttackerFreezeBuildup: values.decode(Int.self, "onHitAttackerFreezeBuildup", default: 0),
            onHitAttackerPoison: values.decode(Int.self, "onHitAttackerPoison", default: 0),
            onHitAttackerBleedPotency: values.decode(Int.self, "onHitAttackerBleedPotency", default: 0),
            onHitAttackerBleedTurns: values.decode(Int.self, "onHitAttackerBleedTurns", default: 0),
            onHitAttackerHoly: values.decode(Int.self, "onHitAttackerHoly", default: 0),
            shieldErosionKeyword: values.decode(Keyword?.self, "shieldErosionKeyword", default: nil),
            shieldErosionTicks: values.decode(Int.self, "shieldErosionTicks", default: 0),
            mitigationShredKeyword: values.decode(Keyword?.self, "mitigationShredKeyword", default: nil),
            mitigationShredMultiplier: values.decode(Double.self, "mitigationShredMultiplier", default: 0),
            mitigationShredDurationTurns: values.decode(Int.self, "mitigationShredDurationTurns", default: 0)
        )
    }

    func encode(to container: inout KeyedEncodingContainer<TriggerCodingKey>) throws {
        try container.encodeNonDefault(onHitAttackerBurn, "onHitAttackerBurn", default: 0)
        try container.encodeNonDefault(onHitAttackerFreezeBuildup, "onHitAttackerFreezeBuildup", default: 0)
        try container.encodeNonDefault(onHitAttackerPoison, "onHitAttackerPoison", default: 0)
        try container.encodeNonDefault(onHitAttackerBleedPotency, "onHitAttackerBleedPotency", default: 0)
        try container.encodeNonDefault(onHitAttackerBleedTurns, "onHitAttackerBleedTurns", default: 0)
        try container.encodeNonDefault(onHitAttackerHoly, "onHitAttackerHoly", default: 0)
        try container.encodeNonDefault(shieldErosionKeyword, "shieldErosionKeyword", default: nil)
        try container.encodeNonDefault(shieldErosionTicks, "shieldErosionTicks", default: 0)
        try container.encodeNonDefault(mitigationShredKeyword, "mitigationShredKeyword", default: nil)
        try container.encodeNonDefault(mitigationShredMultiplier, "mitigationShredMultiplier", default: 0)
        try container.encodeNonDefault(mitigationShredDurationTurns, "mitigationShredDurationTurns", default: 0)
    }
}
