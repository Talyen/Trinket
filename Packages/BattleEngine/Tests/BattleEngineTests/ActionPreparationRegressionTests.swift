import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct ActionPreparationRegressionTests {
    @Test(arguments: [false, true])
    func `Heat Recovery strengthens a later Burn attack after cleansing`(card: Bool) throws {
        let ability = Ability(
            id: "cleanse-then-burn", name: "Cleanse Then Burn", tier: .basic,
            operations: [
                .effect(TargetedEffect(.cleanse(.burn), target: .actor)),
                .damage(DamageComponent(3, keyword: .burn)),
            ],
            criticalChanceBonus: -1,
        )
        var profile = CombatantTalentCatalog.profile(for: ["alchemist_cleanse_t2_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroModifiers: profile, dealOpeningHand: false)
        battle.appliesFightPacing = false
        battle.appendEffect(.burn(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)

        if card {
            let drawn = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
            _ = try battle.playCard(cardID: drawn.id)
        } else {
            _ = BattleTurnEngine.performAction(
                ability: ability, actor: battle.hero, abilityTarget: battle.enemy,
                origin: .counterattack, context: &battle,
            )
        }
        #expect(battle.health(of: battle.enemy) == 97)
        #expect(!battle.roster.hasAffliction(.burn, on: battle.hero))
        #expect(battle.roster.hero.talents.pending.nextBurnDamageBonus?.value == 2)

        _ = BattleTurnEngine.performAction(
            ability: .fireArrow, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(battle.health(of: battle.enemy) == 93)
        #expect(battle.roster.hero.talents.pending.nextBurnDamageBonus == nil)
        _ = BattleTurnEngine.performAction(
            ability: .fireArrow, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(battle.health(of: battle.enemy) == 91)
    }

    @Test func `Sanctified Scroll saves its Critical chance for a later action`() {
        let ability = Ability(
            id: "cleanse-then-hit", name: "Cleanse Then Hit", tier: .basic,
            operations: [
                .effect(TargetedEffect(.cleanse(.burn), target: .actor)),
                .damage(DamageComponent(4, keyword: .physical)),
            ],
        )
        var profile = CombatantTalentCatalog.profile(for: ["library_owl_cleanse_t3_2"])
        profile.triggers.criticalChanceBonus = -0.1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(companionModifiers: profile, dealOpeningHand: false)
        battle.appliesFightPacing = false
        battle.appendEffect(.burn(2), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 0)
        let before = battle.rng

        _ = BattleTurnEngine.performAction(
            ability: ability, actor: battle.companion, abilityTarget: battle.enemy,
            origin: .counterattack, context: &battle,
        )
        #expect(battle.health(of: battle.enemy) == 96)
        #expect(battle.rng == before)
        #expect(battle.roster.companion.talents.pending.nextCleanseCriticalBonus?.value == 0.2)

        _ = BattleTurnEngine.performAction(
            ability: .slash, actor: battle.companion, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(battle.rng != before)
        #expect(battle.roster.companion.talents.pending.nextCleanseCriticalBonus == nil)
    }

    @Test func `Aftershock Guard doubles a later Block gain after stunning`() {
        let ability = Ability(
            id: "stun-then-block", name: "Stun Then Block", tier: .basic,
            operations: [
                .damage(DamageComponent(1, keyword: .stun)),
                .effect(TargetedEffect(.shield(.block, 3), target: .actor)),
            ],
            criticalChanceBonus: -1,
        )
        var profile = CombatantTalentCatalog.profile(for: ["bear_block_t4_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(companionModifiers: profile, dealOpeningHand: false)
        battle.appliesFightPacing = false
        let threshold = ControlMeterEngine.threshold(for: battle.enemy, in: battle)
        battle.appendEffect(
            .controlMeter(.stun, threshold - 1, threshold), to: battle.enemy,
            sourceID: battle.companion.id, remainingTurns: 0,
        )

        _ = BattleTurnEngine.performAction(
            ability: ability, actor: battle.companion, abilityTarget: battle.enemy,
            origin: .counterattack, context: &battle,
        )
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun))
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 3)
        #expect(battle.roster.companion.talents.pending.nextBlockGainMultiplier?.value == 2)

        _ = BattleTurnEngine.performAction(
            ability: .block, actor: battle.companion, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 9)
        #expect(battle.roster.companion.talents.pending.nextBlockGainMultiplier == nil)
        _ = BattleTurnEngine.performAction(
            ability: .block, actor: battle.companion, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 12)
    }
}
