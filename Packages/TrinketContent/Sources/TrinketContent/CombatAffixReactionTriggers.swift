import Foundation
import TrinketCore

/// Heap-backed so `CombatTraitTriggers.affixReactions` stays pointer-sized.
/// Inline `Optional<large struct>` permanently bloated every profile copy and
/// overflowed balance-sim worker stacks.
///
/// Concurrency-Safety: `@unchecked Sendable` — heap-backed mutable class; merged only
/// after `CombatTraitTriggers` CoW / `copy()` ensures a unique trigger bag; no concurrent
/// shared mutation.
public final class CombatAffixReactionTriggers: @unchecked Sendable {
    public var enemyStunnedPurgeCount: Int = 0
    public var enemyStunnedPurgeAll: Bool = false
    public var criticalPurgeCount: Int = 0
    public var criticalPurgeAll: Bool = false
    public var criticalGoldFlat: Int = 0
    public var leechRestoreManaFlat: Int = 0
    public var gainManaBlockFlat: Int = 0
    public var defeatEnemyGoldFlat: Int = 0
    public var leechGoldFlat: Int = 0
    public var dodgeHealFlat: Int = 0
    public var dodgeChanceBelowHealthPercentThreshold: Double = 0
    public var dodgeChanceBelowHealthPercentBonus: Double = 0
    public var dodgeDealStunFlat: Int = 0

    public init(
        enemyStunnedPurgeCount: Int = 0,
        enemyStunnedPurgeAll: Bool = false,
        criticalPurgeCount: Int = 0,
        criticalPurgeAll: Bool = false,
        criticalGoldFlat: Int = 0,
        leechRestoreManaFlat: Int = 0,
        gainManaBlockFlat: Int = 0,
        defeatEnemyGoldFlat: Int = 0,
        leechGoldFlat: Int = 0,
        dodgeHealFlat: Int = 0,
        dodgeChanceBelowHealthPercentThreshold: Double = 0,
        dodgeChanceBelowHealthPercentBonus: Double = 0,
        dodgeDealStunFlat: Int = 0
    ) {
        self.enemyStunnedPurgeCount = enemyStunnedPurgeCount
        self.enemyStunnedPurgeAll = enemyStunnedPurgeAll
        self.criticalPurgeCount = criticalPurgeCount
        self.criticalPurgeAll = criticalPurgeAll
        self.criticalGoldFlat = criticalGoldFlat
        self.leechRestoreManaFlat = leechRestoreManaFlat
        self.gainManaBlockFlat = gainManaBlockFlat
        self.defeatEnemyGoldFlat = defeatEnemyGoldFlat
        self.leechGoldFlat = leechGoldFlat
        self.dodgeHealFlat = dodgeHealFlat
        self.dodgeChanceBelowHealthPercentThreshold = dodgeChanceBelowHealthPercentThreshold
        self.dodgeChanceBelowHealthPercentBonus = dodgeChanceBelowHealthPercentBonus
        self.dodgeDealStunFlat = dodgeDealStunFlat
    }

    public func copy() -> CombatAffixReactionTriggers {
        CombatAffixReactionTriggers(
            enemyStunnedPurgeCount: enemyStunnedPurgeCount,
            enemyStunnedPurgeAll: enemyStunnedPurgeAll,
            criticalPurgeCount: criticalPurgeCount,
            criticalPurgeAll: criticalPurgeAll,
            criticalGoldFlat: criticalGoldFlat,
            leechRestoreManaFlat: leechRestoreManaFlat,
            gainManaBlockFlat: gainManaBlockFlat,
            defeatEnemyGoldFlat: defeatEnemyGoldFlat,
            leechGoldFlat: leechGoldFlat,
            dodgeHealFlat: dodgeHealFlat,
            dodgeChanceBelowHealthPercentThreshold: dodgeChanceBelowHealthPercentThreshold,
            dodgeChanceBelowHealthPercentBonus: dodgeChanceBelowHealthPercentBonus,
            dodgeDealStunFlat: dodgeDealStunFlat
        )
    }

    public func merge(_ other: CombatAffixReactionTriggers) {
        enemyStunnedPurgeCount += other.enemyStunnedPurgeCount
        enemyStunnedPurgeAll = enemyStunnedPurgeAll || other.enemyStunnedPurgeAll
        criticalPurgeCount += other.criticalPurgeCount
        criticalPurgeAll = criticalPurgeAll || other.criticalPurgeAll
        criticalGoldFlat += other.criticalGoldFlat
        leechRestoreManaFlat += other.leechRestoreManaFlat
        gainManaBlockFlat += other.gainManaBlockFlat
        defeatEnemyGoldFlat += other.defeatEnemyGoldFlat
        leechGoldFlat += other.leechGoldFlat
        dodgeHealFlat += other.dodgeHealFlat
        dodgeChanceBelowHealthPercentThreshold = max(
            dodgeChanceBelowHealthPercentThreshold,
            other.dodgeChanceBelowHealthPercentThreshold
        )
        dodgeChanceBelowHealthPercentBonus += other.dodgeChanceBelowHealthPercentBonus
        dodgeDealStunFlat += other.dodgeDealStunFlat
    }
}

extension CombatAffixReactionTriggers: Equatable {
    public static func == (lhs: CombatAffixReactionTriggers, rhs: CombatAffixReactionTriggers) -> Bool {
        lhs.enemyStunnedPurgeCount == rhs.enemyStunnedPurgeCount
            && lhs.enemyStunnedPurgeAll == rhs.enemyStunnedPurgeAll
            && lhs.criticalPurgeCount == rhs.criticalPurgeCount
            && lhs.criticalPurgeAll == rhs.criticalPurgeAll
            && lhs.criticalGoldFlat == rhs.criticalGoldFlat
            && lhs.leechRestoreManaFlat == rhs.leechRestoreManaFlat
            && lhs.gainManaBlockFlat == rhs.gainManaBlockFlat
            && lhs.defeatEnemyGoldFlat == rhs.defeatEnemyGoldFlat
            && lhs.leechGoldFlat == rhs.leechGoldFlat
            && lhs.dodgeHealFlat == rhs.dodgeHealFlat
            && lhs.dodgeChanceBelowHealthPercentThreshold == rhs.dodgeChanceBelowHealthPercentThreshold
            && lhs.dodgeChanceBelowHealthPercentBonus == rhs.dodgeChanceBelowHealthPercentBonus
            && lhs.dodgeDealStunFlat == rhs.dodgeDealStunFlat
    }
}

extension CombatAffixReactionTriggers: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(enemyStunnedPurgeCount)
        hasher.combine(enemyStunnedPurgeAll)
        hasher.combine(criticalPurgeCount)
        hasher.combine(criticalPurgeAll)
        hasher.combine(criticalGoldFlat)
        hasher.combine(leechRestoreManaFlat)
        hasher.combine(gainManaBlockFlat)
        hasher.combine(defeatEnemyGoldFlat)
        hasher.combine(leechGoldFlat)
        hasher.combine(dodgeHealFlat)
        hasher.combine(dodgeChanceBelowHealthPercentThreshold)
        hasher.combine(dodgeChanceBelowHealthPercentBonus)
        hasher.combine(dodgeDealStunFlat)
    }
}
