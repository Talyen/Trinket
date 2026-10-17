import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct TalentCatalogRoundTripTests {
    @Test func `catalog profiles retain authored triggers and their names`() {
        for (talentID, authored) in CombatantTalentCatalog.signatureTalents {
            let profile = CombatantTalentCatalog.profile(for: [talentID])
            #expect(profile.triggers == authored.triggers, "Triggers on \(talentID)")
            for field in authored.triggers.populatedFields {
                #expect(profile.triggerAbilityName(field, fallback: "") == authored.name, "Name on \(talentID) \(field)")
            }
        }
    }

    @Test(arguments: [(Keyword.burn, 0.0, 8, 10, 4), (.physical, 0.5, 1, 5, 2), (.physical, 0.0, 0, 2, 4)])
    func `block bypass applies to intercede and the recipients block`(
        keyword: Keyword, physicalIgnore: Double, healthLost: Int, heroBlock: Int, companionBlock: Int,
    ) {
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: .withTriggers { $0.blockAbsorbsCompanionDamage = true }, enemyModifiers: .withTriggers {
                $0.burnIgnoresBlockAndMitigation = true
                $0.physicalBlockIgnorePercent = physicalIgnore
            }, dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        DefensePoolEngine.set(4, on: battle.companion, in: &battle)
        let result = battle.resolveTestDamage(8, from: .enemy, to: .companion, keyword: keyword, options: .effect(scaling: .flat))
        #expect(result.healthLost == healthLost)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == heroBlock)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == companionBlock)
    }

    @Test func `intercede triggers cascading only when hero block breaks`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatModifierProfile.withTriggers {
                $0.blockBrokenBlockFlat = 2
                $0.blockAbsorbsCompanionDamage = true
            },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        _ = battle.applyBlockGain(3, to: battle.hero, source: battle.hero, abilityName: "Block")
        for amount in [1, 3] {
            _ = battle.resolveTestDamage(amount, from: .enemy, to: .companion, options: .reaction())
            #expect(talentPoints(.shield, on: .hero, in: battle) == 2)
        }
        #expect(battle.roster.companion.currentHealth == battle.roster.companion.maxHealth - 1)
    }

    @Test(arguments: [BattleParticipant.enemy, .hero])
    func `deep freeze denies only the frozen enemy Block and healing`(recipient: BattleParticipant) throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "wizard", talents: "wizard_freeze_t3_1")
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: build.combatant,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            heroModifiers: build.modifiers,
        )
        let target = battle.roster[recipient].combatant
        battle.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
            for: target,
        )
        let blockEvents = battle.recordingEvents { battle in
            battle.applyBlockGain(5, to: target, source: target, abilityName: "Test")
        }
        #expect(blockEvents.isEmpty == (recipient == .enemy))
        battle.roster.mutateRuntime(for: target) { $0.currentHealth = 10 }
        let heal = battle.resolveHeal(HealRequest(amount: 5, target: target, sourceActorID: "enemy"))
        if recipient == .enemy {
            #expect(heal.healthRestored == 0)
        }
        let expectedHealth = recipient == .enemy ? 10 : min(15, battle.roster.maxHealth(for: target))
        #expect(battle.roster.health(for: target) == expectedHealth)
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
        _ = battle.resolveTestDamage(
            40,
            to: hero,
            keyword: .physical,
            sourceActorID: "enemy",
            options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
        )
        #expect(battle.roster.health(for: hero) == 5)
        #expect(battle.roster.runtime(for: build.combatant)?.hasTriggeredPhoenixGift == true)

        _ = battle.resolveTestDamage(
            40,
            to: hero,
            keyword: .physical,
            sourceActorID: "enemy",
            options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
        )
        #expect(battle.roster.health(for: hero) == 1)

        battle.roster.setActiveEffects([], for: hero)
        battle.roster.mutateRuntime(for: hero) {
            $0.hasConsumedDeathsDoor = true
            $0.deathsDoorExpiredAtTurn = -1
        }
        _ = battle.resolveTestDamage(
            40,
            to: hero,
            keyword: .physical,
            sourceActorID: "enemy",
            options: DamageOperation.effect(scaling: .flat, accuracy: .unavoidable),
        )
        #expect(battle.roster.health(for: hero) == 0)
    }

    @Test func `sacrificial guard spends companion block before hero health`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["golden_retriever_block_t3_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 10
        DefensePoolEngine.set(6, on: battle.companion, in: &battle)

        _ = battle.resolveTestDamage(4, from: .enemy, to: .hero, options: .reaction())

        #expect(battle.roster.hero.currentHealth == 10)
        #expect(battle.roster.companion.currentHealth == battle.roster.companion.maxHealth)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 2)
    }

    @Test func `returning bloom restores the wounded Hero when the Companion is full`() throws {
        var battle = capstoneBattle(hero: ["druid_poison_t2_2"])
        battle.roster.hero.currentHealth = 5
        seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle)

        let events = battle.recordingEvents { battle in await EffectTurnEngine.advanceAll(context: &battle) }

        #expect(!battle.roster.hasAffliction(.poison, on: battle.enemy))
        #expect(battle.roster.hero.currentHealth == 8)
        #expect(battle.roster.companion.currentHealth == battle.roster.companion.maxHealth)
        let restoration = try #require(events.first { $0.abilityName == "Returning Bloom" })
        #expect(restoration.targetID == battle.hero.id)
        #expect(restoration.amount == 3)
    }
}
