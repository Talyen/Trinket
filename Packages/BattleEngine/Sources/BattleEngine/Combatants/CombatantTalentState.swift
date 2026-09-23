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
        var cardDamagePercent = 0.0
        var overchargePercent = 0.0
        var overchargePreparedCardSerial: Int?
        var nextHitBonus = 0
        var nextAttackHolyBonus = 0
        var doubleNextHolyAttack = false
        var doubleNextPoisonAttack = false
        var doubleNextPoisonDamage = false
        var doubleNextBleedDamage = false
        var guaranteedBleedCritical = false
        var doubleNextGoldSteal = false
        var nextPhysicalDamageBonus = 0
        var nextHolyHitDouble = false
        var nextHolyHitPreparedCardSerial: Int?
        var nextStunAttackDouble = false
        var nextStunAttackPreparedCardSerial: Int?
        var nextBleedAttackMultiplier = 1.0
        var nextBleedMultiplierPreparedCardSerial: Int?
        var nextPhysicalAttackMultiplier = 1.0
        var nextPhysicalAttackPreparedCardSerial: Int?
        var nextCriticalHitMultiplier = 1.0
        var nextCriticalHitPreparedCardSerial: Int?
        var nextManaEmpowerDiscount = 0
        var nextManaSpendAttackBonus = 0
        var nextManaSpendAttackPreparedCardSerial: Int?
        var nextManaSpendAttackPreparedActionID: Int?
        var nextBlockGainMultiplier = 1.0
        var nextBlockGainPreparedCardSerial: Int?
        var nextFreezeIgnoresBlock = false
        var nextFreezeIgnorePreparedCardSerial: Int?
        var nextAttackIgnoresBlock = false
        var nextAttackIgnorePreparedCardSerial: Int?
        var nextAttackMissChance = 0.0
        var nextAttackMissAbilityName: String?
        var nextOutgoingAttackMultiplier = 1.0
        var nextIncomingDamageMultiplier = 1.0
        var nextIncomingDamagePreparedCardSerial: Int?
        var doubleNextBleedAttack = false
        var nextBleedAttackPreparedCardSerial: Int?
        var doubleNextAttackAfterDeathsDoor = false
        var nextBurnAttackPercent = 0.0
        var nextBurnAttackPreparedCardSerial: Int?
        var doubleNextPhysicalAttack = false
        var nextPhysicalPreparedCardSerial: Int?
        var nextBleedDamageBonus = 0
        var nextBurnDamageBonus = 0
        var nextBurnDamagePreparedCardSerial: Int?
        var nextPoisonDamageBonus = 0
        var manaOverflowThorns = 0
        var manaOverflowBlock = 0
        var nextAttackCriticalBonus = 0.0
        var nextAttackCriticalPreparedCardSerial: Int?
        var nextAttackCriticalPreparedActionID: Int?
        var nextCleanseCriticalBonus = 0.0
        var nextCleanseCriticalPreparedCardSerial: Int?
        var nextAttackGuaranteedCritical = false
        var nextStunPreparedCritical = false
        var nextStunCriticalPreparedCardSerial: Int?
        var nextStunCriticalPreparedActionID: Int?
        var basicGuaranteedCritical = false
        var basicCriticalBonus = 0.0
        var attackBonusOnFullHealth = 0

        static func isLaterAbility(preparedCardSerial: Int?, currentCardSerial: Int?) -> Bool {
            preparedCardSerial == nil || preparedCardSerial != currentCardSerial
        }

        static func isLaterAction(preparedActionID: Int?, currentActionID: Int?) -> Bool {
            preparedActionID == nil || preparedActionID != currentActionID
        }

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
