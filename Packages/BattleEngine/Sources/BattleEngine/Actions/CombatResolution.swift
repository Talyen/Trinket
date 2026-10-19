import TrinketCore

struct CombatResolution {
    var feedbackGroupID: Int?
    var isAdvancingEffects = false
    var naturalReactionPhase: NaturalReactionPhase?
    var pendingToxicShocks: [ToxicShockPayoff] = []
    var controlDepth = 0

    mutating func beginFeedbackGroup(eventID: Int) -> Int? {
        let previous = feedbackGroupID
        feedbackGroupID = previous ?? eventID
        return previous
    }

    enum Scope: Hashable {
        case damage, dot, dotMirror, draw, heroReaction, uniqueReaction, talentReaction, detonation, leechOverflowGold
    }

    typealias Claim = CombatActivationLedger.Claim
    typealias Cadence = CombatActivationLedger.Cadence

    private struct Action {
        let id: Int
        let cardID: Int?
        let context: BattleActionContext
        let origin: DamageOperation.AttackOrigin
        var outcome: ResolvedActionFacts?
        var talents: TalentActionFacts?
        var didCriticalHit = false
        var loadedStrikeDouble: Bool?
        var prismaticEdgeDidRoll = false
        var prismaticEdgeKeyword: Keyword?
    }

    private struct Card {
        var partyDamageBonus = 0
        var partnerAttackDamageBonus = 0
        var criticalAttackActorIDs: Set<String> = []
        var empoweredByMana = false
        let id: Int
        let actorID: String
        var outcome: ResolvedActionFacts?
        var talents: HeroTalentCardFacts?
    }

    private var depths: [Scope: Int] = [:]
    private var actions: [Action] = []
    private var automaticPlayDepth = 0
    private var nextActionID = 0
    private var nextStandaloneRestorationID = 0
    private(set) var standaloneRestorationID: Int?
    private var cards: [Card] = []
    private var partyCardDamageBySource: [String: Int] = [:]
    private var partyDamageByRecipient: [String: Int] = [:]
    private(set) var nextCardID = 0
    private var claims = CombatActivationLedger()

    mutating func beginStandaloneRestoration() -> Bool {
        guard currentAction == nil, cards.isEmpty, standaloneRestorationID == nil else { return false }
        standaloneRestorationID = nextStandaloneRestorationID
        nextStandaloneRestorationID += 1
        return true
    }

    mutating func endStandaloneRestoration() {
        guard let id = standaloneRestorationID else { preconditionFailure() }
        claims.finish(.standaloneRestoration(id))
        standaloneRestorationID = nil
    }

    var actionID: Int? {
        currentAction?.id
    }

    var actionContext: BattleActionContext? {
        currentAction?.context
    }

    var attackOrigin: DamageOperation.AttackOrigin {
        currentAction?.origin ?? .ability
    }

    private var currentAction: Action? {
        actions.last
    }

    var actionOutcome: ResolvedActionFacts? {
        currentAction?.outcome
    }

    func grantsBurnAttackLeech(to actorID: String) -> Bool {
        currentAction?.context.actor.id == actorID && currentAction?.talents?.burnAttackLeech == true
    }

    func isClaimed(_ claim: Claim, actorID: String, cadence: Cadence) -> Bool {
        claims.contains(claim, actorID: actorID, cadence: cadence)
    }

    mutating func recordCriticalAttack(by actorID: String) {
        guard let index = actions.indices.last, actions[index].context.actor.id == actorID else { return }
        actions[index].didCriticalHit = true
    }

    func hasCriticalHit(by actorID: String) -> Bool {
        if let action = currentAction {
            guard action.context.actor.id == actorID else {
                return false
            }
            if action.didCriticalHit {
                return true
            }
            guard action.cardID != nil else { return false }
        }
        return cardTalents?.actorID == actorID && cardTalents?.didCriticalHit == true
    }

    var isAutomaticPlay: Bool {
        automaticPlayDepth > 0 || actions.contains { $0.origin == .counterattack }
    }

    mutating func beginAutomaticPlay() {
        automaticPlayDepth += 1
    }

    mutating func endAutomaticPlay() {
        precondition(automaticPlayDepth > 0)
        automaticPlayDepth -= 1
    }

    func cardOutcome(for actorID: String) -> ResolvedActionFacts? {
        guard cards.last?.actorID == actorID else { return nil }
        return cards.last?.outcome
    }

    var cardTalents: HeroTalentCardFacts? {
        cards.last(where: { $0.talents != nil })?.talents
    }

    func pendingPartyCardDamage(from actorID: String) -> Int {
        partyCardDamageBySource[actorID, default: 0]
    }

    func pendingPartyDamage(for actorID: String) -> Int {
        partyDamageByRecipient[actorID, default: 0]
    }

    mutating func preparePartyCardDamage(_ amount: Int, sourceID: String) {
        partyCardDamageBySource[sourceID] = amount
    }

    mutating func preparePartyDamage(_ amount: Int, recipientID: String) {
        partyDamageByRecipient[recipientID] = amount
    }

    var hasPendingPartyCardDamage: Bool {
        !partyCardDamageBySource.isEmpty
    }

    mutating func reservePartyCardDamage(livingSourceIDs: [String]) -> Int {
        guard !partyCardDamageBySource.isEmpty else { return 0 }
        return livingSourceIDs.reduce(0) {
            SaturatedArithmetic.saturatingAdd($0, partyCardDamageBySource.removeValue(forKey: $1) ?? 0)
        }
    }

    mutating func beginCard(
        actorID: String,
        partyDamageBonus: Int = 0,
    ) -> Int {
        let id = nextCardID
        nextCardID += 1
        var talents = HeroTalentCardFacts(actorID: actorID)
        talents.playSerial = id
        cards.append(Card(
            partyDamageBonus: partyDamageBonus,
            id: id,
            actorID: actorID,
            talents: talents,
        ))
        return id
    }

    func damageProvenance(for actorID: String) -> DamageProvenance? {
        guard let action = currentAction, action.context.actor.id == actorID else { return nil }
        return DamageProvenance(actionID: action.id, cardID: action.cardID)
    }

    mutating func consumePartyCardDamage(from provenance: DamageProvenance?) -> Int {
        consumeCardBonus(\.partyDamageBonus, from: provenance)
    }

    mutating func consumePartyDamage(from provenance: DamageProvenance?) -> Int {
        consumeCardBonus(\.partnerAttackDamageBonus, from: provenance)
    }

    private mutating func consumeCardBonus(_ bonus: WritableKeyPath<Card, Int>, from provenance: DamageProvenance?) -> Int {
        guard let provenance, let cardID = provenance.cardID,
              let index = cards.indices.last, cards[index].id == cardID,
              currentAction?.id == provenance.actionID else { return 0 }
        let amount = cards[index][keyPath: bonus]
        cards[index][keyPath: bonus] = 0
        return amount
    }

    mutating func mutateCardTalents(_ body: (inout HeroTalentCardFacts) -> Void) {
        guard let index = cards.lastIndex(where: { $0.talents != nil }),
              var talents = cards[index].talents else { return }
        // Move the value out before mutation so its collections do not copy the stored value.
        cards[index].talents = nil
        body(&talents)
        cards[index].talents = talents
    }

    mutating func finishCardTalents() -> HeroTalentCardFacts? {
        guard let index = cards.lastIndex(where: { $0.talents != nil }) else { return nil }
        defer { cards[index].talents = nil }
        return cards[index].talents
    }

    mutating func prepareActionTalents(_ talents: TalentActionFacts) {
        precondition(actions.last?.talents == nil && actions.last?.context.actor.id == talents.actorID)
        actions[actions.count - 1].talents = talents
    }

    func actionTalents(for actorID: String) -> TalentActionFacts? {
        guard currentAction?.context.actor.id == actorID else { return nil }
        return currentAction?.talents
    }

    mutating func recordManaEmpowerment(by actorID: String, arcaneBurst: Bool) {
        guard currentAction?.talents?.actorID == actorID else { return }
        _ = mutateActionTalents(for: actorID) {
            $0.empoweredByMana = true
            $0.arcaneBurst = arcaneBurst
        }
        if let cardID = currentAction?.cardID,
           let index = cards.indices.last, cards[index].id == cardID {
            cards[index].empoweredByMana = true
        }
    }

    mutating func consumeCardEmpowerment(by actorID: String) -> Bool {
        guard let index = cards.indices.last, cards[index].actorID == actorID else { return false }
        defer { cards[index].empoweredByMana = false }
        return cards[index].empoweredByMana
    }

    mutating func consumeAttackReduction(for actorID: String?, damage: Int) -> Int {
        mutateActionTalents(for: actorID) { talents in
            let reduction = min(max(0, damage), talents.blindingReduction)
            talents.blindingReduction -= reduction
            return reduction
        } ?? 0
    }

    mutating func loadedStrikeDouble(for actorID: String, using rng: inout some RandomNumberGenerator) -> Bool {
        guard let index = actions.indices.last, actions[index].context.actor.id == actorID else {
            return BattleChance.succeeds(probability: 0.20, using: &rng)
        }
        if let stored = actions[index].loadedStrikeDouble {
            return stored
        }
        let doubled = BattleChance.succeeds(probability: 0.20, using: &rng)
        actions[index].loadedStrikeDouble = doubled
        return doubled
    }

    mutating func prismaticEdgeKeyword(for actorID: String, using rng: inout some RandomNumberGenerator) -> Keyword? {
        let index = actions.indices.last.flatMap { actions[$0].context.actor.id == actorID ? $0 : nil }
        if let index, actions[index].prismaticEdgeDidRoll {
            return actions[index].prismaticEdgeKeyword
        }
        let keyword: Keyword? = if BattleChance.succeeds(probability: 0.10, using: &rng) {
            Bool.random(using: &rng) ? .freeze : .burn
        } else {
            nil
        }
        if let index {
            actions[index].prismaticEdgeDidRoll = true
            actions[index].prismaticEdgeKeyword = keyword
        }
        return keyword
    }

    mutating func consumeGoldDamage(for actorID: String?) -> Int {
        mutateActionTalents(for: actorID) { talents in
            defer { talents.goldDamage = 0 }
            return talents.goldDamage
        } ?? 0
    }

    private mutating func mutateActionTalents<Value>(
        for actorID: String?,
        _ body: (inout TalentActionFacts) -> Value,
    ) -> Value? {
        guard let index = actions.lastIndex(where: { $0.talents != nil }),
              var talents = actions[index].talents, talents.actorID == actorID else { return nil }
        actions[index].talents = nil
        let value = body(&talents)
        actions[index].talents = talents
        return value
    }

    mutating func prepareAction(_ facts: ResolvedActionFacts) -> Bool {
        precondition(!actions.isEmpty)
        actions[actions.count - 1].outcome = facts
        guard cards.last?.actorID == facts.action.actor.id, cards.last?.outcome == nil,
              facts.origin == .card || facts.origin == .ordinaryCard else { return false }
        cards[cards.count - 1].outcome = facts
        if !facts.damageKeywords.isEmpty {
            cards[cards.count - 1].partnerAttackDamageBonus = partyDamageByRecipient.removeValue(forKey: facts.action.actor.id) ?? 0
        }
        return true
    }

    func depth(_ scope: Scope) -> Int {
        depths[scope, default: 0]
    }

    mutating func enter(_ scope: Scope) {
        depths[scope, default: 0] += 1
    }

    mutating func leave(_ scope: Scope) {
        precondition(depth(scope) > 0)
        depths[scope, default: 0] -= 1
    }

    @discardableResult
    mutating func beginAction(_ context: BattleActionContext, origin: DamageOperation.AttackOrigin) -> Int {
        let cardID: Int? = switch origin {
        case .card, .ordinaryCard, .cardRepeat:
            cards.last?.actorID == context.actor.id ? cards.last?.id : nil
        default: nil
        }
        actions.append(Action(id: nextActionID, cardID: cardID, context: context, origin: origin))
        nextActionID += 1
        return nextActionID - 1
    }

    mutating func endAction() {
        let action = actions.removeLast()
        claims.finish(.action(action.id))
    }

    /// Include nested attacks in their enclosing plays, without treating critical
    /// healing or display decorators as attacks.
    mutating func recordCardAttackCritical(by actorID: String) {
        for index in cards.indices {
            cards[index].criticalAttackActorIDs.insert(actorID)
        }
    }

    func criticalAttackActorIDs(forCard id: Int) -> Set<String> {
        precondition(cards.last?.id == id)
        return cards.last?.criticalAttackActorIDs ?? []
    }

    mutating func endCard(_ id: Int) {
        precondition(cards.last?.id == id)
        cards.removeLast()
        claims.finish(.card(id))
    }

    mutating func claim(_ claim: Claim, actorID: String, cadence: Cadence) -> Bool {
        claims.claim(claim, actorID: actorID, cadence: cadence)
    }
}

enum CombatResolver {
    static func damage(_ request: DamageRequest, in context: inout BattleState) async -> CombatOutcome {
        guard request.amount > 0, context.roster.health(for: request.target) > 0 else { return .empty }
        guard context.resolution.depth(.damage) < ReactionScope.maxDepth else {
            ReactionScope.capHit(site: "damage", depth: context.resolution.depth(.damage))
            return .empty
        }
        await CombatExecutor.suspend()
        context.resolution.enter(.damage)
        var state = DamageResolutionState(
            amount: request.amount, combatant: request.target, sourceActorID: request.sourceActorID,
            damageKeyword: request.keyword, options: request.options,
        )
        state.provenance = request.provenance
        state.elementalHit = ElementalReactionEngine.capture(request, in: context)
        await DamagePipeline.run(state: &state, in: &context)
        var outcome = CombatOutcome.fromDamage(state: state)
        outcome.elementalHit = state.elementalHit
        // Recording is scoped to a resolved action, including its immediate DoT pulses.
        if !request.options.isHealthCost, let impact = outcome.damageImpact {
            context.commandOutput?.recordDamage(BattleResolvedDamage(
                targetID: request.target.id, keyword: request.keyword ?? .physical, impact: impact, isCritical: outcome.isCritical,
            ))
        }
        context.resolution.leave(.damage)
        // Preserve the post-damage timing of counter Basics and Block answers.
        // During this drain, reactions only enqueue; the outer loop then visits
        // both queues again. No-op attacks are removed too, so none strand.
        if context.resolution.depth(.damage) == 0, !context.uniques.isDrainingOutOfTurnAttacks {
            context.uniques.isDrainingOutOfTurnAttacks = true
            while !context.uniques.pendingCounterAttacks.isEmpty
                || !context.uniques.pendingBlockAnswerOwners.isEmpty {
                await CombatTriggerEngine.drainPendingCounterAttacks(in: &context)
                await UniqueCombatEngine.drainPendingBlockAnswers(in: &context)
            }
            context.uniques.isDrainingOutOfTurnAttacks = false
            await ElementalReactionEngine.finishControl(in: &context)
        }
        if !request.options.defersElementalPayoff, let hit = state.elementalHit {
            let captured = ElementalReactionEngine.captureAttachment(hit, outcome: outcome, in: &context)
            await ElementalReactionEngine.finish(captured, outcome: outcome, in: &context)
        }
        return outcome
    }
}
