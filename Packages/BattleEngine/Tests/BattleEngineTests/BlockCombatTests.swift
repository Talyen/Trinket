import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BlockCombatTests {
    @Test(arguments: [(3, 0, 3), (5, 0, 5), (3, 2, 5), (5, Int.max, Int.max)])
    func `intercepted attacks refund only paid Block while preserving nested gains`(
        startingBlock: Int,
        nestedBlock: Int,
        expectedBlock: Int,
    ) {
        let attack = Ability(
            id: "block-cost-attack", name: "Block Cost Attack", tier: .basic,
            damageComponents: [DamageComponent(1)], blockCost: 3,
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [attack],
            heroModifiers: .withTriggers { $0.onDodgeDrawAndPlayCardChainOnCrit = nestedBlock > 0 },
            companionModifiers: CombatantTalentCatalog.profile(for: ["golden_retriever_block_t2_2"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(startingBlock, on: battle.enemy, in: &battle)
        if nestedBlock > 0 {
            // A supported automatic support card grants Block during Warning Bark's Dodge reactions.
            battle.heroDeck = CombatDeck(abilities: [Ability(
                id: "interception-block", name: "Interception Block", tier: .basic,
                targetedEffects: [TargetedEffect(.shield(.block, nestedBlock), target: .enemy)],
            )])
        }

        let events = battle.recordingEvents { battle in
            _ = await BattleTurnEngine.performEnemyAction(ability: attack, abilityTarget: battle.hero, context: &battle)
        }

        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == expectedBlock)
        #expect(battle.health(of: battle.hero) == battle.hero.maxHealth)
        #expect(events.contains { $0.abilityName == "Warning Bark" && $0.effectKind == .dodgeApplied })
        #expect(!events.contains { $0.effectKind == .blockSpent })
        if nestedBlock > 0 {
            #expect(events.contains { $0.abilityID == "interception-block" })
        }
    }

    @Test func `enemy Block-cost attack requires full payment before acting`() {
        let attack = Ability(
            id: "block-cost-attack", name: "Block Cost Attack", tier: .basic,
            damageComponents: [DamageComponent(1)], blockCost: 3,
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [attack],
            companionModifiers: .withTriggers { $0.onEnemyAbilityGold = 5 },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(1, on: battle.enemy, in: &battle)
        var performed = true
        let events = battle.recordingEvents { battle in
            performed = await BattleTurnEngine.performEnemyAction(ability: attack, abilityTarget: battle.hero, context: &battle)
        }

        #expect(!performed)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 1)
        #expect(battle.health(of: battle.hero) == battle.hero.maxHealth)
        #expect(!events.contains { $0.effectKind == .blockSpent })
        #expect(!events.contains { $0.kind == .ability && $0.abilityID == attack.id })

        let turnEvents = battle.recordingEvents { battle in
            await BattleCardCombatEngine.resolveEnemyTurn(context: &battle)
        }
        #expect(!turnEvents.contains { $0.abilityName == "Fetch!" })
    }

    @Test func `player Block-cost card is denied without spending partial Block`() throws {
        let ability = Ability(
            id: "block-cost-slash", name: "Block Cost Slash", tier: .basic,
            damageComponents: [DamageComponent(1)], blockCost: 3,
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        DefensePoolEngine.set(1, on: battle.hero, in: &battle)
        battle.hand = BattleHand()
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)

        #expect(battle.assessCard(card).denial == .insufficientBlock)
        #expect(throws: BattlePlayError.insufficientBlock) { try battle.playCard(cardID: card.id) }
        #expect(battle.hand.card(id: card.id) != nil)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 1)
    }

    @Test(arguments: [0, -1])
    func `nonpositive Block requests do not create bonus Block or spend the next gain`(amount: Int) {
        var profile = CombatModifierProfile.zero
        profile.blockGainedBonus = 7
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companionModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.companion.talents.pending.nextBlockGainMultiplier = PreparedTalentBonus(value: 2)

        let events = battle.recordingEvents { state in
            let applied = state.applyBlockGain(amount, to: state.companion, source: state.companion, abilityName: "Empty gain")
            #expect(applied == 0)
        }

        #expect(events.isEmpty)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == 0)
        #expect(battle.roster.companion.talents.pending.nextBlockGainMultiplier?.value == 2)
        let later = battle.applyBlockGain(1, to: battle.companion, source: battle.companion, abilityName: "Positive gain")
        #expect(later == 16)
        #expect(battle.roster.companion.talents.pending.nextBlockGainMultiplier == nil)
    }

    @Test(arguments: [false, true], [0, 7])
    func `Block theft reports only actual loss while preserving protected pools`(protected: Bool, block: Int) {
        var battle = BattleStateTestFactory.makeBattle(
            companionModifiers: .withTriggers { $0.goldTheftStealEnemyBlockChancePercent = 1 },
            enemyModifiers: .withTriggers { $0.sealedSarcophagus = protected },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let events = battle.recordingEvents { state in
            _ = await state.grantGold(2, to: state.companion, abilityName: "Steal", isTheft: true)
        }
        let stolen = protected ? 0 : block
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == block - stolen)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == stolen)
        let losses = events.filter { $0.effectKind == .blockStripped }
        #expect(losses.map(\.amount) == (stolen > 0 ? [stolen] : []))
        #expect(losses
            .allSatisfy { $0.actorID == battle.companion.id && $0.targetID == battle.enemy.id && $0.abilityName == "Light-Fingered" })
        #expect(!events.contains { $0.effectKind == .shieldAbsorbed })
    }

    @Test(arguments: [0, 7])
    func `Sunder Shield reports stripped Block without absorption`(block: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["shield_scarab_stun_t1_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let events = battle.chargeTestControl(
            ControlMeterEngine.threshold(for: battle.enemy, in: battle), keyword: .stun,
            to: battle.enemy, sourceActorID: battle.companion.id, applyFightPacing: false,
        )
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 0)
        let losses = events.filter { $0.effectKind == .blockStripped }
        #expect(losses.map(\.amount) == (block > 0 ? [block] : []))
        #expect(losses
            .allSatisfy { $0.actorID == battle.companion.id && $0.targetID == battle.enemy.id && $0.abilityName == "Sunder Shield" })
        #expect(!events.contains { $0.effectKind == .shieldAbsorbed })
    }

    @Test func `preventing new Block does not erase retained or spent Block`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        DefensePoolEngine.set(12, on: battle.enemy, in: &battle)
        battle.roster.enemy.talents.turn.blockGainPrevented = true

        #expect(DefensePoolEngine.halveBlock(on: battle.enemy, in: &battle))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 6)
        DefensePoolEngine.decayBlock(on: battle.enemy, in: &battle)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 3)
        #expect(battle.applyBlockGain(4, to: battle.enemy, source: battle.enemy, abilityName: "Blocked gain") == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 3)
    }

    @Test func `resolved enemy Block does not repeat Burning gain reduction`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: .withTriggers { $0.burningEnemyBlockGainMultiplier = 0.5 }, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.insertEffect(.burn(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)

        let resolved = battle.applyBlockGain(
            8, to: battle.enemy, source: battle.enemy, abilityName: "Resolved gain", amountBasis: .resolved,
        )
        let base = battle.applyBlockGain(8, to: battle.enemy, source: battle.enemy, abilityName: "Base gain")
        #expect(resolved == 8)
        #expect(base == 4)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 12)
    }

    @Test func `Laughing Guard breaking enemy Block prepares the next Critical Hit`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_physical_t2_2"])
        let laughingGuard = try #require(GameContent.unique(matching: "laughing_guard")?.affixPowers?.first)
        profile.triggers.merge(laughingGuard.triggers)
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash], heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(8, on: battle.hero, in: &battle)
        DefensePoolEngine.set(2, on: battle.enemy, in: &battle)

        CombatExecutor.run { await UniqueCombatEngine.afterUniqueDodge(by: battle.hero, attackerID: battle.enemy.id, in: &battle) }

        #expect(DefensePoolEngine.blockPoints(in: battle.roster.enemy.activeEffects) == 0)
        #expect(battle.roster.hero.talents.pending.nextAttackGuaranteedCritical != nil)
        let card = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        let events = try battle.playCard(cardID: card.id).events
        #expect(events.contains { $0.kind == .abilityDamage && $0.abilityID == Ability.slash.id && $0.isCritical })
        #expect(battle.roster.hero.talents.pending.nextAttackGuaranteedCritical == nil)
    }

    @Test func `Block break preparation waits for the next card rather than a later hit`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_physical_t2_2"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(1, on: battle.enemy, in: &battle)
        let twoHits = Ability(
            id: "two-physical-hits", name: "Two Physical Hits", tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical), DamageComponent(2, keyword: .physical)],
        )
        let card = BattleCardCombatEngine.deal(twoHits, owner: .hero, context: &battle)
        let creating = try battle.playCard(cardID: card.id).events
        #expect(creating.filter { $0.kind == .abilityDamage }.allSatisfy { !$0.isCritical })
        #expect(battle.roster.hero.talents.pending.nextAttackGuaranteedCritical != nil)
        let next = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        let consuming = try battle.playCard(cardID: next.id).events
        #expect(consuming.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(battle.roster.hero.talents.pending.nextAttackGuaranteedCritical == nil)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `owned and borrowed Block spend all stacks before breaking the pool`(target: BattleParticipant) throws {
        let profile = CombatModifierProfile.withTriggers {
            $0.blockAbsorbsCompanionDamage = true
            $0.seismicReversal = true
            $0.criticalChanceBonus = -1
        }
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.setActiveEffects([
            ActiveEffect(id: 100, effect: .shield(.block, 2), remainingTurns: 0, sourceActorID: battle.hero.id),
            ActiveEffect(id: 101, effect: .shield(.block, 3), remainingTurns: 0, sourceActorID: battle.companion.id),
        ], for: battle.hero)

        func hit(_ amount: Int, in battle: inout BattleState) -> CombatOutcome {
            battle.resolveTestDamage(
                amount, to: battle.roster[target].combatant, keyword: .physical,
                sourceActorID: battle.enemy.id,
                options: .attack(scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
            )
        }

        #expect(hit(3, in: &battle).healthLost == 0)
        let retained = try #require(battle.activeEffects(of: battle.hero).first { $0.effect.kind == .shield })
        #expect(retained.id == 101)
        #expect(retained.sourceActorID == battle.companion.id)
        #expect(retained.effect == .shield(.block, 2))
        #expect(battle.health(of: battle.enemy) == 100)

        #expect(hit(2, in: &battle).healthLost == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 0)
        #expect(battle.health(of: battle.enemy) == 98)
        #expect(hit(1, in: &battle).healthLost == 1)
    }

    @Test func `Watchful Guard protects the opening round and grants once on the next round`() throws {
        let definition = try #require(GameContent.enemy(matching: "living_armor"))
        let build = CombatBuildResolver.build(enemy: definition)
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 50),
            enemy: build.combatant,
            enemyModifiers: build.modifiers,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.drawOpeningHand(rebuildLog: false)

        #expect(BattleTestFixtures.shieldPoints(for: battle.enemy, in: battle) == 1)
        #expect(battle.events.count(where: { $0.abilityName == "Watchful Guard" }) == 1)
        let hit = battle.resolveTestDamage(1, options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1))
        #expect(hit.healthLost == 0)
        #expect(BattleTestFixtures.shieldPoints(for: battle.enemy, in: battle) == 0)

        let events = battle.endTurn(rebuildLog: false).events
        #expect(battle.turnCount == 1)
        #expect(events.count(where: { $0.abilityName == "Watchful Guard" }) == 1)
    }

    @Test func `opening round Block skips defeated owners`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.blockPerTurn = 1
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: profile,
            companionModifiers: profile,
            enemyModifiers: profile,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 0 }
        battle.drawOpeningHand(rebuildLog: false)

        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 1)
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 0)
        #expect(BattleTestFixtures.shieldPoints(for: battle.enemy, in: battle) == 1)
    }
}
