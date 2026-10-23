import TrinketContent
import TrinketCore

extension EffectApplication {
    static func aegisEffects(block: Int, holyDamage: Int) -> [Effect] {
        [.shield(.block, block), .onHitDamage(.holy, holyDamage)]
    }

    static let panaceaHealTarget: EffectTarget = .lowestHealthAlly

    static func panaceaCleanseTarget(action: BattleActionContext, in context: BattleState) -> Combatant {
        BattleActionContext.mostDebuffed(in: action.allies(in: context), state: context)
    }

    /// This draw recipient is chosen at application, after preceding hits and reactions.
    static func selectsDrawPartner(abilityID: String) -> Bool {
        abilityID == Ability.packTactics.id
    }

    func drawRecipient(in context: BattleState) -> Combatant {
        guard Self.selectsDrawPartner(abilityID: ability.id),
              let owner = context.roster.participant(for: source), owner.isPartyMember else { return target }
        let partner: BattleParticipant = owner == .hero ? .companion : .hero
        return BattleCardCombatEngine.canDrawFromDeck(for: partner, in: context)
            && !BattleCardCombatEngine.isDeckEmpty(for: partner, in: context)
            ? context.roster[partner].combatant : source
    }
}
