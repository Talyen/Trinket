import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HealthRestorationTargetingTests {
    @Test func `Spiteful heals a wounded partner when the wearer is full`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.firstThornsDamageHealPerTurn = 2
        profile.triggers.criticalChanceBonus = -1
        var battle = battle(heroModifiers: profile)
        DefensePoolEngine.set(1, on: battle.hero, in: &battle)
        battle.insertEffect(.thorns(3), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        _ = battle.resolveTestDamage(1, from: .enemy, to: .hero, options: .attack(accuracy: .unavoidable))
        #expect(battle.health(of: battle.companion) == 3)
        #expect(battle.health(of: battle.hero) == 20)
    }

    private func battle(
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        heroHealth: Int = 20,
        companionHealth: Int = 1,
    ) -> BattleState {
        BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: heroHealth,
            companionHealth: companionHealth,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers, appliesFightPacing: false,
        )
    }

    @Test func `holy and dodge affixes restore the lowest ally`() {
        let holy = CombatModifierProfile.withTriggers { $0.firstHolyAttackHealPerTurn = 3 }
        var holyBattle = battle(heroModifiers: holy)
        CombatExecutor.run { await CombatTriggerEngine.afterHolyDamageDealt(
            to: holyBattle.enemy, source: holyBattle.hero, attackHit: true, in: &holyBattle,
        ) }
        #expect(holyBattle.health(of: holyBattle.companion) == 4)
        #expect(holyBattle.health(of: holyBattle.hero) == 20)

        let dodge = CombatModifierProfile.withTriggers { $0.dodgeHealFlat = 3 }
        var dodgeBattle = battle(heroModifiers: dodge)
        CombatExecutor.run { await CombatTriggerEngine.afterDodge(
            by: dodgeBattle.hero, attackerID: dodgeBattle.enemy.id,
            allowsCounterattacks: false, in: &dodgeBattle,
        ) }
        #expect(dodgeBattle.health(of: dodgeBattle.companion) == 4)
        #expect(dodgeBattle.health(of: dodgeBattle.hero) == 20)
    }

    @Test func `gold affix and talent restoration reach a wounded partner`() {
        let profile = CombatModifierProfile.withTriggers {
            $0.gainGoldBonusHealSelf = 2
            $0.goldGainHealChancePercent = 1
            $0.goldGainHealAmount = 3
        }
        var battle = battle(heroModifiers: profile)
        battle.grantGoldEvent(1, to: battle.hero, abilityName: "Test Gold")
        #expect(battle.health(of: battle.companion) == 6)
        #expect(battle.health(of: battle.hero) == 20)
    }

    @Test func `hibernation uses the bear's Block to heal its lower Health ally`() {
        let profile = CombatModifierProfile.withTriggers { $0.endTurnWithBlockHealFlat = 2 }
        var battle = battle(companionModifiers: profile, heroHealth: 1, companionHealth: 20)
        DefensePoolEngine.set(3, on: battle.companion, in: &battle)
        CombatExecutor.run { await CombatTriggerEngine.atPlayerEndTurn(in: &battle) }
        #expect(battle.health(of: battle.hero) == 3)
        #expect(battle.health(of: battle.companion) == 20)
    }

    @Test func `cleanse restoration can heal a different ally`() {
        let profile = CombatModifierProfile.withTriggers {
            $0.criticalChanceBonus = -1
            $0.cleanseSelfHeal = 2
            $0.cleanseBonusHeal = 2
            $0.purifyingWaters = true
            $0.freshBatch = true
        }
        var battle = battle(heroModifiers: profile)
        battle.insertEffect(.poison(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 1)
        _ = CombatExecutor.run { await EffectRemovalOperation.resolveCleanse(
            .all(.poison), source: battle.hero, target: battle.hero,
            abilityName: "Cleanse", in: &battle,
        ) }
        #expect(battle.health(of: battle.companion) == 9)
        #expect(battle.health(of: battle.hero) == 20)
    }

    @Test func `Panacea heals the lowest ally after Fresh Batch changes Health`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["alchemist_cleanse_t1_2"])
        profile.triggers.criticalChanceBonus = -1
        var battle = battle(heroModifiers: profile, heroHealth: 5, companionHealth: 6)
        battle.insertEffect(.poison(1), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 1)
        battle.nextCardID += 1
        let card = BattleCard(id: battle.nextCardID, ability: .panaceaPotion, owner: .hero)
        battle.hand.append(card)

        let events = try battle.playCard(cardID: card.id).events

        #expect(battle.health(of: battle.hero) == 7)
        #expect(battle.health(of: battle.companion) == 12)
        #expect(!battle.activeEffects(of: battle.companion).contains { $0.effect.isRemovableDebuff })
        #expect(events.contains { $0.abilityName == "Fresh Batch" && $0.effectKind == .instantHeal && $0.amount == 2 })
        #expect(events.contains { $0.abilityName == Ability.panaceaPotion.name && $0.effectKind == .instantHeal && $0.amount == 6 })
    }

    @Test func `saintfall heals the lowest ally after Block breaks`() {
        let profile = CombatModifierProfile.withTriggers { $0.blockBrokenSaintfallPower = 6 }
        var battle = battle(heroModifiers: profile)
        DefensePoolEngine.set(1, on: battle.hero, in: &battle)
        _ = battle.resolveTestDamage(2, from: .enemy, to: .hero, options: .effect())
        #expect(battle.health(of: battle.companion) == 7)
    }
}
