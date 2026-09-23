import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `fae ward spends its first cleanse allowance even without another effect`() {
        var battle = capstoneBattle(companion: ["pixie_cleanse_t3_1"])
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 0)],
            for: battle.hero, on: &battle,
        )
        let first = CleanseOperation.resolve(
            .random, source: battle.companion, target: battle.hero,
            abilityName: "Cleanse", in: &battle,
        )
        #expect(first.removed.count == 1)

        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 2, effect: .burn(2), remainingTurns: 0),
                ActiveEffect(id: 3, effect: .bleed(2), remainingTurns: 0),
            ],
            for: battle.hero, on: &battle,
        )
        let second = CleanseOperation.resolve(
            .random, source: battle.companion, target: battle.hero,
            abilityName: "Cleanse", in: &battle,
        )
        #expect(second.removed.count == 1)
        #expect(battle.activeEffects(of: battle.hero).count(where: \.effect.isRemovableDebuff) == 1)
    }

    @Test func `fae swiftness clears freeze before fae ward chooses its extra effect`() {
        for seed in 0 ..< 8 {
            var battle = capstoneBattle(companion: ["pixie_cleanse_t2_1", "pixie_cleanse_t3_1"])
            battle.rng = SeededRandomNumberGenerator(seed: UInt64(seed))
            BattleStateTestFactory.seedActiveEffects(
                [
                    ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 0),
                    ActiveEffect(id: 2, effect: .controlMeter(.freeze, 3, 10), remainingTurns: 0),
                    ActiveEffect(id: 3, effect: .burn(2), remainingTurns: 0),
                ],
                for: battle.hero, on: &battle,
            )
            let result = CleanseOperation.resolve(
                .all(.poison), source: battle.companion, target: battle.hero,
                abilityName: "Cleanse", in: &battle,
            )
            #expect(result.removed.count == 3)
            #expect(battle.activeEffects(of: battle.hero).filter(\.effect.isRemovableDebuff).isEmpty)
        }
    }

    @Test func `critical miss preparations credit their own talent`() {
        for (talentID, keyword, abilityName) in [
            ("mana_moth_freeze_t2_1", Keyword.freeze, "Blinding Frost"),
            ("shield_scarab_holy_t3_1", .holy, "Dazzling Guard"),
        ] {
            var battle = capstoneBattle(companion: [talentID])
            let triggers = battle.companionModifiers.triggers
            _ = CombatTriggerEngine.afterFinalCompanionCardHit(
                keyword: keyword, actor: battle.companion, critical: true,
                triggers: triggers, in: &battle,
            )
            battle.roster.enemy.talents.pending.nextAttackMissChance = 1
            let avoided = CombatTriggerEngine.enemyAttackAvoidance(in: &battle)
            #expect(avoided.cancelled)
            #expect(avoided.events.first?.abilityName == abilityName)
            #expect(battle.roster.enemy.talents.pending.nextAttackMissAbilityName == nil)
        }
    }

    @Test func `pixie holy attacks bypass half block and unbroken vow bypasses all`() {
        var battle = capstoneBattle(companion: ["pixie_holy_t1_2", "pixie_holy_t4_1"])
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        let attack = DamageOperation.attack(
            scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
        )
        let first = battle.resolveDamage(DamageRequest(
            amount: 6, target: battle.enemy, keyword: .holy,
            sourceActorID: battle.companion.id, options: attack,
        ))
        #expect(first.healthLost == 1)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 5)

        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        DefensePoolEngine.set(2, on: battle.companion, in: &battle)
        let vow = battle.resolveDamage(DamageRequest(
            amount: 6, target: battle.enemy, keyword: .holy,
            sourceActorID: battle.companion.id, options: attack,
        ))
        #expect(vow.healthLost == 6)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 10)
    }

    @Test func `decoy swap dodges a whole enemy ability once`() {
        var profile = CombatantTalentCatalog.profile(for: ["fox_dodge_t3_1"])
        profile.triggers.swapAndDodgeForHeroChance = 1
        let attack = Ability(
            id: "double-strike", name: "Double Strike", tier: .basic,
            damageComponents: [DamageComponent(3, keyword: .physical), DamageComponent(4, keyword: .physical)],
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [attack], companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let heroHealth = battle.health(of: battle.hero)
        let companionHealth = battle.health(of: battle.companion)
        let result = BattleTurnEngine.performEnemyAction(
            ability: attack, abilityTarget: battle.hero, context: &battle,
        )
        #expect(!result.performed)
        #expect(result.events.count { $0.effectKind == .dodgeApplied } == 1)
        #expect(!result.events.contains { $0.kind == .abilityDamage })
        #expect(battle.health(of: battle.hero) == heroHealth)
        #expect(battle.health(of: battle.companion) == companionHealth)
    }

    @Test func `radiant shell reflects damage actually blocked as holy`() {
        var profile = CombatantTalentCatalog.profile(for: ["shield_scarab_holy_t1_2"])
        profile.triggers.blockHolyReflectChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(10, on: battle.companion, in: &battle)
        let enemyHealth = battle.health(of: battle.enemy)
        let result = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id, options: .attack(scaling: .flat, accuracy: .unavoidable),
        ))
        #expect(result.healthLost == 0)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 6)
        #expect(battle.health(of: battle.enemy) == enemyHealth - 4)
    }

    @Test func `sealed sarcophagus doubles block absorption without protecting block from purge`() {
        var battle = capstoneBattle(companion: ["shield_scarab_block_t4_1"])
        DefensePoolEngine.set(3, on: battle.companion, in: &battle)
        let result = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id, options: .reaction(),
        ))
        #expect(result.healthLost == 0)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 1)
        let purge = EffectHandlers.all[.purge]
        #expect(purge != nil)
        _ = purge?.apply(.purge(nil), ability: .cleanse, source: battle.enemy, target: battle.companion, in: &battle)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 0)
    }

    @Test func `lingering blessing repeats actual restoration once without chaining`() {
        var profile = CombatantTalentCatalog.profile(for: ["pixie_health_t2_1"])
        profile.triggers.healthRestorationRepeatNextTurnChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 1
        let first = battle.resolveHeal(HealRequest(
            amount: 3, target: battle.hero, sourceActorID: battle.companion.id,
        ))
        #expect(first.healthRestored == 3)
        #expect(battle.health(of: battle.hero) == 4)
        let next = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(battle.health(of: battle.hero) == 7)
        #expect(next.count { $0.abilityName == "Lingering Blessing" } == 1)
        let later = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(battle.health(of: battle.hero) == 7)
        #expect(!later.contains { $0.abilityName == "Lingering Blessing" })
    }

    @Test func `weaken soul reduces one enemy hit even when leech overheals`() {
        var battle = capstoneBattle(companion: ["risen_skeleton_leech_t1_1"])
        var leech = DamageOperation.attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1)
        leech.abilityHasLeech = true
        _ = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.companion.id, options: leech,
        ))
        let enemyHit = DamageRequest(
            amount: 8, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
        #expect(battle.resolveDamage(enemyHit).healthLost == 6)
        #expect(battle.resolveDamage(enemyHit).healthLost == 8)
    }

    @Test func `vital infusion restores once after crossing half health`() {
        var battle = capstoneBattle(companion: ["pixie_health_t3_1"])
        battle.roster.companion.currentHealth = 22
        let hit = DamageRequest(
            amount: 5, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id, options: .reaction(),
        )
        _ = battle.resolveDamage(hit)
        #expect(battle.health(of: battle.companion) == 23)
        battle.roster.companion.currentHealth = 22
        _ = battle.resolveDamage(hit)
        #expect(battle.health(of: battle.companion) == 17)
    }

    @Test func `marrowmend converts only the first excess leech each turn`() {
        var battle = capstoneBattle(companion: ["risen_skeleton_leech_t4_1"])
        var leech = DamageOperation.reaction()
        leech.abilityHasLeech = true
        let hit = DamageRequest(
            amount: 12, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.companion.id, options: leech,
        )
        _ = battle.resolveDamage(hit)
        let first = talentPoints(.shield, on: .companion, in: battle)
        #expect(first > 0)
        _ = battle.resolveDamage(hit)
        #expect(talentPoints(.shield, on: .companion, in: battle) == first)
        battle.turnCount += 1
        let third = battle.resolveDamage(hit)
        let reward = third.events.filter { $0.abilityName == "Marrowmend" }
        #expect(reward.count == 1)
        #expect(reward.first?.amount == 6)
        #expect(talentPoints(.shield, on: .companion, in: battle) == first + 6)
    }

    @Test func `light fingered steals enemy block only on a gold theft proc`() {
        var profile = CombatantTalentCatalog.profile(for: ["fox_gold_t4_1"])
        profile.triggers.goldTheftStealEnemyBlockChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(5, on: battle.enemy, in: &battle)
        _ = battle.grantGoldEvent(2, to: battle.companion, abilityName: "Gold")
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 5)
        _ = battle.grantGoldEvent(2, to: battle.companion, abilityName: "Steal", isTheft: true)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 0)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 5)
    }

    @Test func `arcane reservoir doubles a mana restoration on its proc`() {
        var profile = CombatantTalentCatalog.profile(for: ["mana_moth_mana_t1_1"])
        profile.triggers.manaRestorationDoubleChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 10, companionMana: 0,
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        _ = battle.restoreManaEmitting(2, to: battle.companion, abilityName: "Restore")
        #expect(battle.mana(of: battle.companion) == 4)
    }

    @Test func `mana empowerment damage talents do not add extra hits`() throws {
        func hit(talents: [String]) throws -> (damage: Int, hits: Int) {
            var profile = CombatantTalentCatalog.profile(for: Set(talents))
            profile.triggers.criticalChanceBonus = -1
            profile.triggers.manaEmpowerDamageChancePercent = talents.contains("mana_moth_mana_t3_2") ? 1 : 0
            var battle = BattleStateTestFactory.makeBattleWithAbilities(
                enemyMaxHealth: 100, companionMaxMana: 3, companionMana: 3,
                companionModifiers: profile, dealOpeningHand: false,
            )
            battle.appliesFightPacing = false
            let events = try playHeroTalentCard(.frostbolt, owner: .companion, in: &battle)
            let hits = events.filter { $0.kind == .abilityDamage && $0.keyword == .freeze }
            return (hits.reduce(0) { $0 + $1.amount }, hits.count)
        }
        let baseline = try hit(talents: [])
        let burst = try hit(talents: ["mana_moth_mana_t3_2"])
        let scales = try hit(talents: ["mana_moth_mana_t4_1"])
        #expect(baseline.hits == 1)
        #expect(burst.hits == 1)
        #expect(scales.hits == 1)
        #expect(burst.damage == CombatRounding.scaled(baseline.damage, multiplier: 1.5))
        #expect(scales.damage == CombatRounding.scaled(baseline.damage, multiplier: 1.25))
    }

    @Test func `stolen thunder prepares one critical attack when stun lands`() {
        var profile = CombatantTalentCatalog.profile(for: ["fox_stun_t4_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let threshold = ControlMeterEngine.threshold(for: battle.enemy, in: battle)
        _ = ControlMeterEngine.applyMeterCharge(
            threshold, keyword: .stun, to: battle.enemy,
            sourceActorID: battle.companion.id, applyFightPacing: false, in: &battle,
        )
        let attack = DamageRequest(
            amount: 2, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.companion.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
        #expect(battle.resolveDamage(attack).isCritical)
        #expect(!battle.resolveDamage(attack).isCritical)
    }
}
