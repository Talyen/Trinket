import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ItemAffixKeywordExpansionTests {
    @Test func `healing cleanse grants clearheaded block and solace mana only when a status is removed`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onHealCleanseTargetChance = 1
        profile.triggers.cleanseSelfBlockFlat = 2
        profile.triggers.onCleanseRestoreMana = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40, maxMana: 10),
            heroEffects: [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 0)],
            heroHealth: 10,
            heroMana: 0,
            heroModifiers: profile,
        )
        let hero = battle.hero

        let first = battle.recordingEvents { battle in await battle.healEmitting(
            amount: 2,
            target: hero,
            source: hero,
            abilityName: "Test Heal",
        ) }
        #expect(first.contains { $0.effectKind == .cleanseApplied })
        #expect(!battle.roster.activeEffects(for: hero).contains { $0.effect.isRemovableDebuff })
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: hero)) == 2)
        #expect(battle.roster.runtime(for: hero)?.currentMana == 1)

        battle.healEmitting(amount: 2, target: hero, source: hero, abilityName: "Test Heal")
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: hero)) == 2)
        #expect(battle.roster.runtime(for: hero)?.currentMana == 1)
    }

    @Test func `a successful Purge grants Block and prepares Holy damage while an empty Purge cannot rearm it`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.manaEmpowerPurgeCount = 1
        profile.triggers.onPurgeGainBlock = 2
        profile.triggers.purgeNextHolyAttackBonus = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40, maxMana: 10),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            enemyEffects: [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 2)],
            heroModifiers: profile, appliesFightPacing: false,
        )
        let hero = battle.hero
        let enemy = battle.enemy

        let first = battle.recordingEvents { battle in await CombatTriggerEngine.afterHeroTalentSpendMana(
            actor: hero,
            amount: 3,
            empowered: true,
            in: &battle,
        ) }
        #expect(first.contains { $0.effectKind == .purgeApplied })
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: hero)) == 2)
        #expect(battle.health(of: enemy) == 40)
        #expect(battle.roster.hero.talents.pending.nextPurgeHolyAttackBonus?.value == 2)

        let second = battle.recordingEvents { battle in await CombatTriggerEngine.afterHeroTalentSpendMana(
            actor: hero,
            amount: 3,
            empowered: true,
            in: &battle,
        ) }
        #expect(!second.contains { $0.effectKind == .purgeApplied })
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: hero)) == 2)
        #expect(battle.health(of: enemy) == 40)
        #expect(battle.roster.hero.talents.pending.nextPurgeHolyAttackBonus?.value == 2)
        let outcome = battle.resolveTestDamage(2, keyword: .holy, options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1))
        #expect(outcome.healthLost == 4)
        CombatExecutor.run { await CombatTriggerEngine.afterHeroTalentSpendMana(actor: hero, amount: 3, empowered: true, in: &battle) }
        #expect(battle.roster.hero.talents.pending.nextPurgeHolyAttackBonus == nil)
    }

    @Test func `Unmaking and Fortunate Strike reward a fully Blocked Critical Hit`() throws {
        var profile = CombatModifierProfile.zero
        for id in ["unmaking", "lucky_clover"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        }
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            enemyEffects: [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 2)],
            heroModifiers: profile, appliesFightPacing: false,
        )

        let outcome = battle.resolveTestDamage(1, options: .attack(scaling: .flat, accuracy: .unavoidable, guaranteedCritical: true))

        #expect(outcome.isCritical)
        #expect(outcome.healthLost == 0)
        #expect(battle.health(of: battle.enemy) == 40)
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.isRemovableBuff })
        #expect(outcome.events.count { $0.effectKind == .purgeApplied && $0.abilityName == "Unmaking" } == 1)
        #expect(battle.gold == 1)
        #expect(outcome.events.count { $0.keyword == .gold && $0.abilityName == "Fortunate Strike" && $0.amount == 1 } == 1)
    }

    @Test func `death door entry burns and surviving its expiry heals`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.enterDeathsDoorBurnDamage = 3
        profile.triggers.deathsDoorCriticalChanceBonus = 1
        profile.triggers.affixDeathsDoorSurviveHealFlat = 3
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroHealth: 5,
            heroModifiers: profile, appliesFightPacing: false,
        )
        let hero = battle.hero

        _ = battle.resolveTestDamage(5, to: hero, options: .attack(scaling: .flat, accuracy: .unavoidable))
        #expect(battle.roster.isDeathsDoorActive(for: hero))
        #expect(battle.roster.activeEffects(for: battle.enemy).contains {
            $0.effect.kind == .burn
        })
        let attack = battle.resolveTestDamage(2, options: DamageOperation.attack(tier: .basic, scaling: .flat, accuracy: .unavoidable))
        #expect(attack.isCritical)

        let expiry = battle.recordingEvents { battle in await DeathsDoorEngine.afterDeathsDoorExpired(on: hero, in: &battle) }
        #expect(expiry.contains { $0.effectKind == .instantHeal && $0.amount == 3 })
        #expect(battle.health(of: hero) == 4)
    }

    @Test func `retained block grows thorns and only the first damaging retaliation heals`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.retainedBlockThornsFlat = 1
        profile.triggers.thornsDamageFlatWhileBlocked = 2
        profile.triggers.firstThornsDamageHealPerTurn = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroEffects: [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 2)],
            heroHealth: 10,
            heroModifiers: profile, appliesFightPacing: false,
        )
        let hero = battle.hero

        CombatExecutor.run { await DefensePoolEngine.decayBlock(on: hero, in: &battle) }
        #expect(battle.roster.activeEffects(for: hero).contains {
            if case .thorns(1) = $0.effect {
                return true
            }
            return false
        })
        for _ in 0 ..< 2 {
            _ = battle.resolveTestDamage(1, from: .enemy, to: .hero, options: DamageOperation.attack(
                tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
            ))
            CombatExecutor.run { await CombatTriggerEngine.heroTalentThorns(
                to: hero, source: hero, amount: 1, name: "Test Thorns", in: &battle,
            ) }
        }
        #expect(battle.health(of: battle.enemy) == 34)
        #expect(battle.health(of: hero) == 12)
    }
}
