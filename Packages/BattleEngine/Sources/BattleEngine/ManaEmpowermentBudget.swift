import TrinketContent
import TrinketCore

struct ManaEmpowermentBudget {
    struct Payment {
        let ownMana: Int
        let partnerMana: Int
        let block: Int
        let rimeglassAllyFreezeCount: Int
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
    private var preparedDiscount: Int
    private var rimeglassAllyFreezeCount: Int

    init(ability: Ability, actor: Combatant, in context: BattleState, blockOverride: Int? = nil) {
        self.init(
            keywords: ability.keywords, hasBurnDamage: ability.hasManaEmpowerableBurnDamage,
            repeatsManaEmpowerment: ability.repeatsManaEmpowerment,
            actor: actor, in: context, blockOverride: blockOverride,
        )
    }

    init(
        keywords: [Keyword], hasBurnDamage: Bool, repeatsManaEmpowerment: Bool,
        actor: Combatant, in context: BattleState, blockOverride: Int? = nil,
    ) {
        let runtime = context.roster.runtime(for: actor)
        let triggers = context.modifiers(for: actor.id).triggers
        let hasFreeze = keywords.contains(.freeze)
        rimeglassAllyFreezeCount = Self.rimeglassReadiness(
            hasFreeze: hasFreeze, equipped: triggers.allyFreezeCardDiscountsNextFreeze, actor: actor, in: context,
        )
        func isPatron(_ candidate: CombatantRuntime) -> Bool {
            candidate.id != actor.id && candidate.isAlive && context.modifiers(for: candidate.id).triggers.dragonPatronage
        }
        let patron: CombatantRuntime? = if hasFreeze, actor.role != .enemy, isPatron(context.roster.hero) {
            context.roster.hero
        } else if hasFreeze, actor.role != .enemy, isPatron(context.roster.companion) {
            context.roster.companion
        } else {
            nil
        }
        partner = patron?.combatant
        ownMana = runtime?.currentMana ?? 0
        partnerMana = patron?.currentMana ?? 0
        blockRate = hasFreeze ? triggers.freezeEmpowermentBlockPerMana : 0
        block = blockRate > 0 ? (blockOverride ?? (runtime.map { DefensePoolEngine.blockPoints(in: $0.activeEffects) } ?? 0)) : 0
        hasEmpowered = runtime?.talents.battle.hasEmpoweredWithMana ?? false
        firstDiscount = triggers.firstEmpowermentCostReduction
        let reduction = keywords.contains(.health) && triggers.healingEmpowermentCostReduction > 0
            ? triggers.healingEmpowermentCostReduction : triggers.empowermentCostReduction
        let burnReduction = hasBurnDamage ? triggers.empowerBurnCostReduction : 0
        preparedDiscount = max(0, runtime?.talents.pending.nextManaEmpowerDiscount ?? 0)
        baseCost = max(
            0,
            SaturatedArithmetic.saturatingSub(
                SaturatedArithmetic.saturatingSub(BattleTurnEngine.manaEmpowermentCost, max(0, reduction)),
                max(0, burnReduction),
            ),
        )
        let maxMana = SaturatedArithmetic.saturatingAdd(runtime?.maxMana ?? 0, patron?.maxMana ?? 0)
        hasCapacity = maxMana > 0 || blockRate > 0
        let repeats = repeatsManaEmpowerment
            || (hasBurnDamage && triggers.repeatManaEmpowerment)
        let hasDiscount = preparedDiscount > 0 || (!hasEmpowered && firstDiscount > 0) || rimeglassAllyFreezeCount > 0
        let discountPurchase = hasDiscount ? 1 : 0
        let capacity = SaturatedArithmetic.saturatingAdd(maxMana, blockRate > 0 ? block / blockRate : 0)
        purchaseLimit = repeats && baseCost > 0
            ? max(1, SaturatedArithmetic.saturatingAdd(capacity / baseCost, discountPurchase)) : 1
    }

    private static func rimeglassReadiness(
        hasFreeze: Bool, equipped: Bool, actor: Combatant, in context: BattleState,
    ) -> Int {
        guard hasFreeze, equipped, actor.role != .enemy else { return 0 }
        let ally: BattleParticipant = actor.role == .hero ? .companion : .hero
        let count = context.turnCadence.freezeCardsPlayed[ally, default: 0]
        let used = context.roster.runtime(for: actor)?.talents.turn.rimeglassUsedAllyFreezeCount ?? 0
        return count > used ? count : 0
    }

    mutating func nextPayment() -> Payment? {
        guard hasCapacity else { return nil }
        let talentDiscount = SaturatedArithmetic.saturatingAdd(preparedDiscount, hasEmpowered ? 0 : firstDiscount)
        let discount = SaturatedArithmetic.saturatingAdd(talentDiscount, rimeglassAllyFreezeCount > 0 ? 1 : 0)
        let cost = max(0, SaturatedArithmetic.saturatingSub(baseCost, discount))
        let own = min(cost, ownMana)
        let shared = min(cost - own, partnerMana)
        let shortfall = cost - own - shared
        if shortfall > 0 {
            guard blockRate > 0, shortfall <= block / blockRate else { return nil }
        }
        let blockCost = shortfall > 0 ? shortfall * blockRate : 0
        ownMana -= own
        partnerMana -= shared
        block -= blockCost
        hasEmpowered = true
        preparedDiscount = 0
        let usedAllyFreezeCount = rimeglassAllyFreezeCount
        rimeglassAllyFreezeCount = 0
        return Payment(ownMana: own, partnerMana: shared, block: blockCost, rimeglassAllyFreezeCount: usedAllyFreezeCount)
    }

    /// Inspection has no spending reactions. Pay the discounted first purchase,
    /// then quote the identical remaining purchases without iterating over Mana.
    mutating func totalPayment() -> Payment? {
        guard let first = nextPayment() else { return nil }
        guard baseCost > 0, purchaseLimit > 1 else { return first }
        let available = SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingAdd(ownMana, partnerMana),
            blockRate > 0 ? block / blockRate : 0,
        )
        let purchases = min(purchaseLimit - 1, available / baseCost)
        // The original purchase limit bounds this product by the capped capacity.
        let cost = purchases * baseCost
        let own = min(cost, ownMana)
        let shared = min(cost - own, partnerMana)
        let blockCost = (cost - own - shared) * blockRate
        ownMana -= own
        partnerMana -= shared
        block -= blockCost
        return Payment(
            ownMana: first.ownMana + own,
            partnerMana: first.partnerMana + shared,
            block: first.block + blockCost,
            rimeglassAllyFreezeCount: first.rimeglassAllyFreezeCount,
        )
    }
}
