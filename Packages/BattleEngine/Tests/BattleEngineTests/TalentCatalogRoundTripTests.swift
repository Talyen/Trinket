import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct TalentCatalogRoundTripTests {
    @Test func `catalog build matches every authored talent`() throws {
        try #expect(CombatantTalentCatalog.validNodeIDsByCombatantID.values.contains { !$0.isEmpty })
        for (combatantID, talentIDs) in CombatantTalentCatalog.validNodeIDsByCombatantID {
            for talentID in talentIDs.sorted() {
                try assertCatalogBuildMatchesAuthoredTalent(combatantID: combatantID, talentID: talentID)
            }
        }
    }

    private func assertCatalogBuildMatchesAuthoredTalent(combatantID: String, talentID: String) throws {
        let authored = try #require(CombatantTalentCatalog.effect(for: talentID), "missing talent \(talentID)")
        let profile = CombatantTalentCatalog.profile(for: [talentID])
        let build = try BattleTestFixtures.catalogBuild(combatantID: combatantID, talents: talentID)
        try #expect(build.modifiers.triggers == authored.triggers, "triggers \(talentID)")
        try #expect(build.modifiers.triggers == profile.triggers, "profile triggers \(talentID)")
        try #expect(
            build.modifiers.triggerAbilityNames == profile.triggerAbilityNames,
            "trigger names \(talentID)",
        )
        for key in authored.triggers.populatedFieldNames {
            try #expect(
                build.modifiers.triggerAbilityName(key, fallback: "") == authored.name,
                "ability name \(talentID) \(key)",
            )
        }
    }

    @Test func `catalog profile merges sorted talent I ds`() {
        let profile = CombatantTalentCatalog.profile(for: ["knight_holy_t1_2", "knight_block_t3_2"])
        #expect(profile.triggers.holyBlockBreakMultiplier == 1.5)
        #expect(profile.triggers.blockRetainsThreeQuarters)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `intercede returns absorbed damage through seismic reversal`(target: BattleParticipant) throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "knight", talents: "knight_block_t2_1")
        let bear = try BattleTestFixtures.catalogBuild(combatantID: "bear", talents: "bear_stun_t4_1")
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: build.combatant,
            companion: bear.combatant,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            heroModifiers: build.modifiers,
            companionModifiers: bear.modifiers,
        )
        battle.appliesFightPacing = false
        _ = battle.applyBlock(10, to: build.combatant, source: build.combatant, abilityName: "Test")
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 4,
                target: battle.roster[target].combatant,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
            ),
        )
        #expect(outcome.healthLost == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: build.combatant)) == 6)
        #expect(battle.roster.enemy.currentHealth == 36)
        #expect(battle.roster.activeEffects(for: battle.enemy).contains {
            if case .controlMeter(.stun, 4, _) = $0.effect {
                return true
            }
            return false
        })
    }

    @Test(arguments: [(Keyword.burn, 0.0, 8, 10, 4), (.physical, 0.5, 1, 5, 2), (.physical, 0.0, 0, 2, 4)])
    func `block bypass applies to intercede and the recipients block`(
        keyword: Keyword, physicalIgnore: Double, healthLost: Int, heroBlock: Int, companionBlock: Int,
    ) {
        var heroProfile = CombatModifierProfile.zero
        heroProfile.triggers.blockAbsorbsCompanionDamage = true
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.burnIgnoresBlockAndMitigation = true
        enemyProfile.triggers.physicalBlockIgnorePercent = physicalIgnore
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: heroProfile, enemyModifiers: enemyProfile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        DefensePoolEngine.set(4, on: battle.companion, in: &battle)
        let result = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.companion, keyword: keyword, sourceActorID: battle.enemy.id,
            options: .effect(scaling: .flat),
        ))
        #expect(result.healthLost == healthLost)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == heroBlock)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == companionBlock)
    }

    @Test func `intercede triggers cascading only when hero block breaks`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(block: BlockTriggers(
                blockBrokenBlockFlat: 2, blockAbsorbsCompanionDamage: true,
            ))),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        _ = battle.applyBlock(3, to: battle.hero, source: battle.hero, abilityName: "Block")
        for amount in [1, 3] {
            _ = battle.resolveDamage(DamageRequest(
                amount: amount, target: battle.companion, keyword: .physical,
                sourceActorID: battle.enemy.id, options: .reaction(),
            ))
            #expect(talentPoints(.shield, on: .hero, in: battle) == 2)
        }
        #expect(battle.roster.companion.currentHealth == battle.roster.companion.maxHealth - 1)
    }

    @Test(arguments: [false, true])
    func `triggered purge pays crownfall for each removed buff`(purgeAll: Bool) {
        var battle = heroTalentBattle("shield_scarab_holy_t4_1")
        seedHeroTalentEffect(.thorns(2), on: .enemy, in: &battle)
        seedHeroTalentEffect(.damageReductionFlat(1, 2), on: .enemy, in: &battle)
        seedHeroTalentEffect(.nextStrikeDouble, on: .enemy, in: &battle)
        let healthBefore = battle.roster.enemy.currentHealth
        let events = CombatTriggerEngine.applyPurge(
            to: battle.enemy, source: battle.hero, abilityName: "Unmaking",
            count: 1, purgeAll: purgeAll, in: &battle,
        )
        #expect(events.count { $0.effectKind == .purgeApplied } == (purgeAll ? 2 : 1))
        #expect(healthBefore - battle.roster.enemy.currentHealth == (purgeAll ? 6 : 3))
        #expect(battle.roster.activeEffects(for: battle.enemy).contains { $0.effect.kind == .damageReductionFlat })
    }

    @Test func `deep freeze blocks enemy block and healing`() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "wizard", talents: "wizard_freeze_t3_1")
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: build.combatant,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            heroModifiers: build.modifiers,
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        let blockEvents = battle.applyBlock(
            5,
            to: battle.roster.enemy.combatant,
            source: battle.roster.enemy.combatant,
            abilityName: "Test",
        )
        #expect(blockEvents.isEmpty)
        battle.roster.mutateRuntime(for: battle.roster.enemy.combatant) { $0.currentHealth = 10 }
        let heal = battle.resolveHeal(
            HealRequest(amount: 5, target: battle.roster.enemy.combatant, sourceActorID: battle.roster.enemy.id),
        )
        #expect(heal.healthRestored == 0)
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 10)
    }

    @Test func `deep freeze does not deny frozen hero block or heal`() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "wizard", talents: "wizard_freeze_t3_1")
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: build.combatant,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            heroModifiers: build.modifiers,
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
            for: battle.roster.hero.combatant,
            on: &battle,
        )
        let blockEvents = battle.applyBlock(
            5,
            to: battle.roster.hero.combatant,
            source: battle.roster.hero.combatant,
            abilityName: "Test",
        )
        #expect(!(blockEvents.isEmpty))
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 10 }
        let maxHealth = battle.roster.maxHealth(for: battle.roster.hero.combatant)
        _ = battle.resolveHeal(
            HealRequest(amount: 5, target: battle.roster.hero.combatant, sourceActorID: "enemy"),
        )
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == min(15, maxHealth))
    }

    @Test func `phoenix gift heals hero from fatal damage`() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "phoenix", talents: "phoenix_health_t3_1")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: build.combatant,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            companionModifiers: build.modifiers,
        )
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 5 }
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 40,
                target: hero,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
            ),
        )
        #expect(battle.roster.health(for: hero) == 3)
        #expect(battle.roster.runtime(for: build.combatant)?.hasTriggeredPhoenixGift == true)

        _ = battle.resolveDamage(
            DamageRequest(
                amount: 40,
                target: hero,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
            ),
        )
        #expect(battle.roster.health(for: hero) == 1)

        battle.roster.setActiveEffects([], for: hero)
        battle.roster.mutateRuntime(for: hero) {
            $0.hasConsumedDeathsDoor = true
            $0.deathsDoorExpiredAtTurn = -1
        }
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 40,
                target: hero,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
            ),
        )
        #expect(battle.roster.health(for: hero) == 0)
    }

    @Test func `rebirth revives before deaths door then deaths door on second lethal`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = try BattleTestFixtures.catalogBuild(combatantID: "phoenix", talents: "phoenix_deathsdoor_t1_1")
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers,
        )
        context.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 5 }

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
            ),
        )
        try #expect(context.roster.health(for: build.combatant) == 10)
        try #expect(context.roster.runtime(for: build.combatant)?.hasTriggeredDeathRevive == true)
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant) == false)

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
            ),
        )
        try #expect(context.roster.health(for: build.combatant) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant))
        try #expect(context.roster.isDeathsDoorActive(for: build.combatant))
    }

    @Test func `deathrattle revives with block before deaths door`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = try BattleTestFixtures.catalogBuild(
            combatantID: "risen_skeleton",
            talents: "risen_skeleton_deathsdoor_t1_1",
        )
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers,
        )
        context.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 5 }

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
            ),
        )
        try #expect(context.roster.health(for: build.combatant) == 1)
        try #expect(
            BattleTestFixtures.shieldPoints(for: build.combatant, in: context)
                == context.paced(10, sourceActorID: build.combatant.id),
        )
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant) == false)

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
            ),
        )
        try #expect(context.roster.health(for: build.combatant) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant))
    }

    private struct HealGrantBlockCase {
        let combatantID: String
        let talentID: String
        let abilityName: String

        static let wardedRoost = Self(
            combatantID: "library_owl",
            talentID: "library_owl_health_t1_2",
            abilityName: "Warded Roost",
        )
    }

    @Test(arguments: [Self.HealGrantBlockCase.wardedRoost])
    private func `heal grant block logs authored ability name`(_ testCase: HealGrantBlockCase) throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: testCase.combatantID, talents: testCase.talentID)
        #expect(build.modifiers.triggerAbilityName("onHealGrantBlock", fallback: "") == testCase.abilityName)
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: build.combatant,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            companionModifiers: build.modifiers,
        )
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        let outcome = battle.resolveHeal(
            HealRequest(amount: 4, target: hero, sourceActorID: build.combatant.id),
        )
        #expect(outcome.events.contains {
            $0.abilityName == testCase.abilityName && $0.effectKind == .shieldApplied && $0.amount == 2
        })
    }
}
