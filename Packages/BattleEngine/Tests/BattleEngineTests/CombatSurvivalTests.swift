import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatSurvivalTests {
    @Test(arguments: [false, true])
    func `cleanse retains its removal but requires a surviving caster for later rewards`(survives: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 5, companionHealth: survives ? 20 : 1,
            companionModifiers: .withTriggers {
                $0.cleanseHolyDamage = 3
                $0.cleanseSelfHeal = 2
                $0.cleansePartyBlock = 3
                $0.cleanseAffectsBothHeroAndCompanion = true
            }, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 2 }, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.insertEffect(.poison(2), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.insertEffect(.burn(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)

        let outcome = battle.recordingResult { battle in await EffectRemovalOperation.resolveCleanse(
            .all(nil), source: battle.companion, target: battle.companion, abilityName: "Cleanse",
            baseHeal: 6, healTarget: .lowestHealthAlly, in: &battle,
        ) }

        #expect(battle.roster.companion.isAlive == survives)
        #expect(!battle.activeEffects(of: battle.companion).contains { $0.effect.isRemovableDebuff })
        #expect(outcome.events.contains { $0.effectKind == .cleanseApplied && $0.targetID == battle.companion.id })
        #expect(battle.hasTalentDebuff(on: battle.hero) == !survives)
        #expect((battle.health(of: battle.hero) > 5) == survives)
        #expect((DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) > 0) == survives)
    }

    @Test(arguments: [false, true])
    func `Companion Holy hit stops remaining benefits after lethal Gold or Purge reactions`(purgeReaction: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.criticalGoldStealFlat = purgeReaction ? 0 : 1
        profile.triggers.gainGoldBonusHealSelf = purgeReaction ? 0 : 1
        profile.triggers.onHealDealHoly = 1
        profile.triggers.holyCriticalAllyIgnoreBlock = true
        profile.triggers.holyCriticalPurgeCount = purgeReaction ? 1 : 0
        profile.triggers.crownfall = purgeReaction
        profile.triggers.holyAttackEnemyMissChance = 1
        profile.triggers.holyAttackDrawChancePercent = 1
        profile.triggers.holyAttackCleanseAllyChancePercent = 1
        profile.triggers.holyCritEnemyNextAttackMissChance = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 1,
            companionModifiers: profile, enemyModifiers: .withTriggers {
                $0.onBlockHitDealHoly = 3
                $0.sealedSarcophagus = true
            }, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.companionDeck = CombatDeck(abilities: [.block])
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)
        battle.insertEffect(.poison(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 1)
        battle.insertEffect(.thorns(2), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterCompanionAttackHit(
            keyword: .holy, actor: battle.companion, critical: true, healthLost: 1,
            triggers: profile.triggers, in: &battle,
        ) }

        #expect(!battle.roster.companion.isAlive)
        #expect(battle.roster.hero.isAlive)
        #expect(battle.gold == (purgeReaction ? 0 : 1))
        // Revealed Flaw precedes Bane of Evil and remains committed if the later Purge is lethal.
        #expect((battle.roster.hero.talents.pending.nextAttackIgnoresBlock != nil) == purgeReaction)
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .poison(2) })
        #expect(battle.companionDeck.abilities.map(\.id) == [Ability.block.id])
        #expect(battle.roster.enemy.talents.pending.nextAttackMissChance == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == (purgeReaction ? 17 : 19))
        #expect(!events.contains { $0.abilityName == "Purifying Light" || $0.abilityName == "Radiant Wisdom" })
        #expect(events.contains { $0.abilityName == (purgeReaction ? "Bane of Evil" : "Pickpocket") })
    }

    @Test(arguments: [false, true])
    func `final Companion hit does not prepare enemy misses after lethal reward retaliation`(goldReaction: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.attackGoldStealAmount = goldReaction ? 1 : 0
        profile.triggers.attackGoldStealChancePercent = 1
        profile.triggers.gainGoldBonusHealSelf = 1
        profile.triggers.onHealDealHoly = 1
        profile.triggers.holyCriticalStunDamage = goldReaction ? 0 : 1
        profile.triggers.holyCritEnemyNextAttackMissChance = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 1,
            companionModifiers: profile, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 3 }, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterFinalCompanionCardHit(
            keyword: .holy, actor: battle.companion, critical: true, triggers: profile.triggers, in: &battle,
        ) }

        #expect(!battle.roster.companion.isAlive)
        #expect(battle.roster.enemy.talents.pending.nextAttackMissChance == 0)
        #expect(battle.gold == (goldReaction ? 1 : 0))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 19)
        #expect(events.contains { $0.abilityName == "Snatch" } == goldReaction)
    }

    @Test(arguments: [false, true])
    func `Blood Money grants Gold from lingering Bleed only while its wearer lives`(wearerDefeated: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "cutpurse_knife"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: wearerDefeated ? 0 : 20,
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.insertEffect(.bleed(4), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)

        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: battle.enemy, context: &battle) }

        #expect(battle.roster.enemy.currentHealth == 96)
        #expect(battle.gold == (wearerDefeated ? 0 : 1))
    }

    @Test(arguments: [false, true])
    func `Martial Guard rewards committed Thorns only after its wearer survives the incoming hit`(
        finallyDefeated: Bool,
    ) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "vanguards_crest"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1,
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
        #expect(battle.roster.hero.currentHealth == (finallyDefeated ? 0 : 1))
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == (finallyDefeated ? 0 : 4))
        #expect(outcome.events.contains {
            $0.abilityName == "Martial Guard" && $0.effectKind == .shieldApplied && $0.amount == 4
        } == !finallyDefeated)
    }

    @Test(arguments: [false, true])
    func `lethal retaliation during a Dodge reward stops later uncommitted rewards`(healsFromGold: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30, maxMana: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 1, heroMana: 0,
            companionModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.dodgeGoldFlat = healsFromGold ? 1 : 0
                $0.gainGoldBonusHealSelf = healsFromGold ? 1 : 0
                $0.dodgeHealFlat = healsFromGold ? 0 : 1
                $0.onHealDealHoly = 1
                $0.onDodgeGrantHeroBlock = 3
                $0.onDodgePartyMana = 2
                $0.onDodgeDrawCardForHero = 1
                $0.dodgeNextStunAttackBonus = 3
                $0.dodgeNextFreezeAttackBonus = 2
                $0.dodgeNextBleedAttackBonus = 2
                $0.dodgeBleedChancePercent = 1
                $0.dodgeBleedDamage = 2
                $0.dodgeBurnChancePercent = 1
                $0.dodgeBurnDamage = 2
                $0.dodgeApplyPoison = 2
                $0.onDodgeCounterDamage = 2
                $0.onDodgeApplyPoisonOrBleed = 2
                $0.onDodgeAttackerStunBuildup = 2
                $0.onDodgeDelayAttackerTurn = true
            }, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 3 }, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.heroDeck = CombatDeck(abilities: [.block])
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterDodge(
            by: battle.companion, attackerID: battle.enemy.id, in: &battle,
        ) }

        #expect(battle.health(of: battle.companion) == 0)
        #expect(battle.roster.companion.talents.pending.nextDodgeStunAttackBonus == nil)
        #expect(battle.roster.companion.talents.pending.nextDodgeFreezeAttackBonus == nil)
        #expect(battle.roster.companion.talents.pending.nextDodgeBleedAttackBonus == nil)
        #expect(battle.roster.hero.isAlive)
        #expect(battle.health(of: battle.enemy) == 100)
        // Only the committed healing's Holy ping can consume enemy Block.
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 19)
        #expect(battle.activeEffects(of: battle.enemy).allSatisfy { !$0.effect.isRemovableDebuff })
        #expect(battle.roster.enemy.talents.battle.actionDelays == 0)
        #expect(battle.mana(of: battle.hero) == (healsFromGold ? 0 : 2))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == (healsFromGold ? 0 : 3))
        #expect(battle.heroDeck.abilities.map(\.id) == (healsFromGold ? [Ability.block.id] : []))
        #expect(events.contains { $0.effectKind == .instantHeal && $0.targetID == battle.companion.id })
    }

    @Test func `a surviving Dodge winner still completes healing and ally card support`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1),
            companionHealth: 3, companionModifiers: .withTriggers {
                $0.onDodgeDrawAndPlayCardChainOnCrit = true
                $0.dodgeHealFlat = 2
                $0.criticalChanceBonus = -1
                $0.firstDodgeDrawForAlly = true
            }, appliesFightPacing: false,
        )
        battle.companionDeck = CombatDeck(abilities: [.stab])
        battle.heroDeck = CombatDeck(abilities: [.block])

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterDodge(
            by: battle.companion, attackerID: battle.enemy.id, in: &battle,
        ) }

        #expect(!battle.roster.enemy.isAlive)
        #expect(battle.health(of: battle.companion) == 5)
        #expect(battle.heroDeck.abilities.isEmpty)
        #expect(events.contains { $0.abilityName == "Tailwind" && $0.effectKind == .cardsDrawn })
    }

    @Test(arguments: ["Windfall", "Health is Wealth", "Golden Recovery"])
    func `Gold keeps its committed gain but stops later rewards when restoration kills its owner`(checkpoint: String) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1, companionHealth: 5,
            heroModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.onHealDealHoly = 1
                $0.gainGoldBonusHealSelf = checkpoint == "Windfall" ? 2 : 0
                $0.goldGainHealChancePercent = checkpoint == "Golden Recovery" ? 0 : 1
                $0.goldGainHealAmount = 2
                $0.onGainGoldHealParty = 2
            }, companionModifiers: .withTriggers { $0.blockPerGoldEarnedEvery = 1 },
            enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 4 }, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)

        let gain = battle.recordingResult { battle in await battle.grantGold(
            1, to: battle.hero, abilityName: "Gold",
        ) }

        #expect(gain.value == 1)
        #expect(battle.gold == 1)
        #expect(gain.events.contains { $0.keyword == .gold && $0.amount == 1 })
        #expect(!battle.roster.hero.isAlive)
        #expect(battle.health(of: battle.companion) == 5)
        #expect(!gain.events.contains { $0.effectKind == .instantHeal && $0.targetID == battle.companion.id })
        // The partner's own threshold still observes the Gold already earned.
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 1)
    }

    @Test func `Shared Spoils cannot trigger Gold restoration after its owner falls`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 5, companionHealth: 1,
            companionModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.onHealDealHoly = 1
                $0.goldTheftHealAllyFlat = 2
                $0.gainGoldBonusHealSelf = 2
                $0.onGainGoldHealParty = 2
            }, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 4 }, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)

        let gain = battle.recordingResult { battle in await battle.grantGold(
            1, to: battle.companion, abilityName: "Theft", isTheft: true,
        ) }

        #expect(gain.value == 1)
        #expect(!battle.roster.companion.isAlive)
        #expect(battle.health(of: battle.hero) == 7)
        #expect(gain.events.count(where: { $0.effectKind == .instantHeal }) == 1)
    }

    @Test func `Gold restoration that wins still finishes support rewards for a living owner`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1, companionHealth: 5, enemyHealth: 1,
            heroModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.gainGoldBonusHealSelf = 2
                $0.onHealDealHoly = 1
                $0.onGainGoldHealParty = 2
            }, appliesFightPacing: false,
        )

        battle.grantGoldEvent(1, to: battle.hero, abilityName: "Gold")

        #expect(battle.isEnemyDefeated)
        #expect(battle.roster.hero.isAlive)
        #expect(battle.health(of: battle.hero) == 5)
        #expect(battle.health(of: battle.companion) == 7)
    }
}
