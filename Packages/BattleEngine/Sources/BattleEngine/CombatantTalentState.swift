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
        var maximumHealthBonus = 0
        var damageBonus = 0
        var keywordDamageRamp: [Keyword: Int] = [:]
        var leechOverhealDamageBonus = 0
        var totalBlockGained = 0
        var criticalMultiplierBonus = 0.0
        var negatedFirstEnemyAttack = false
        var hasEmpoweredWithMana = false
        var manaSpentTowardAutoPlay = 0
        var flatDamageReductionBonus = 0
    }

    struct Turn: Hashable, Sendable {
        var cleansedKeywordProtection: Set<Keyword> = []
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
        var nextHitBonus = 0
        var nextAttackHolyBonus = 0
        var basicGuaranteedCritical = false
        var basicCriticalBonus = 0.0
        var attackBonusOnFullHealth = 0
        var doubleStatusNextCard = false

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

    struct Card: Hashable, Sendable {
        var goldenTouchActive = false
    }

    struct Action: Hashable, Sendable {
        var empoweredByMana = false
    }

    var battle = Battle()
    var turn = Turn()
    var pending = Pending()
    var timed = Timed()
    var card = Card()
    var action = Action()

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

    mutating func finishCard() {
        card = Card()
    }

    mutating func consumeActionEmpowerment() -> Bool {
        defer { action.empoweredByMana = false }
        return action.empoweredByMana
    }
}
