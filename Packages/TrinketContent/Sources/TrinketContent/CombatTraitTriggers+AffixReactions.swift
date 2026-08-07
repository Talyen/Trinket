import Foundation
import TrinketCore

public extension CombatTraitTriggers {
    var enemyStunnedPurgeCount: Int {
        get { affixReactions?.enemyStunnedPurgeCount ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.enemyStunnedPurgeCount = newValue
        }
    }

    var enemyStunnedPurgeAll: Bool {
        get { affixReactions?.enemyStunnedPurgeAll ?? false }
        set {
            if affixReactions == nil, !newValue {
                return
            }
            ensureAffixReactions()
            affixReactions?.enemyStunnedPurgeAll = newValue
        }
    }

    var criticalPurgeCount: Int {
        get { affixReactions?.criticalPurgeCount ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.criticalPurgeCount = newValue
        }
    }

    var criticalPurgeAll: Bool {
        get { affixReactions?.criticalPurgeAll ?? false }
        set {
            if affixReactions == nil, !newValue {
                return
            }
            ensureAffixReactions()
            affixReactions?.criticalPurgeAll = newValue
        }
    }

    var criticalGoldFlat: Int {
        get { affixReactions?.criticalGoldFlat ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.criticalGoldFlat = newValue
        }
    }

    var leechRestoreManaFlat: Int {
        get { affixReactions?.leechRestoreManaFlat ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.leechRestoreManaFlat = newValue
        }
    }

    var gainManaBlockFlat: Int {
        get { affixReactions?.gainManaBlockFlat ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.gainManaBlockFlat = newValue
        }
    }

    var defeatEnemyGoldFlat: Int {
        get { affixReactions?.defeatEnemyGoldFlat ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.defeatEnemyGoldFlat = newValue
        }
    }

    var leechGoldFlat: Int {
        get { affixReactions?.leechGoldFlat ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.leechGoldFlat = newValue
        }
    }

    var dodgeHealFlat: Int {
        get { affixReactions?.dodgeHealFlat ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.dodgeHealFlat = newValue
        }
    }

    var dodgeChanceBelowHealthPercentThreshold: Double {
        get { affixReactions?.dodgeChanceBelowHealthPercentThreshold ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.dodgeChanceBelowHealthPercentThreshold = newValue
        }
    }

    var dodgeChanceBelowHealthPercentBonus: Double {
        get { affixReactions?.dodgeChanceBelowHealthPercentBonus ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.dodgeChanceBelowHealthPercentBonus = newValue
        }
    }

    var dodgeDealStunFlat: Int {
        get { affixReactions?.dodgeDealStunFlat ?? 0 }
        set {
            if affixReactions == nil, newValue == 0 {
                return
            }
            ensureAffixReactions()
            affixReactions?.dodgeDealStunFlat = newValue
        }
    }

    private mutating func ensureAffixReactions() {
        if affixReactions == nil {
            affixReactions = CombatAffixReactionTriggers()
        }
    }
}
