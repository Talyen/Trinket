import TrinketCore

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
        var subzeroMistActive = false
        var tookAttackHit = false
        var blockedFaeWard = false
        var triggeredBlockBreak = false
    }

    struct Pending: Hashable, Sendable {
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
        var guaranteedBleedCritical = false
        var doubleNextGoldSteal = false
        var nextPhysicalDamageBonus = 0
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
        var nextBleedDamageBonus = 0
        var nextBurnDamageBonus: PreparedTalentBonus<Int>?
        var nextPoisonDamageBonus: PreparedTalentBonus<Int>?
        var manaOverflowThorns = 0
        var manaOverflowBlock = 0
        var nextAttackCriticalBonus: PreparedTalentBonus<Double>?
        var nextCleanseCriticalBonus: PreparedTalentBonus<Double>?
        var nextAttackGuaranteedCritical: PreparedTalentBonus<Bool>?
        var nextStunPreparedCritical: PreparedTalentBonus<Bool>?
        var basicGuaranteedCritical = false
        var basicCriticalBonus = 0.0
        var attackBonusOnFullHealth = 0

        mutating func reserveAttackBonuses() -> (damage: Int, holy: Int) {
            let bonuses = (nextHitBonus + attackBonusOnFullHealth, nextAttackHolyBonus)
            nextHitBonus = 0
            attackBonusOnFullHealth = 0
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

    struct Action: Hashable, Sendable {
        var empoweredByMana = false
        var arcaneBurst = false
    }

    var battle = Battle()
    var turn = Turn()
    var pending = Pending()
    var timed = Timed()
    var action = Action()

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

    mutating func beginAction() {
        action = Action()
    }

    mutating func consumeActionEmpowerment() -> Bool {
        defer { action.empoweredByMana = false }
        return action.empoweredByMana
    }
}
