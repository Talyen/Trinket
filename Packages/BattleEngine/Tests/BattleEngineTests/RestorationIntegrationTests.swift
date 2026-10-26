import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct RestorationIntegrationTests {
    @Test func `redirected Mana gains retain their provider in committed feedback`() throws {
        var companionProfile = CombatModifierProfile.zero
        companionProfile.triggerAbilityNames[.onDodgePartyMana] = "Skyward Gift"
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: 5), heroMana: 0,
            companionModifiers: companionProfile, appliesFightPacing: false,
        )

        let events = battle.recordingEvents { context in
            await CombatTriggerEngine.emitMana(
                .onDodgePartyMana, "Fallback Mana", amount: 2, to: context.hero,
                nameFrom: context.companion, in: &context,
            )
        }
        let manaEvent = try #require(events.first { $0.effectKind == .resourceGain && $0.keyword == .mana })

        #expect(manaEvent.actorID == battle.companion.id)
        #expect(manaEvent.targetID == battle.hero.id)
        #expect(manaEvent.abilityName == "Skyward Gift")
        #expect(manaEvent.amount == 2)
        #expect(battle.mana(of: battle.hero) == 2)
    }

    @Test(arguments: [0, 3, 10])
    func `healing reports overflow without inflating restoration`(missingHealth: Int) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
        )
        battle.roster.hero.currentHealth = battle.hero.maxHealth - missingHealth
        var request = HealRequest(
            amount: 10, target: battle.hero,
            logAs: .instantHeal(source: .init(battle.hero), abilityName: "Heal", keyword: .health),
        )
        request.amountBasis = .resolved

        let result = battle.recordingResult { context in await HealingEngine.resolveHealing(request, in: &context) }

        #expect(battle.health(of: battle.hero) == battle.hero.maxHealth)
        #expect(result.value.directRestoration == missingHealth)
        #expect(result.events.first { $0.effectKind == .instantHeal }?.amount == missingHealth)
        let overflow = result.events.filter { $0.effectKind == .overheal }
        #expect(overflow.map(\.amount) == (missingHealth < 10 ? [10 - missingHealth] : []))
    }

    @Test(arguments: [0, 3])
    func `leech logs only actual restoration while reporting overflow separately`(missingHealth: Int) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(), appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = battle.hero.maxHealth - missingHealth
        let result = battle.recordingResult { context in await HealingEngine.leechFromDamage(
            20, sourceActorID: context.hero.id, abilityHasLeech: true, in: &context,
        ) }
        #expect(result.value.healthDelta == missingHealth)
        #expect(result.value.flags.contains(.leeched) == (missingHealth > 0))
        #expect(result.events.first { $0.effectKind == .overheal }?.amount == 10 - missingHealth)
    }

    @Test(arguments: [
        (Ability(id: "heal", name: "Heal", tier: .basic, effects: [.instantHeal(.health, 3)]), 10),
        (Ability(id: "leech-slash", name: "Leech Slash", tier: .basic, directDamage: 2, hasLeech: true), 9),
    ])
    func `played healing and Leech cards restore actual missing Health`(ability: Ability, expectedHealth: Int) throws {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 10), heroHealth: 8,
            heroModifiers: .withTriggers { $0.criticalChanceBonus = -1 }, appliesFightPacing: false,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        let events = try battle.playCard(cardID: card.id).events
        #expect(battle.health(of: battle.hero) == expectedHealth)
        #expect(battle.health(of: battle.enemy) == (ability.hasLeech ? 98 : 100))
        #expect(events.contains {
            $0.effectKind == (ability.hasLeech ? .leechHeal : .instantHeal)
                && $0.keyword == (ability.hasLeech ? .leech : .health) && $0.amount == expectedHealth - 8
        })
    }

    @Test func `enemy instant heal restores health when below max`() {
        let selfHeal = Ability(
            id: "self-heal",
            name: "Self Heal",
            tier: .basic,
            description: "Restore 5 Health.",
            effects: [.instantHeal(.health, 5)],
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, abilities: [selfHeal]),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
        )
        battle.roster.enemy.currentHealth = 16
        let events = battle.endTurn().events
        #expect(events.contains { $0.effectKind == .instantHeal && $0.amount > 0 })
        #expect(battle.health(of: battle.enemy) >= 16)
    }

    @Test func `hero leech share skips zero-rounded shares instead of fabricating healing`() {
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: CombatModifierProfile.withTriggers { $0.companionLeechSharePercent = 0.1 },
            dealOpeningHand: false,
        )
        battle.roster.companion.currentHealth -= 5
        let healthBefore = battle.roster.companion.currentHealth
        let events = battle
            .recordingEvents { battle in await HealingEngine.shareLeechWithAlly(restored: 1, source: battle.hero, in: &battle) }
        #expect(events.isEmpty)
        #expect(battle.roster.companion.currentHealth == healthBefore)
    }

    @Test(arguments: [0, 1, 9, 10])
    func `overheal transfer consumes only recipient space before converting the remainder`(companionHealth: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 10, heroMaxMana: 10,
            heroModifiers: .withTriggers {
                $0.wishspring = true
                $0.overhealConvertsToBlock = true
                $0.leechOverhealTransfersToCompanion = true
            },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.companion.currentHealth = companionHealth
        battle.roster.hero.currentMana = 0
        var request = HealRequest(amount: 10, target: battle.hero, sourceActorID: battle.hero.id, origin: .leech, logAs: .silent)
        request.amountBasis = .resolved
        let result = battle.recordingResult { context in await HealingEngine.resolveHealing(request, in: &context) }
        let transferred = companionHealth > 0 ? 10 - companionHealth : 0
        #expect(result.value.allocation.transferred == transferred)
        #expect(result.value.allocation.block == 10 - transferred)
        #expect(result.value.allocation.remaining == 0)
        #expect(battle.roster.companion.currentHealth == (companionHealth > 0 ? 10 : 0))
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 10 - transferred)
        #expect(battle.roster.hero.currentMana == min(5, battle.roster.hero.maxMana))
    }

    @Test(arguments: [DamageOperation.healthCost, .periodic, .reaction(), .redirected])
    func `damage cap policy follows operation semantics`(operation: DamageOperation) {
        #expect(DamageDefensePolicy.cappedDamage(20, operation: operation, cap: 12) == (operation.isHealthCost ? 20 : 12))
        #expect(DamageDefensePolicy.cappedDamage(8, operation: operation, cap: 12) == 8)
    }

    @Test func `bounded gains cannot reduce an already capped value`() {
        #expect(CombatGain.amount(3, current: 3, cap: 4) == 1)
        #expect(CombatGain.amount(3, current: 5, cap: 4) == 0)
        #expect(CombatGain.amount(30, current: 0, cap: 10) == 10)
    }

    @Test func `aether shield waits for overflow remaining after blood link`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 20,
            heroModifiers: .withTriggers {
                $0.leechOverhealTransfersToCompanion = true
                $0.overhealFirstBlockPerTurn = 3
            },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.companion.currentHealth = 10
        var request = HealRequest(amount: 10, target: battle.hero, sourceActorID: battle.hero.id, origin: .leech, logAs: .silent)
        request.amountBasis = .resolved
        _ = CombatExecutor.run { await HealingEngine.resolveHealing(request, in: &battle) }
        #expect(battle.roster.companion.currentHealth == 20)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 0)
        _ = CombatExecutor.run { await HealingEngine.resolveHealing(request, in: &battle) }
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 3)
    }
}

extension RestorationIntegrationTests {
    @Test func `sprite touch does not increase resolved healing or spend its allowance`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            heroHealth: 10, companionHealth: 10,
            companionModifiers: CombatantTalentCatalog.profile(for: ["pixie_health_t1_1"]), appliesFightPacing: false,
        )
        var transfer = HealRequest(amount: 3, target: battle.hero, sourceActorID: battle.companion.id)
        transfer.amountBasis = .resolved

        let transferred = battle.resolveHeal(transfer)
        let fresh = battle.resolveHeal(HealRequest(amount: 3, target: battle.hero, sourceActorID: battle.companion.id))

        #expect(transferred.healthRestored == 3)
        #expect(fresh.healthRestored == 5)
        #expect(battle.health(of: battle.hero) == 18)
    }

    @Test func `barrier blessing converts overflow without scaling Block again`() {
        var profile = CombatantTalentCatalog.profile(for: ["pixie_health_t3_2"])
        profile.blockGainedBonus = 7
        profile.blockGainedPercent = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            heroModifiers: profile, appliesFightPacing: false,
        )
        var request = HealRequest(amount: 4, target: battle.hero, sourceActorID: battle.hero.id)
        request.amountBasis = .resolved

        let result = CombatExecutor.run { await HealingEngine.resolveHealing(request, in: &battle) }

        #expect(result.allocation.block == 4)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 4)
    }
}
