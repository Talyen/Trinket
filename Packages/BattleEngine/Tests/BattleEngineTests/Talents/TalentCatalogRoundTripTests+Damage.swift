import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `golden opportunity limits multiple gains and empty decks`() {
        var battle = heroTalentBattle("fox_gold_t2_1")
        battle.heroDeck = CombatDeck(abilities: [.slash, .stab, .bash])
        for amount in [4, 5, 10] {
            let events = battle.grantGoldEvent(amount, to: battle.hero, abilityName: "Gold")
            #expect(events.contains { $0.effectKind == .cardsDrawn } == (amount == 5))
        }
        battle.turnCount += 1
        let renewed = battle.grantGoldEvent(5, to: battle.hero, abilityName: "Gold")
        #expect(renewed.contains { $0.effectKind == .cardsDrawn })
        battle.turnCount += 1
        battle.heroDeck = CombatDeck(abilities: [])
        _ = battle.grantGoldEvent(5, to: battle.hero, abilityName: "Gold")
        battle.heroDeck = CombatDeck(abilities: [.slash])
        let spent = battle.grantGoldEvent(5, to: battle.hero, abilityName: "Gold")
        #expect(!spent.contains { $0.effectKind == .cardsDrawn })
    }

    @Test(arguments: ["risen_skeleton_leech_t1_2", "risen_skeleton_leech_t3_2"])
    func `leech talents deal immediate damage and leave their status`(talentID: String) {
        var battle = BattleTestFixtures.makePipelineContext(
            companionModifiers: CombatantTalentCatalog.profile(for: [talentID]),
        )
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        let before = battle.roster.enemy.currentHealth
        _ = HealingEngine.leechFromDamage(
            4, sourceActorID: battle.companion.id, target: battle.enemy,
            abilityHasLeech: true, damageKeyword: .physical, in: &battle,
        )
        let keyword: Keyword = talentID == "risen_skeleton_leech_t1_2" ? .poison : .bleed
        #expect(battle.roster.enemy.currentHealth == before - 2)
        #expect(battle.roster.enemy.activeEffects.contains { $0.keyword == keyword && $0.effect.potency == 2 })
    }

    @Test(arguments: [BattleParticipant.hero, .companion], [false, true])
    func `supernal glow adds holy damage to physical basics`(owner: BattleParticipant, basic: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            companionModifiers: CombatantTalentCatalog.profile(for: ["pixie_holy_t3_1"]),
        )
        battle.appliesFightPacing = false
        _ = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.roster[owner].id,
            options: DamageOperation.attack(
                tier: basic ? .basic : .skill,
                scaling: .statsAndItems,
                accuracy: .unavoidable,
                abilityCriticalChanceBonus: -1,
            ),
        ))
        #expect(battle.roster.enemy.currentHealth == (basic ? 188 : 190))
    }

    @Test(arguments: [Ability.pixieDust, .stargaze])
    func `frost guard adds freeze to every empowered element`(original: Ability) {
        var battle = heroTalentBattle("mana_moth_freeze_t1_2")
        battle.roster.hero.currentMana = 3
        var ability = original
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        )
        let freeze = ability.damageComponents.filter { $0.keyword == .freeze }.reduce(0) { $0 + $1.amount }
        #expect(freeze == (original.id == Ability.pixieDust.id ? 1 : 3))
        #expect(battle.roster.hero.currentMana == 0)
    }

    @Test func `sacrificial guard spends companion block before hero health`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["golden_retriever_block_t3_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 10
        DefensePoolEngine.set(6, on: battle.companion, in: &battle)

        _ = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id, options: .reaction(),
        ))

        #expect(battle.roster.hero.currentHealth == 10)
        #expect(battle.roster.companion.currentHealth == battle.roster.companion.maxHealth)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 2)
    }
}
