import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct DamageRampTests {
    @Test func `damage ramp grows each round up to cap`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.slash]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(dot: DotTriggers(
                    burnDamageRampPerRound: 1,
                    burnDamageRampCap: 4,
                )),
            ),
            dealOpeningHand: false,
        )
        for expected in [1, 2, 3, 4, 4] {
            _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
            let runtime = try #require(battle.roster.runtime(for: battle.roster.hero.combatant))
            #expect(runtime.keywordDamageRamp[.burn] == expected)
        }
        let companion = try #require(battle.roster.runtime(for: battle.roster.companion.combatant))
        #expect(companion.keywordDamageRamp[.burn, default: 0] == 0)
    }

    @Test func `damage ramp applies to matching keyword only`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.slash]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(dot: DotTriggers(
                    burnDamageRampPerRound: 1,
                    burnDamageRampCap: 4,
                )),
            ),
            dealOpeningHand: false,
        )
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(DamagePipeline.outgoingDamageBonus(
            for: battle.roster.hero.id,
            keyword: .burn,
            in: battle,
        ) == 1)
        #expect(DamagePipeline.outgoingDamageBonus(
            for: battle.roster.hero.id,
            keyword: .bleed,
            in: battle,
        ) == 0)
    }
}
