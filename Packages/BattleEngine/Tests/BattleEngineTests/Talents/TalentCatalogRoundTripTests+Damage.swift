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

    @Test(arguments: ["rogue_poison_t1_1", "ranger_burn_t1_1"])
    func `critical talents deal immediate damage and leave their status`(talentID: String) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: [talentID]),
        )
        battle.appliesFightPacing = false
        let before = battle.roster.enemy.currentHealth
        _ = CombatTriggerEngine.afterCriticalHit(to: battle.enemy, source: battle.hero, in: &battle)
        let keyword: Keyword = talentID == "rogue_poison_t1_1" ? .poison : .burn
        #expect(battle.roster.enemy.currentHealth == before - 2)
        #expect(battle.roster.enemy.activeEffects.contains { $0.keyword == keyword && $0.effect.potency == 2 })
    }

    @Test(arguments: [false, true])
    func `fuel the flames damages only burning enemies`(burning: Bool) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_burn_t2_2"]),
        )
        battle.appliesFightPacing = false
        if burning {
            battle.appendEffect(.burn(3), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }
        let before = battle.roster.enemy.currentHealth
        _ = CombatTriggerEngine.afterSpendMana(
            ManaPayment(
                payer: battle.hero,
                balanceBefore: battle.mana(of: battle.hero) + 2,
                balanceAfter: battle.mana(of: battle.hero),
            ),
            in: &battle,
        )
        #expect(battle.roster.enemy.currentHealth == before - (burning ? 1 : 0))
        #expect(battle.roster.enemy.activeEffects.first?.effect.potency == (burning ? 4 : nil))
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

    @Test(arguments: [("knight_holy_t2_1", 3), ("pixie_holy_t3_2", 1)])
    func `next attack holy bonus keeps its damage type`(talent: String, bonus: Int) {
        var resistance = CombatModifierProfile.zero
        resistance.merge([.damageTakenPercent(.physical, 1)])
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: CombatantTalentCatalog.profile(for: [talent]),
            enemyModifiers: resistance,
        )
        battle.appliesFightPacing = false
        _ = CombatTriggerEngine.afterHolyDamageDealt(to: battle.enemy, source: battle.hero, in: &battle)
        for _ in 0 ..< 2 {
            _ = battle.resolveDamage(DamageRequest(
                amount: 10, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
                options: DamageOperation.attack(
                    tier: .skill,
                    scaling: .statsAndItems,
                    accuracy: .unavoidable,
                    abilityCriticalChanceBonus: -1,
                ),
            ))
            #expect(battle.roster.enemy.currentHealth == 200 - bonus)
            #expect(battle.roster.hero.talents.pending.nextAttackHolyBonus == 0)
        }
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

    @Test func `sacrificial guard does not weaken the redirected hit twice`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["golden_retriever_block_t3_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 1
        battle.appendEffect(.damageReductionFlat(2, 2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)

        _ = battle.resolveDamage(DamageRequest(
            amount: 6, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id, options: .reaction(),
        ))

        #expect(battle.roster.hero.currentHealth == 1)
        #expect(battle.roster.companion.currentHealth == 16)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 10)
    }

    @Test(arguments: [
        "knight_stun_t2_1", "bear_stun_t1_1", "bear_stun_t3_2",
        "bear_physical_t3_2", "mana_moth_freeze_t1_1",
    ], [false, true])
    func `attack talents deal advertised damage`(talentID: String, active: Bool) {
        var battle = heroTalentBattle(talentID)
        let skullcracker = talentID == "knight_stun_t2_1"
        let groundSlam = talentID == "bear_stun_t1_1"
        let seismicRoar = talentID == "bear_stun_t3_2"
        let pulverize = talentID == "bear_physical_t3_2"
        let chillingFlutter = talentID == "mana_moth_freeze_t1_1"
        if skullcracker, active {
            seedHeroTalentEffect(.controlMeter(.stun, 20, 20), on: .enemy, in: &battle)
        }
        if seismicRoar {
            battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = active ? 9 : 10 }
        }
        let keyword: Keyword = !active && (groundSlam || pulverize) ? .holy : .physical
        let bonus = active ? (groundSlam ? 1 : 2) : 0
        for hit in 1 ... 2 {
            _ = battle.resolveDamage(DamageRequest(
                amount: 1, target: battle.enemy, keyword: keyword, sourceActorID: battle.hero.id,
                options: DamageOperation.attack(tier: chillingFlutter && active ? .basic : .skill, scaling: .flat, accuracy: .unavoidable),
            ))
            let bonusHits = pulverize ? 1 : hit
            #expect(battle.roster.enemy.currentHealth == 100 - hit - bonus * bonusHits)
        }
        if active, !skullcracker {
            let control: Keyword = chillingFlutter ? .freeze : .stun
            let buildup = pulverize ? 1 : bonus * 2
            #expect(battle.roster.enemy.activeEffects.contains { $0.effect == .controlMeter(control, buildup, 20) })
        }
        if pulverize {
            #expect(battle.roster.enemy.activeEffects.count(where: \.effect.isBleed) == (active ? 1 : 0))
        }
    }
}
