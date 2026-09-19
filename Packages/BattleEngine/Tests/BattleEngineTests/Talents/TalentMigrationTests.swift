import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct TalentMigrationTests {
    func makeBattle(
        heroTriggers: CombatTraitTriggers = CombatTraitTriggers(),
        companionTriggers: CombatTraitTriggers = CombatTraitTriggers(),
        heroAbilities: [Ability] = [.slash],
        initialGold: Int = 0,
        seed: UInt64 = CombatantFixtures.deterministicBattleSeed,
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: heroAbilities,
            companionAbilities: [.bash],
            enemyMaxHealth: 100,
            heroMaxMana: 12,
            heroMana: 5,
            companionMaxMana: 12,
            initialGold: initialGold,
            heroModifiers: CombatModifierProfile(triggers: heroTriggers),
            companionModifiers: CombatModifierProfile(triggers: companionTriggers),
            rngSeed: seed,
            tracksLog: false,
            dealOpeningHand: false,
        )
    }

    func cardReactions(_ ability: Ability, in context: inout BattleState) -> [ActionEvent] {
        let resolved = BattleAbilityRules.resolveOutcome(ability, actor: context.hero, in: &context)
        let facts = ResolvedActionFacts(
            original: ability, resolved: resolved, action: BattleActionContext(actor: context.hero, in: context),
            origin: .card, in: context,
        )
        return CombatTriggerEngine.afterCardPlayed(facts, in: &context)
    }
}
