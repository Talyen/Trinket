import TrinketCore

struct CombatantTalentHistory: Hashable, Sendable {
    var spentMana = false
    var preparations: Set<TalentPreparation> = []
    var stolenGoldDamage = 0
    var blindingReduction = 0
    var dodgeGrowth = 0
}

struct HealingEcho: Hashable, Sendable {
    let amount: Int
    let sourceActorID: String
}

struct LingeringBlessing: Hashable, Sendable {
    let amount: Int
    let sourceActorID: String
    var turnsRemaining: Int
}

struct CombatantTalentState: Hashable, Sendable {
    struct Battle: Hashable, Sendable {
        var storedBlockedDamage = 0
        var actionDelays = 0
        var wasBelowHalfHealth = false
        var maximumHealthBonus = 0
        var damageBonus = 0
        var keywordDamageRamp: [Keyword: Int] = [:]
        var leechOverhealDamageBonus = 0
        var criticalMultiplierBonus = 0.0
        var negatedFirstEnemyAttack = false
        var interceptedFirstAllyFatalHit = false
        var hasEmpoweredWithMana = false
        var manaSpentTowardAutoPlay = 0
        var flatDamageReductionBonus = 0
    }

    struct Turn: Hashable, Sendable {
        var dodgeChanceBonus = 0.0
        var goldTheftDodgeApplied = false
        var cleansedKeywordProtection: Set<Keyword> = []
        var negativeStatusImmune = false
        var purgedEffectProtection: Set<EffectKind> = []
        var blockGainPrevented = false
        var subzeroMistActive = false
        var tookAttackHit = false
        var blockedFaeWard = false
        var triggeredBlockBreak = false
        var primedRepeatKeywords: Set<Keyword> = []
    }

    struct Pending: Hashable, Sendable {
        var nextDamageReduction = 0
        var healingEchoes: [HealingEcho] = []
        var damageAfterDodge = 0
        var doubleDamageAfterDodge = false
        var guaranteedCriticalAfterDodge = false
        var bleedAfterDodge = 0
        var cardDamageBonus = 0
        var feintStrikeDamageBonus = 0
        var cardDamagePercent = 0.0
        var overchargePercent: PreparedTalentBonus<Double>?
        var nextHitBonus = 0
        var nextAttackHolyBonus = 0
        var doubleNextHolyAttack = false
        var doubleNextPoisonAttack = false
        var doubleNextPoisonDamage = false
        var doubleNextBleedDamage = false
        var guaranteedBleedCritical: PreparedTalentBonus<Bool>?
        var doubleNextGoldSteal = false
        var nextPhysicalDamageBonus: PreparedTalentBonus<Int>?
        var nextAttackDamageBonus: PreparedTalentBonus<Int>?
        var nextHolyHitDouble: PreparedTalentBonus<Bool>?
        var nextStunAttackDouble: PreparedTalentBonus<Bool>?
        var nextBleedAttackMultiplier: PreparedTalentBonus<Double>?
        var nextPhysicalAttackMultiplier: PreparedTalentBonus<Double>?
        var nextCriticalHitMultiplier: PreparedTalentBonus<Double>?
        var nextManaEmpowerDiscount = 0
        var nextManaSpendAttackBonus: PreparedTalentBonus<Int>?
        var nextBlockGainMultiplier: PreparedTalentBonus<Double>?
        var nextFreezeIgnoresBlock: PreparedTalentBonus<Bool>?
        var nextAttackIgnoresBlock: PreparedTalentBonus<Bool>?
        var nextAttackMissChance = 0.0
        var nextAttackMissAbilityName: String?
        var nextOutgoingAttackMultiplier = 1.0
        var nextIncomingDamageMultiplier: PreparedTalentBonus<Double>?
        var doubleNextBleedAttack: PreparedTalentBonus<Bool>?
        var doubleNextAttackAfterDeathsDoor = false
        var nextBurnAttackPercent: PreparedTalentBonus<Double>?
        var doubleNextPhysicalAttack: PreparedTalentBonus<Bool>?
        var nextBleedDamageBonus: PreparedTalentBonus<Int>?
        var nextBurnDamageBonus: PreparedTalentBonus<Int>?
        var nextPoisonDamageBonus: PreparedTalentBonus<Int>?
        var nextToxicRemedyDamageBonus: PreparedTalentBonus<Int>?
        var nextDodgeStunAttackBonus: PreparedTalentBonus<Int>?
        var nextDodgeFreezeAttackBonus: PreparedTalentBonus<Int>?
        var nextDodgeBleedAttackBonus: PreparedTalentBonus<Int>?
        var nextPurgeHolyAttackBonus: PreparedTalentBonus<Int>?
        var nextLeechCriticalPoisonAttackBonus: PreparedTalentBonus<Int>?
        var manaOverflowThorns = 0
        var manaOverflowBlock = 0
        var nextAttackCriticalBonus: PreparedTalentBonus<Double>?
        var nextCleanseCriticalBonus: PreparedTalentBonus<Double>?
        var nextAttackGuaranteedCritical: PreparedTalentBonus<Bool>?
        var nextStunPreparedCritical: PreparedTalentBonus<Bool>?
        var basicGuaranteedCritical = false
        var basicCriticalBonus = 0.0
        var attackBonusOnFullHealth: PreparedTalentBonus<Int>?

        mutating func reserveAttackBonuses() -> (damage: Int, holy: Int) {
            let bonuses = (nextHitBonus, nextAttackHolyBonus)
            nextHitBonus = 0
            nextAttackHolyBonus = 0
            return bonuses
        }
    }

    struct ExpiringBonus: Hashable, Sendable {
        var amount = 0.0
        var expiresAtTurn = 0
    }

    struct Timed: Hashable, Sendable {
        var dodge = ExpiringBonus()
        var damage = ExpiringBonus()
        var lingeringBlessing: LingeringBlessing?
    }

    var history = CombatantTalentHistory()
    var battle = Battle()
    var turn = Turn()
    var pending = Pending()
    var timed = Timed()

    mutating func delayAction() {
        battle.actionDelays = SaturatedArithmetic.saturatingAdd(battle.actionDelays, 1)
    }

    mutating func grantDodgeUntilNextTurn(_ amount: Double) {
        turn.dodgeChanceBonus += amount
    }

    mutating func grantTimedDodge(_ amount: Double, untilTurn: Int) {
        timed.dodge.amount += amount
        timed.dodge.expiresAtTurn = max(timed.dodge.expiresAtTurn, untilTurn)
    }

    func dodgeChanceBonus(atTurn currentTurn: Int) -> Double {
        let timedAmount = timed.dodge.expiresAtTurn == 0 || currentTurn < timed.dodge.expiresAtTurn ? timed.dodge.amount : 0
        return turn.dodgeChanceBonus + timedAmount
    }

    mutating func beginTurn(_ currentTurn: Int) {
        turn = Turn()
        if timed.dodge.expiresAtTurn == 0 || currentTurn >= timed.dodge.expiresAtTurn {
            timed.dodge = ExpiringBonus()
        }
        if timed.damage.expiresAtTurn != 0, currentTurn >= timed.damage.expiresAtTurn {
            timed.damage = ExpiringBonus()
        }
    }
}
