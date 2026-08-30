import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct BoonBattleTests {
    @Test func `offer uses only party affinities and selected boons do not repeat`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash],
            companionAbilities: [.fireArrow],
            enemyMaxHealth: 100,
            dealOpeningHand: false,
        )

        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.enemy) { $0.currentHealth = 20 }
            BoonEngine.enqueueCrossedThresholds(in: &context)
        }

        let firstOffer = try #require(battle.pendingBoonOffer)
        try #expect(firstOffer.threshold == BoonThreshold.eightyPercent)
        try #expect(firstOffer.choices.allSatisfy {
            Set<Keyword>($0.boon.category.keywords).isSubset(of: Set<Keyword>([.physical, .burn]))
        })
        let selectedID = firstOffer.choices[0].id
        try #expect(battle.selectBoon(id: selectedID))
        try #expect(battle.activeBoons.map(\.id) == [selectedID])
        try #expect(battle.pendingBoonOffer?.threshold == BoonThreshold.half)
        try #expect(battle.pendingBoonOffer?.choices.contains(where: { $0.id == selectedID }) == false)
    }

    @Test func `physical poison boon deals poison damage and creates poison`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash],
            enemyMaxHealth: 100,
            dealOpeningHand: false,
        )
        let boon = try #require(BoonCatalog.boon(id: "toxic-transfusion"))
        battle.activeBoons = [ActiveBoon(boon: boon)]

        battle.withEngineContext { context in
            _ = context.resolveDamage(DamageRequest(
                amount: 10,
                target: context.enemy,
                keyword: .physical,
                sourceActorID: context.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false),
            ))
        }

        try #expect(battle.health(of: battle.enemy) == 85)
        try #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.keyword == Keyword.poison })
    }

    @Test func `critical detonations ignore normal hits then consume the status on critical`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 100, dealOpeningHand: false)
        battle.activeBoons = try [activeBoon("backdraft")]
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(6), remainingTurns: 0, sourceActorID: battle.hero.id)],
            for: battle.enemy,
            on: &battle,
        )

        resolveDamage(1, keyword: .physical, guaranteedCritical: false, in: &battle)

        try #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.keyword == .burn })
        let healthBeforeCritical = battle.health(of: battle.enemy)

        resolveDamage(1, keyword: .physical, guaranteedCritical: true, in: &battle)

        try #expect(battle.health(of: battle.enemy) == healthBeforeCritical - 8)
        try #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.keyword == .burn })
    }

    @Test func `unconditional detonation consumes burn without reapplying it`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 100, dealOpeningHand: false)
        battle.activeBoons = try [activeBoon("steam-explosion")]
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(5), remainingTurns: 0, sourceActorID: battle.hero.id)],
            for: battle.enemy,
            on: &battle,
        )

        resolveDamage(2, keyword: .freeze, in: &battle)

        try #expect(battle.health(of: battle.enemy) == 93)
        try #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.keyword == .burn })
    }

    @Test func `blocked holy damage bypasses dodge and block while source has block`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 100, dealOpeningHand: false)
        battle.activeBoons = try [activeBoon("unbroken-vow")]
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
            for: battle.hero,
            on: &battle,
        )
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 2, effect: .shield(.block, 20), remainingTurns: 0),
                ActiveEffect(id: 3, effect: .evadeNextHit, remainingTurns: 0),
            ],
            for: battle.enemy,
            on: &battle,
        )

        resolveDamage(10, keyword: .holy, applyDodge: true, in: &battle)

        try #expect(battle.health(of: battle.enemy) == 90)
        try #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == .shield(.block, 20) })
        try #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == .evadeNextHit })
    }

    @Test func `mana and cleanse boons resolve their resource reactions`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 50,
            enemyMaxHealth: 100,
            heroMaxMana: 10,
            heroMana: 0,
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.activeBoons = try [activeBoon("closed-circuit"), activeBoon("eye-of-the-storm"), activeBoon("purifying-waters")]
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.hero) { $0.currentHealth = 30 }
            _ = BoonCombatEngine.afterManaSpent(3, by: context.hero, in: &context)
            _ = BoonCombatEngine.afterCleanse(2, source: context.hero, target: context.hero, in: &context)
        }

        try #expect(battle.health(of: battle.enemy) == 97)
        try #expect(battle.mana(of: battle.hero) == 3)
        try #expect(battle.health(of: battle.hero) == 38)
    }

    @Test func `overheal cleanses one debuff without recursing`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.activeBoons = try [activeBoon("clean-slate"), activeBoon("purifying-waters")]
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2, sourceActorID: battle.enemy.id)],
            for: battle.hero,
            on: &battle,
        )

        battle.withEngineContext { context in
            _ = context.resolveHeal(HealRequest(amount: 5, target: context.hero, sourceActorID: context.hero.id))
        }

        try #expect(!battle.activeEffects(of: battle.hero).contains(where: \.effect.isBleed))
        try #expect(battle.boonRuntime.resolvingBoonIDs.isEmpty)
    }

    @Test func `primed repeat plays the matching card once and clears its guard`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 100, dealOpeningHand: false)
        battle.activeBoons = try [activeBoon("furnace-rhythm")]
        battle.withEngineContext { context in
            _ = BoonCombatEngine.afterCardPlayed(.fireArrow, actor: context.hero, target: context.enemy, in: &context)
            #expect(context.boonRuntime.primedRepeatKeywords == [.physical])
            _ = BoonCombatEngine.afterCardPlayed(.slash, actor: context.hero, target: context.enemy, in: &context)
        }

        try #expect(battle.health(of: battle.enemy) < 100)
        try #expect(battle.boonRuntime.primedRepeatKeywords.isEmpty)
        try #expect(battle.boonRuntime.resolvingBoonIDs.isEmpty)
    }

    @Test func `partial freeze buildup does not decay at turn end`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.withEngineContext { context in
            _ = ControlMeterEngine.applyMeterCharge(
                4,
                keyword: .freeze,
                to: context.enemy,
                sourceActorID: context.hero.id,
                applyFightPacing: false,
                in: &context,
            )
        }
        let before = battle.activeEffects(of: battle.enemy)
        _ = battle.endTurn()
        let after = battle.activeEffects(of: battle.enemy)
        try #expect(after.first(where: { $0.effect.keyword == .freeze })?.effect == before.first(where: { $0.effect.keyword == .freeze })?
            .effect)
    }

    private func activeBoon(_ id: String) throws -> ActiveBoon {
        try ActiveBoon(boon: #require(BoonCatalog.boon(id: id)))
    }

    private func resolveDamage(
        _ amount: Int,
        keyword: Keyword,
        applyDodge: Bool = false,
        guaranteedCritical: Bool = false,
        in battle: inout BattleState,
    ) {
        battle.withEngineContext { context in
            _ = context.resolveDamage(DamageRequest(
                amount: amount,
                target: context.enemy,
                keyword: keyword,
                sourceActorID: context.hero.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: applyDodge,
                    guaranteedCritical: guaranteedCritical,
                ),
            ))
        }
    }
}
