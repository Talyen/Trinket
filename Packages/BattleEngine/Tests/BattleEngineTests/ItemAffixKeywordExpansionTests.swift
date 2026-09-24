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
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
            heroEffects: [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 0)],
            heroHealth: 10,
            heroMana: 0,
            heroModifiers: profile,
        )
        let hero = battle.hero

        let first = battle.healEmitting(amount: 2, target: hero, source: hero, abilityName: "Test Heal")
        #expect(first.contains { $0.effectKind == .cleanseApplied })
        #expect(!battle.roster.activeEffects(for: hero).contains { $0.effect.isRemovableDebuff })
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: hero)) == 2)
        #expect(battle.roster.runtime(for: hero)?.currentMana == 1)

        _ = battle.healEmitting(amount: 2, target: hero, source: hero, abilityName: "Test Heal")
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: hero)) == 2)
        #expect(battle.roster.runtime(for: hero)?.currentMana == 1)
    }

    @Test func `a successful purge grants block and holy damage while an empty purge grants neither`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.manaEmpowerPurgeCount = 1
        profile.triggers.onPurgeGainBlock = 2
        profile.triggers.onPurgeDealHolyDamage = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40, maxMana: 10),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            enemyEffects: [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 2)],
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        let hero = battle.hero
        let enemy = battle.enemy

        let first = CombatTriggerEngine.afterHeroTalentSpendMana(actor: hero, amount: 3, empowered: true, in: &battle)
        #expect(first.contains { $0.effectKind == .purgeApplied })
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: hero)) == 2)
        #expect(battle.health(of: enemy) == 38)

        let second = CombatTriggerEngine.afterHeroTalentSpendMana(actor: hero, amount: 3, empowered: true, in: &battle)
        #expect(!second.contains { $0.effectKind == .purgeApplied })
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: hero)) == 2)
        #expect(battle.health(of: enemy) == 38)
    }

    @Test func `death door entry burns and surviving its expiry heals`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.enterDeathsDoorBurnDamage = 3
        profile.triggers.deathsDoorCriticalChanceBonus = 1
        profile.triggers.affixDeathsDoorSurviveHealFlat = 3
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroHealth: 5,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        let hero = battle.hero

        _ = battle.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        #expect(battle.roster.isDeathsDoorActive(for: hero))
        #expect(battle.roster.activeEffects(for: battle.enemy).contains {
            if case .burn = $0.effect {
                return true
            }
            return false
        })
        let attack = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .physical,
            sourceActorID: hero.id,
            options: DamageOperation.attack(tier: .basic, scaling: .flat, accuracy: .unavoidable),
        ))
        #expect(attack.isCritical)

        let expiry = DeathsDoorEngine.afterDeathsDoorExpired(on: hero, in: &battle)
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
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroEffects: [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 2)],
            heroHealth: 10,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        let hero = battle.hero

        _ = DefensePoolEngine.decayBlock(on: hero, in: &battle)
        #expect(battle.roster.activeEffects(for: hero).contains {
            if case .thorns(1) = $0.effect {
                return true
            }
            return false
        })
        for _ in 0 ..< 2 {
            _ = battle.resolveDamage(DamageRequest(
                amount: 1, target: hero, keyword: .physical,
                sourceActorID: battle.enemy.id,
                options: DamageOperation.attack(
                    tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
                ),
            ))
            _ = CombatTriggerEngine.heroTalentThorns(
                to: hero, source: hero, amount: 1, name: "Test Thorns", in: &battle,
            )
        }
        #expect(battle.health(of: battle.enemy) == 34)
        #expect(battle.health(of: hero) == 12)
    }
}
