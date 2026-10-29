import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ItemAffixAdditionsTests {
    @Test func `Bastioned is an opening grant and Stun rewards require actual control and empty resources`() throws {
        var profile = try profile(["bastioned", "steadfast", "arcane"])
        profile.triggers.startBattleBlock = 4
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40, maxMana: 10),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroMana: 0, heroModifiers: profile, appliesFightPacing: false,
        )
        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(block(battle) == 4)
        battle.turnCount = 1
        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(block(battle) == 4)
        battle.roster.mutateEffects(for: battle.hero) { $0.removeAll { $0.effect.keyword == .block } }
        battle.roster.hero.currentMana = 0
        _ = battle.chargeTestControl(1, keyword: .stun, to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false)
        #expect(block(battle) == 0 && battle.roster.hero.currentMana == 0)
        _ = battle.chargeTestControl(30, keyword: .stun, to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false)
        #expect(block(battle) == 3 && battle.roster.hero.currentMana == 1)
        _ = battle.chargeTestControl(30, keyword: .stun, to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false)
        #expect(block(battle) == 3 && battle.roster.hero.currentMana == 1)
    }

    @Test func `Shattering needs completed Freeze and Cinderbound strengthens existing Burn ticks`() throws {
        var battle = try BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            enemyEffects: [ActiveEffect(id: 1, effect: .bleed(1), remainingTurns: 2)],
            heroModifiers: profile(["shattering", "cinderbound"]), appliesFightPacing: false,
        )
        let burn = battle.resolveTestDamage(2, keyword: .burn, options: .resolvedPeriodic)
        #expect(burn.healthLost == 3)
        _ = battle.chargeTestControl(1, keyword: .freeze, to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false)
        let before = battle.health(of: battle.enemy)
        _ = battle.chargeTestControl(30, keyword: .freeze, to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false)
        #expect(before - battle.health(of: battle.enemy) == 3)
    }

    @Test func `Block break rewards repeat in the same turn and do not share Saintfall allowances`() throws {
        var profile = try profile(["resolute", "reactive"])
        profile.triggers.blockBrokenBlockFlat = 1
        profile.triggers.blockBrokenSaintfallPower = 1
        var battle = BattleTestFixtures.makeAffixBattle(
            heroHealth: 10,
            heroEffects: [ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTurns: 2)],
            modifiers: profile,
        )
        for _ in 0 ..< 2 {
            _ = battle.resolveTestDamage(1, from: .enemy, to: .hero, options: .attack(
                scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
            ))
        }
        #expect(battle.health(of: battle.hero) == 13)
        #expect(battle.health(of: battle.enemy) == 36)
        #expect(block(battle) == 1)
    }

    @Test func `Bloodletting rolls once per card after Health damage and rearms for another card in the same turn`() throws {
        var profile = try profile(["bloodletting"])
        profile.triggers.physicalAttackBleedChancePercent = 1
        var battle = BattleTestFixtures.makeAffixBattle(
            enemyEffects: [ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTurns: 2)],
            modifiers: profile,
        )
        let operation = DamageOperation.attack(origin: .card, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1)
        let outcome = battle.recordingResult { context in
            for index in 0 ..< 2 {
                let serial = context.resolution.beginCard(actorID: context.hero.id)
                if index == 0 {
                    _ = context.resolveTestDamage(1, options: operation)
                }
                _ = context.resolveTestDamage(1, options: operation)
                _ = context.resolveTestDamage(1, options: operation)
                context.resolution.endCard(serial)
            }
        }
        #expect(outcome.events.count(where: { $0.kind == .abilityDamage && $0.abilityName == "Bloodletting" }) == 2)
        #expect(battle.health(of: battle.enemy) == 34)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Kinbound heals either wearer repeatedly from ally attacks but excludes ticks and retaliation`(wearer: BattleParticipant) throws {
        let profile = try profile(["kinbound"])
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10, companionHealth: 10,
            heroModifiers: wearer == .hero ? profile : .zero,
            companionModifiers: wearer == .companion ? profile : .zero,
            appliesFightPacing: false,
        )
        let attacker: BattleParticipant = wearer == .hero ? .companion : .hero
        for operation in [DamageOperation.resolvedPeriodic, .reaction()] {
            _ = battle.resolveTestDamage(10, from: attacker, options: operation)
        }
        #expect(battle.roster[wearer].currentHealth == 10)
        for _ in 0 ..< 2 {
            _ = battle.resolveTestDamage(10, from: attacker, options: .attack(
                scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
            ))
        }
        #expect(battle.roster[wearer].currentHealth == 12)
    }

    private func profile(_ ids: [String]) throws -> CombatModifierProfile {
        var result = CombatModifierProfile.zero
        result.triggers.criticalChanceBonus = -1
        for id in ids {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &result, abilityName: affix.title)
        }
        return result
    }

    private func block(_ battle: BattleState) -> Int {
        DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero))
    }
}
