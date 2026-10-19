import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ThornsCombatTests {
    @Test(arguments: [false, true])
    func `Spiteful requires its wearer to survive the hit while committed Thorns still returns damage`(
        finallyDefeated: Bool,
    ) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "spiteful"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1,
            companionHealth: 5,
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = finallyDefeated
        battle.insertEffect(.thorns(8), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)

        let outcome = battle.recordingResult { context in context.resolveTestDamage(
            1,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }

        #expect(battle.roster.enemy.currentHealth == 92)
        #expect(battle.roster.hero.currentHealth == (finallyDefeated ? 0 : 3))
        #expect(battle.roster.companion.currentHealth == 5)
        #expect(outcome.events.contains {
            $0.abilityName == "Spiteful" && $0.effectKind == .instantHeal && $0.amount == 2
        } == !finallyDefeated)
    }

    @Test(arguments: [false, true])
    func `Retaliatory earns Spiteful once even when a Thorns stack also fires`(hasStack: Bool) throws {
        var profile = CombatModifierProfile.zero
        for id in ["retaliatory", "spiteful"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        }
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 5,
            heroModifiers: profile, appliesFightPacing: false,
        )
        if hasStack {
            battle.insertEffect(.thorns(3), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        }

        let hit = battle.recordingResult { context in context.resolveTestDamage(
            10,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }

        #expect(battle.health(of: battle.companion) == 7)
        #expect(hit.events.count(where: { $0.abilityName == "Spiteful" && $0.effectKind == .instantHeal }) == 1)
        #expect(battle.health(of: battle.enemy) == (hasStack ? 96 : 99))
    }

    @Test(arguments: [0, 2])
    func `Spitebloom strengthens Retaliatory before enemy Block`(enemyBlock: Int) throws {
        var profile = CombatModifierProfile.zero
        for id in ["retaliatory", "spitebloom"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        }
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.insertEffect(.poison(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        DefensePoolEngine.set(enemyBlock, on: battle.enemy, in: &battle)

        _ = battle.resolveTestDamage(
            10,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )

        #expect(battle.health(of: battle.enemy) == (enemyBlock == 0 ? 98 : 100))
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == 1)
    }

    @Test(arguments: [false, true])
    func `capped Thorns preserves its stack without gain feedback and still retaliates`(talentGain: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroEffects: [ActiveEffect(id: 1, effect: .thorns(Int.max), remainingTurns: 0)],
            heroModifiers: .withTriggers {
                $0.blockGainThornsPercent = 1
                $0.thornsDamageFlat = 1
                $0.thornsDamageDoubleWhileBlocked = true
            }, appliesFightPacing: false,
        )
        battle.roster.enemy.hasConsumedDeathsDoor = true
        let original = battle.roster.hero.activeEffects
        let gains = battle.recordingEvents { battle in
            if talentGain {
                CombatTriggerEngine.heroTalentThorns(
                    to: battle.hero, source: battle.hero, amount: 1, name: "Thorns", in: &battle,
                )
                DefensePoolEngine.set(2, on: battle.hero, in: &battle)
            } else {
                _ = battle.applyBlockGain(2, to: battle.hero, source: battle.hero, abilityName: "Block")
            }
        }
        #expect(battle.activeEffects(of: battle.hero).filter { $0.effect.kind == .thorns } == original)
        #expect(!gains.contains { $0.effectKind == .thornsApplied })

        _ = battle.resolveTestDamage(1, from: .enemy, to: .hero, options: .attack(accuracy: .unavoidable))

        #expect(battle.isEnemyDefeated)
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect.kind == .thorns })
    }

    @Test func `Interdict rejects triggered Thorns without false gain feedback`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemyModifiers: .withTriggers { $0.interdict = true }, appliesFightPacing: false,
        )
        _ = EffectHandlersTestSupport.dispatch(.thorns(3), battle: &battle)
        _ = EffectHandlersTestSupport.dispatch(.purge(nil), source: battle.enemy, battle: &battle)
        let nextID = battle.nextEffectID

        let gains = battle.recordingEvents { battle in
            CombatTriggerEngine.heroTalentThorns(to: battle.hero, source: battle.hero, name: "Thorns", in: &battle)
        }

        #expect(battle.roster.hero.activeEffects.isEmpty)
        #expect(battle.nextEffectID == nextID)
        #expect(gains.isEmpty)
    }

    @Test(arguments: ["obsidian_hammer", "vanguards_crest"])
    func `Retaliatory preserves nested trinket feedback and reports reflected Health damage`(trinketID: String) throws {
        let armor = try #require(GameContent.itemAffixDefinition(matching: "retaliatory"))
        let trinket = try #require(GameContent.itemAffixDefinition(matching: trinketID))
        var profile = CombatModifierProfile.zero
        armor.astral.triggers.apply(to: &profile, abilityName: armor.title)
        trinket.basic.triggers.apply(to: &profile, abilityName: trinket.title)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 10),
            heroModifiers: profile, appliesFightPacing: false,
        )

        let outcome = battle.recordingResult { context in context.resolveTestDamage(
            10,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }

        #expect(outcome.value.healthLost == 10)
        #expect(battle.roster.enemy.currentHealth == 7)
        let reflection = outcome.events.filter { $0.effectKind == .thornsTriggered }
        #expect(reflection.count == 1)
        #expect(reflection.first?.amount == 3)
        #expect(reflection.first?.keyword == .physical)
        #expect(reflection.first?.targetID == battle.enemy.id)
        #expect(reflection.first?.abilityName == "Retaliatory")
        if trinketID == "obsidian_hammer" {
            #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun))
            #expect(outcome.events.contains {
                $0.effectKind == .controlTriggered && $0.keyword == .stun
                    && $0.targetID == battle.enemy.id && $0.abilityName == "Stunned"
            })
        } else {
            #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 2)
            #expect(outcome.events.contains {
                $0.effectKind == .shieldApplied && $0.targetID == battle.hero.id
                    && $0.amount == 2 && $0.abilityName == "Martial Guard"
            })
        }
    }

    @Test func `fully resisted Retaliatory reflection grants neither Spiteful nor Spitebloom`() throws {
        var profile = CombatModifierProfile.zero
        for id in ["retaliatory", "spiteful", "spitebloom"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        }
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 5,
            heroModifiers: profile,
            enemyModifiers: .init(modifiers: [.damageTakenPercent(.thorns, 1)]), appliesFightPacing: false,
        )

        let reflected = battle.recordingResult { context in context.resolveTestDamage(
            20,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }

        #expect(battle.health(of: battle.enemy) == 100)
        #expect(battle.health(of: battle.companion) == 5)
        #expect(!battle.roster.hasAffliction(.poison, on: battle.enemy))
        #expect(!reflected.events.contains { $0.abilityName == "Spiteful" || $0.abilityName == "Spitebloom" })
        let ordinary = battle.resolveTestDamage(
            20,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
        #expect(ordinary.healthLost == 20)
    }

    @Test(arguments: [Keyword.physical, .holy])
    func `Briar Ward resists actual Thorns including converted retaliation`(keyword: Keyword) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .withTriggers { $0.thornsDealHoly = keyword == .holy },
            enemyModifiers: .init(modifiers: [.damageTakenPercent(.thorns, 0.5)]), appliesFightPacing: false,
        )
        battle.insertEffect(.thorns(8), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)

        let hit = battle.recordingResult { context in context.resolveTestDamage(
            1,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ) }

        #expect(battle.health(of: battle.enemy) == 96)
        #expect(hit.events.contains { $0.effectKind == .thornsTriggered && $0.keyword == keyword && $0.amount == 4 })
        let ordinary = battle.resolveTestDamage(8, options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1))
        #expect(ordinary.healthLost == 8)
    }
}
