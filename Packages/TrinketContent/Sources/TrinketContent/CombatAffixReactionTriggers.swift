import Foundation
import TrinketCore

/// Struct representing affix reaction triggers.
public struct CombatAffixReactionTriggers: Sendable, Equatable, Hashable {
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

    public mutating func merge(_ other: Self) {
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
