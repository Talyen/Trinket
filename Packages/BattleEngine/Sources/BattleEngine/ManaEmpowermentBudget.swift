import TrinketContent
import TrinketCore

struct ManaEmpowermentBudget {
    struct Payment {
        let ownMana: Int
        let partnerMana: Int
        let block: Int
    }

    let partner: Combatant?
    let purchaseLimit: Int
    private let baseCost: Int
    private let firstDiscount: Int
    private let blockRate: Int
    private let hasCapacity: Bool
    private(set) var ownMana: Int
    private(set) var partnerMana: Int
    private var block: Int
    private var hasEmpowered: Bool

    init(ability: Ability, actor: Combatant, in context: BattleState) {
        let runtime = context.roster.runtime(for: actor)
        let triggers = context.modifiers(for: actor.id).triggers
        let patron = ability.keywords.contains(.freeze) && actor.role != .enemy
            ? [context.roster.hero, context.roster.companion].first {
                $0.id != actor.id && $0.isAlive && context.modifiers(for: $0.id).triggers.dragonPatronage
            } : nil
        partner = patron?.combatant
        ownMana = runtime?.currentMana ?? 0
        partnerMana = patron?.currentMana ?? 0
        block = runtime.map { DefensePoolEngine.blockPoints(in: $0.activeEffects) } ?? 0
        blockRate = ability.keywords.contains(.freeze) ? triggers.freezeEmpowermentBlockPerMana : 0
        hasEmpowered = runtime?.hasEmpoweredWithMana ?? false
        firstDiscount = triggers.firstEmpowermentCostReduction
        let reduction = ability.keywords.contains(.health) && triggers.healingEmpowermentCostReduction > 0
            ? triggers.healingEmpowermentCostReduction : triggers.empowermentCostReduction
        baseCost = max(0, BattleTurnEngine.manaEmpowermentCost - max(0, reduction))
        let maxMana = (runtime?.maxMana ?? 0) + (patron?.maxMana ?? 0)
        hasCapacity = maxMana > 0
        let repeats = ability.repeatsManaEmpowerment
            || (ability.hasManaEmpowerableBurnDamage && triggers.repeatManaEmpowerment)
        let discountPurchase = !hasEmpowered && firstDiscount > 0 ? 1 : 0
        purchaseLimit = repeats && baseCost > 0 ? max(1, maxMana / baseCost + discountPurchase) : 1
    }

    mutating func nextPayment() -> Payment? {
        guard hasCapacity else { return nil }
        let cost = max(0, baseCost - (hasEmpowered ? 0 : firstDiscount))
        let own = min(cost, ownMana)
        let shared = min(cost - own, partnerMana)
        let shortfall = cost - own - shared
        guard shortfall == 0 || blockRate > 0 else { return nil }
        let blockCost = shortfall * blockRate
        guard block >= blockCost else { return nil }
        ownMana -= own
        partnerMana -= shared
        block -= blockCost
        hasEmpowered = true
        return Payment(ownMana: own, partnerMana: shared, block: blockCost)
    }
}
