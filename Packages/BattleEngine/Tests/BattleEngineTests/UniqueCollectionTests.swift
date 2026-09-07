import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct UniqueCollectionTests {
    func battle(
        _ ids: [String],
        owner: BattleParticipant = .hero,
        extra: CombatModifierProfile = .zero,
        enemyExtra: CombatModifierProfile = .zero,
        other: CombatModifierProfile = .zero,
        heroBasic: Ability = .slash,
        companionBasic: Ability = .fangs,
    ) throws -> BattleState {
        var profile = extra
        for id in ids {
            let item = try #require(GameContent.unique(matching: id))
            let signature = try #require(item.affixPowers?.first)
            profile.merge(signature.modifiers)
            signature.triggers.apply(to: &profile)
        }
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 200, maxMana: 12, abilities: [heroBasic]),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 200, maxMana: 12, abilities: [companionBasic]),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 2000),
            heroMana: 0,
            companionMana: 0,
            heroModifiers: owner == .hero ? profile : other,
            companionModifiers: owner == .companion ? profile : other,
            enemyModifiers: enemyExtra,
        )
        context.appliesFightPacing = false
        return context
    }

    func attack(_ keyword: Keyword = .physical, amount: Int = 10, id: String = "strike") -> Ability {
        Ability(id: id, name: id, tier: .basic, directDamage: amount, damageKeyword: keyword, criticalChanceBonus: -1)
    }

    @discardableResult
    func play(
        _ ability: Ability,
        owner: BattleParticipant = .hero,
        critical: Bool = false,
        in context: inout BattleState,
    ) throws -> [ActionEvent] {
        if critical {
            let actor = context.roster[owner].combatant
            context.appendEffect(.nextStrikeCritical, to: actor, sourceID: actor.id, remainingTurns: 0)
        }
        let card = BattleCardCombatEngine.deal(ability, owner: owner, context: &context)
        return try BattleCardCombatEngine.playDrawnCard(card, context: &context)
    }

    func block(_ amount: Int, owner: BattleParticipant, in context: inout BattleState) {
        DefensePoolEngine.set(amount, on: context.roster[owner].combatant, in: &context)
    }

    func blockAmount(_ owner: BattleParticipant, in context: BattleState) -> Int {
        DefensePoolEngine.blockPoints(in: context.roster[owner].activeEffects)
    }

    func enemyHit(_ amount: Int, target: BattleParticipant = .hero, in context: inout BattleState) -> CombatOutcome {
        context.resolveDamage(DamageRequest(
            amount: amount,
            target: context.roster[target].combatant,
            keyword: .physical,
            sourceActorID: context.roster.enemy.id,
            options: DamageOptions(applyDodge: false, isAttackHit: true),
        ))
    }
}
