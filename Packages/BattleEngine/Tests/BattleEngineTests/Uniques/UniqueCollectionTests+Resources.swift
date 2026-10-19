import Testing
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

extension UniqueCollectionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `winter credit pays shortfall before mana rewards and triggers final spark`(owner: BattleParticipant) throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.spendManaBlockFlat = 2
        extra.triggers.blockBrokenBlockFlat = 50
        var context = try battle(["winters_credit", "the_final_spark", "the_knights_answer"], owner: owner, extra: extra)
        context.roster.mutateRuntime(for: context.roster[owner].combatant) { $0.currentMana = 2 }
        block(3, owner: owner, in: &context)
        let events = try play(attack(.freeze), owner: owner, in: &context)
        #expect(context.roster[owner].currentMana == 0)
        #expect(blockAmount(owner, in: context) == 2)
        #expect(context.roster.enemy.currentHealth == 1978)
        #expect(events.count(where: { $0.abilityName == "The Final Spark" }) == 1)
        #expect(context.roster[owner].uniques.answeredBlock != true)
    }

    @Test func `block only empowerment does not spend mana allowances or draw opposite element`() throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.spendManaBlockFlat = 2
        extra.triggers.drawOnSpendMana = 1
        extra.triggers.blockBrokenBlockFlat = 50
        var context = try battle(["winters_credit", "the_final_spark", "twin_casting"], extra: extra)
        context.heroDeck = CombatDeck(abilities: [attack(.burn, id: "opposite")])
        block(9, owner: .hero, in: &context)
        let events = try play(attack(.freeze), in: &context)
        #expect(context.roster.hero.currentMana == 0)
        #expect(blockAmount(.hero, in: context) == 0)
        #expect(context.roster.enemy.currentHealth == 1989)
        #expect(context.hand.isEmpty)
        #expect(!events.contains { $0.abilityName == "The Final Spark" })
        #expect(context.roster[.hero].uniques.usedFinalSpark != true)
        #expect(context.turnCadence.spendManaDrawOwners.isEmpty)
    }

    @Test(arguments: [Keyword.freeze, .burn])
    func `unavailable empowerment preserves both resources and still plays card`(keyword: Keyword) throws {
        var context = try battle(["winters_credit", "the_final_spark"])
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 2 }
        block(keyword == .freeze ? 2 : 100, owner: .hero, in: &context)
        let before = blockAmount(.hero, in: context)
        try play(attack(keyword), in: &context)
        #expect(context.roster.hero.currentMana == 2)
        #expect(blockAmount(.hero, in: context) == before)
        #expect(context.roster.enemy.currentHealth == 1990)
        #expect(context.roster[.hero].uniques.usedFinalSpark != true)
    }

    @Test func `final spark qualifies before refunds and does not repeat utility`() throws {
        var context = try battle(["the_final_spark"], extra: .withTriggers { $0.spendManaRefundChancePercent = 1 })
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 3 }
        let spell = Ability(
            id: "spell",
            name: "spell",
            tier: .basic,
            directDamage: 10,
            damageKeyword: .burn,
            effects: [.shield(.block, 3)],
            criticalChanceBonus: -1,
        )
        let first = try play(spell, in: &context)
        #expect(context.roster.hero.currentMana == 3)
        #expect(blockAmount(.hero, in: context) == 3)
        #expect(context.roster.enemy.currentHealth == 1978)
        #expect(first.count(where: { $0.abilityName == "The Final Spark" }) == 1)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 3 }
        let second = try play(spell, in: &context)
        #expect(!second.contains { $0.abilityName == "The Final Spark" })
        #expect(context.roster.enemy.currentHealth == 1967)
        UniqueCombatEngine.startTurn(in: &context)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 3 }
        let third = try play(spell, in: &context)
        #expect(third.count(where: { $0.abilityName == "The Final Spark" }) == 1)
    }

    @Test(arguments: [Ability.blizzard])
    func `final spark repeats only initial recurring damage without attack rewards`(ability: Ability) throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.onAttackStealGold = 5
        var ordinary = try battle([], extra: extra)
        var spark = try battle(["the_final_spark", "everkeen"], extra: extra)
        ordinary.roster.mutateRuntime(for: ordinary.roster.hero.combatant) { $0.currentMana = 3 }
        spark.roster.mutateRuntime(for: spark.roster.hero.combatant) { $0.currentMana = 3 }
        try play(ability, critical: true, in: &ordinary)
        let events = try play(ability, critical: true, in: &spark)
        let initialDamage = 2000 - ordinary.roster.enemy.currentHealth
        #expect(initialDamage > 0)
        #expect(2000 - spark.roster.enemy.currentHealth == initialDamage * 2)
        #expect(events.count(where: { $0.abilityName == "The Final Spark" }) == 1)
        #expect(!events.contains { $0.isCritical })
        #expect(spark.gold == ordinary.gold)
        #expect(spark.roster.hero.currentMana == 0)
        let recurring = spark.roster.enemy.activeEffects.filter { $0.effect.kind == .recurringDamage }
        let original = ordinary.roster.enemy.activeEffects.filter { $0.effect.kind == .recurringDamage }
        #expect(recurring.map(\.effect) == original.map(\.effect))
        #expect(recurring.map(\.remainingTurns) == original.map(\.remainingTurns))
        #expect(events.count(where: { $0.effectKind == .recurringDamageApplied }) == 1)
        for _ in 0 ..< 3 {
            CombatExecutor.run { await EffectTurnEngine.advanceAll(context: &ordinary) }
            let ticks = spark.recordingEvents { spark in await EffectTurnEngine.advanceAll(context: &spark) }
            #expect(ordinary.roster.enemy.currentHealth - spark.roster.enemy.currentHealth == initialDamage)
            #expect(!ticks.contains { $0.abilityName == "The Final Spark" })
        }
    }

    @Test func `free empowerment cannot trigger mana spend rewards or final spark`() throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.empowermentCostReduction = 3
        extra.triggers.spendManaBlockFlat = 2
        var context = try battle(["the_final_spark"], extra: extra)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 3 }
        try play(attack(.burn), in: &context)
        #expect(context.roster.hero.currentMana == 3)
        #expect(blockAmount(.hero, in: context) == 0)
        #expect(context.roster.enemy.currentHealth == 1989)
        #expect(context.roster[.hero].uniques.usedFinalSpark != true)
    }

    @Test func `final spark and everkeen do not recursively repeat`() throws {
        var context = try battle(["the_final_spark", "everkeen"])
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 3 }
        // Everkeen requires Physical Crits while Final Spark requires empowered Burn/Freeze,
        // so a Physical Crit repeats once via Everkeen without triggering Final Spark.
        let events = try play(attack(.physical), critical: true, in: &context)
        #expect(events.count(where: { $0.abilityName == "Everkeen" }) == 1)
        #expect(events.count(where: { $0.abilityName == "The Final Spark" }) == 0)
        #expect(context.resolution.depth(.uniqueReaction) == 0)
    }

    @Test func `crucible stores actual gains but not starting gold or other owners gold`() throws {
        let current = try #require(GameContent.unique(matching: "the_golden_crucible"))
        let signature = try #require(current.affixPowers?.first)
        let owned = InventoryItem(
            id: "saved-crucible", templateID: current.templateID, baseType: current.baseType,
            rarity: current.rarity, displayName: current.displayName, affixes: current.affixes,
            affixPowers: [ItemAffixPower(
                description: "Gold gained in combat adds equal damage to your next Holy hit.",
                modifiers: signature.modifiers, triggers: signature.triggers,
            )],
        )
        let power = try #require(owned.resolvedPower(at: 0))
        #expect(current.displayedAffixes.first?.description.contains("manually played card") == true)
        #expect(owned.displayedAffixes.first?.description.contains("manually played card") == true)
        var profile = CombatModifierProfile(goldGainedBonus: 2)
        profile.merge(power.modifiers)
        power.triggers.apply(to: &profile)
        var context = try battle([], extra: profile)
        context.gold = 100
        try play(attack(.holy), in: &context)
        #expect(context.roster.enemy.currentHealth == 1990)
        context.grantGoldEvent(3, to: context.roster.companion.combatant, abilityName: "Other")
        #expect(context.roster[.hero].uniques.goldDamage == 0)
        context.grantGoldEvent(3, to: context.roster.hero.combatant, abilityName: "Grant")
        #expect(context.roster[.hero].uniques.goldDamage == 5)
        _ = context.resolveTestDamage(
            1,
            to: context.roster.enemy.combatant,
            keyword: .holy,
            sourceActorID: context.roster.hero.id,
            options: .reaction(),
        )
        #expect(context.roster[.hero].uniques.goldDamage == 5)
        #expect(context.effectSummaries(of: context.hero).contains {
            $0.keyword == .holy && $0.text.contains("manually played card") && $0.text.contains("5")
        })
        try play(attack(.holy), in: &context)
        #expect(context.roster.enemy.currentHealth == 1974)
        #expect(context.roster[.hero].uniques.goldDamage == 0)
        #expect(!context.effectSummaries(of: context.hero).contains { $0.text.contains("The Golden Crucible") })
    }

    @Test func `crucible gold from holy hit prepares next hit`() throws {
        var context = try battle(["the_golden_crucible"], extra: .withTriggers { $0.onAttackStealGold = 2 })
        context.grantGoldEvent(5, to: context.roster.hero.combatant, abilityName: "Grant")
        try play(attack(.holy), in: &context)
        #expect(context.roster.enemy.currentHealth == 1985)
        #expect(context.roster[.hero].uniques.goldDamage == 2)
        try play(attack(.holy), in: &context)
        #expect(context.roster.enemy.currentHealth == 1973)
        #expect(context.roster[.hero].uniques.goldDamage == 2)
    }

    @Test(arguments: [false, true])
    func `winter credit funds every affordable Freeze empowerment without mana capacity`(repeats: Bool) throws {
        var context = try battle(["winters_credit"])
        let knight = try #require(GameContent.hero(matching: "knight"))
        let wearer = Combatant(
            id: context.roster.hero.id,
            name: knight.name,
            role: .hero,
            maxHealth: knight.maxHealth,
            abilities: [attack(.freeze)],
        )
        context.roster.hero = CombatantRuntime(combatant: wearer)
        #expect(context.roster.hero.maxMana == 0)
        block(repeats ? 27 : 9, owner: .hero, in: &context)
        var ability = Ability(
            id: "freeze", name: "Freeze", tier: .basic,
            directDamage: 10, damageKeyword: .freeze, repeatsManaEmpowerment: repeats,
        )
        CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability,
            actor: wearer,
            context: &context,
        ) }
        #expect(blockAmount(.hero, in: context) == 0)
        #expect(ability.damageComponents.first?.amount == (repeats ? 13 : 11))
    }

    @Test(arguments: [
        (Keyword.burn, DamageOperation.resolvedPeriodic),
        (.freeze, .periodic),
        (.holy, .reaction()),
        (.holy, .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1)),
    ], [BattleParticipant.hero, .companion])
    func `Threefold rewards each qualifying elemental damage packet once`(
        packet: (Keyword, DamageOperation),
        owner: BattleParticipant,
    ) throws {
        var context = try battle(
            ["threefold_grace"],
            owner: owner,
            extra: .withTriggers { $0.threefoldElementalDamageManaChancePercent = 0.90 },
        )
        let source: BattleParticipant = owner == .hero ? .companion : .hero
        let outcome = context.recordingResult { context in context.resolveTestDamage(
            5,
            to: context.roster.enemy.combatant,
            keyword: packet.0,
            sourceActorID: context.roster[source].id,
            options: packet.1,
        ) }

        #expect(outcome.value.healthLost == 5)
        #expect(context.roster[owner].currentMana == 1)
        #expect(context.roster[source].currentMana == 0)
        #expect(outcome.events.count { $0.abilityName == "Threefold Grace" && $0.keyword == .mana } == 1)
    }

    @Test func `Last Wager rewards a counterattack once across critical Gold and theft`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_gold_t3_1"])
        let fortunateStrike = try #require(GameContent.itemAffixDefinition(matching: "lucky_clover"))
        fortunateStrike.basic.triggers.apply(to: &profile, abilityName: fortunateStrike.title)
        profile.triggers.criticalChanceBonus = 1
        var context = try battle(["the_knights_answer"], extra: profile, heroBasic: .blackjack)
        context.roster.hero.currentHealth = 50
        context.heroDeck = CombatDeck(abilities: [.slash, .block, .maul])
        let threshold = ControlMeterEngine.threshold(for: context.enemy, in: context)
        context.insertEffect(
            .controlMeter(.stun, threshold - 1, threshold), to: context.enemy,
            sourceID: context.hero.id, remainingTurns: 0,
        )
        block(5, owner: .hero, in: &context)

        let hit = context.recordingResult { context in self.enemyHit(1, in: &context) }

        #expect(context.gold == 4)
        #expect(hit.events.count { $0.effectKind == .cardsDrawn && $0.abilityName == "Last Wager" } == 1)
        #expect(context.hand.cards.map(\.ability.id) == [Ability.slash.id])

        context.grantGoldEvent(1, to: context.hero, abilityName: "Separate reward")
        #expect(context.hand.cards.map(\.ability.id) == [Ability.slash.id, Ability.block.id])
    }

    @Test func `repeat does not consume the Burn newly attached after Backdraft`() throws {
        var battle = try battle(["the_final_spark"], extra: .withTriggers { $0.backdraft = true })
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 3 }
        battle.insertEffect(.burn(4), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)

        let events = try play(attack(.burn), critical: true, in: &battle)
        let original = try #require(events.first { $0.kind == .abilityDamage && $0.abilityName == "strike" })
        let repeated = try #require(events.first { $0.abilityName == "The Final Spark" })

        #expect(original.amount == 26)
        #expect(repeated.amount == original.amount)
        let burn = try #require(battle.activeEffects(of: battle.enemy).first { $0.keyword == .burn })
        #expect(burn.effect.potency == original.amount + repeated.amount)
    }

    @Test(arguments: [Keyword.poison, .freeze])
    func `resolved repeat leaves newly readied source preparations for the next attack`(keyword: Keyword) throws {
        var battle = try UniqueCollectionTests().battle([])
        battle.roster.mutateRuntime(for: battle.hero) {
            $0.talents.pending.doubleNextPoisonDamage = true
            $0.talents.pending.nextFreezeIgnoresBlock = PreparedTalentBonus(value: true)
        }
        DefensePoolEngine.set(4, on: battle.enemy, in: &battle)
        var options = DamageOperation.attack(scaling: .resolved, accuracy: .unavoidable)
        options.capturesCardRepeat = true
        let outcome = battle.resolveTestDamage(10, keyword: keyword, options: options)

        #expect(outcome.healthLost == 6)
        #expect(battle.roster.hero.talents.pending.doubleNextPoisonDamage)
        #expect(battle.roster.hero.talents.pending.nextFreezeIgnoresBlock != nil)
    }

    @Test func `repeat preserves one use damage bonuses and current block`() throws {
        var battle = try battle(["the_final_spark"])
        battle.roster.mutateRuntime(for: battle.hero) {
            $0.currentMana = 3
            $0.talents.pending.cardDamageBonus = 7
            $0.talents.pending.damageAfterDodge = 5
        }
        DefensePoolEngine.set(4, on: battle.enemy, in: &battle)

        let events = try play(attack(.freeze), in: &battle)
        let original = try #require(events.first { $0.kind == .abilityDamage && $0.abilityName == "strike" })
        let repeated = try #require(events.first { $0.abilityName == "The Final Spark" })

        #expect(original.amount == 19)
        #expect(repeated.amount == 23)
        #expect(battle.roster.hero.currentMana == 0)
        #expect(battle.roster.hero.talents.pending.cardDamageBonus == 0)
        #expect(battle.roster.hero.talents.pending.damageAfterDodge == 0)
    }

    @Test func `repeat keeps the original random critical result`() throws {
        var battle = try battle(["the_final_spark"])
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 3 }
        battle.rng = SeededRandomNumberGenerator(seed: 1)
        let ability = Ability(
            id: "critical_spell", name: "critical_spell", tier: .basic,
            directDamage: 10, damageKeyword: .freeze, criticalChanceBonus: 0.4,
        )

        let events = try play(ability, in: &battle)
        let original = try #require(events.first { $0.kind == .abilityDamage && $0.abilityName == ability.name })
        let repeated = try #require(events.first { $0.abilityName == "The Final Spark" })

        #expect(repeated.isCritical == original.isCritical)
        #expect(repeated.amount == original.amount)
    }

    @Test func `repeat includes critical flat and percent bonuses`() throws {
        let extra = CombatModifierProfile(criticalDamagePercent: 0.5, criticalDamageBonus: 3)
        var battle = try battle(["the_final_spark"], extra: extra)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 3 }

        let events = try play(attack(.freeze), critical: true, in: &battle)
        let original = try #require(events.first { $0.kind == .abilityDamage && $0.abilityName == "strike" })
        let repeated = try #require(events.first { $0.abilityName == "The Final Spark" })

        #expect(original.amount == 38)
        #expect(repeated.amount == original.amount)
        #expect(repeated.isCritical)
    }

    @Test func `repeat preserves recurring initial pulse outgoing multipliers`() throws {
        var extra = CombatModifierProfile.zero
        extra.triggers.manaEmpowerBurnFreezeDamageMultiplier = 2
        var ordinary = try battle([], extra: extra)
        var spark = try battle(["the_final_spark"], extra: extra)
        ordinary.roster.mutateRuntime(for: ordinary.hero) { $0.currentMana = 3 }
        spark.roster.mutateRuntime(for: spark.hero) { $0.currentMana = 3 }

        try play(.blizzard, in: &ordinary)
        let events = try play(.blizzard, in: &spark)
        let initialDamage = 2000 - ordinary.roster.enemy.currentHealth

        #expect(2000 - spark.roster.enemy.currentHealth == initialDamage * 2)
        #expect(events.count { $0.abilityName == "The Final Spark" } == 1)
        #expect(spark.roster.enemy.activeEffects.filter { $0.effect.kind == .recurringDamage }.map(\.effect)
            == ordinary.roster.enemy.activeEffects.filter { $0.effect.kind == .recurringDamage }.map(\.effect))
    }

    @Test func `Beacon heals on the first damaging Holy attack per turn without spending its allowance on Thorns or Block`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["knight_holy_t2_1"])
        let beacon = try #require(GameContent.itemAffixDefinition(matching: "beacon"))
        beacon.basic.triggers.apply(to: &profile, abilityName: beacon.title)
        profile.triggers.criticalChanceBonus = -1
        var context = try battle([], extra: profile)
        context.roster.hero.currentHealth = 10
        context.roster.companion.currentHealth = 20
        context.insertEffect(.thorns(4), to: context.hero, sourceID: context.hero.id, remainingTurns: 0)

        let events = context.recordingResult { observation in self.enemyHit(1, in: &observation) }.events
        #expect(context.health(of: context.enemy) == 1996)
        #expect(context.health(of: context.hero) == 9)
        #expect(!events.contains { $0.abilityName == "Beacon" })
        let attack = DamageOperation.attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1)
        block(10, owner: .enemy, in: &context)
        _ = context.resolveTestDamage(10, keyword: .holy, options: attack)
        #expect(context.health(of: context.hero) == 9)
        let first = context.recordingResult { context in context.resolveTestDamage(1, keyword: .holy, options: attack) }
        #expect(context.health(of: context.hero) == 11)
        #expect(first.events.filter { $0.abilityName == "Beacon" && $0.effectKind == .instantHeal }.map(\.amount) == [2])
        _ = context.resolveTestDamage(1, keyword: .holy, options: attack)
        #expect(context.health(of: context.hero) == 11)
        context.turnCount += 1
        _ = context.resolveTestDamage(1, keyword: .holy, options: attack)
        #expect(context.health(of: context.hero) == 13)
    }

    @Test func `Rimeheart grants Block for Blizzard's immediate and lingering Freeze damage`() throws {
        var context = try battle(["rimeheart_locket"])
        let applied = CombatExecutor.run {
            await EffectApplication(
                effect: .recurringDamage(.freeze, 6, 1),
                ability: .blizzard,
                source: context.hero,
                target: context.enemy,
            ).apply(in: &context)
        }
        #expect(applied.didApply)
        #expect(context.health(of: context.enemy) == 1994)
        #expect(blockAmount(.hero, in: context) == 6)

        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: context.enemy, context: &context) }
        #expect(context.health(of: context.enemy) == 1988)
        #expect(blockAmount(.hero, in: context) == 12)
    }

    @Test(arguments: [false, true])
    func `Rimeheart's lingering Freeze grants Mana only to a living wearer`(defeated: Bool) throws {
        var context = try battle(["rimeheart_locket"])
        context.roster.hero.currentHealth = defeated ? 0 : 200
        block(3, owner: .hero, in: &context)
        let threshold = ControlMeterEngine.threshold(for: context.enemy, in: context)
        context.insertEffect(
            .recurringDamage(.freeze, threshold, 1), to: context.enemy,
            sourceID: context.hero.id, remainingTurns: 1,
        )

        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: context.enemy, context: &context) }

        #expect(context.roster.hasControlStatus(for: context.enemy, keyword: .freeze))
        #expect(context.roster.hero.currentMana == (defeated ? 0 : 3))
    }

    @Test(arguments: [false, true])
    func `Golden Verdict grants Gold for committed Holy Thorns only while its wearer lives`(defeated: Bool) throws {
        var context = try battle(["golden_verdict"], extra: CombatantTalentCatalog.profile(for: ["knight_holy_t2_1"]))
        context.roster.hero.currentHealth = 1
        context.roster.hero.hasConsumedDeathsDoor = defeated
        let threshold = ControlMeterEngine.threshold(for: context.enemy, in: context)
        context.insertEffect(.thorns(threshold), to: context.hero, sourceID: context.hero.id, remainingTurns: 0)

        _ = enemyHit(1, in: &context)

        #expect(context.health(of: context.hero) == (defeated ? 0 : 1))
        #expect(context.roster.hasControlStatus(for: context.enemy, keyword: .stun))
        #expect(context.gold == (defeated ? 0 : 1))
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Red Harvest detonates Bleed only after damaging Physical Critical Hits`(owner: BattleParticipant) throws {
        func prepared() throws -> BattleState {
            var context = try battle(["red_harvest"], owner: owner)
            context.insertEffect(
                .bleed(4), to: context.roster.enemy.combatant,
                sourceID: context.roster[owner].id, remainingTurns: 2,
            )
            return context
        }

        var critical = try prepared()
        let enemy = critical.roster.enemy.combatant
        let beforeHealth = critical.roster.enemy.currentHealth
        try play(attack(.physical, amount: 5), owner: owner, critical: true, in: &critical)
        #expect(!critical.roster.hasAffliction(.bleed, on: enemy))
        #expect(beforeHealth - critical.roster.enemy.currentHealth > 10)
        #expect(critical.hand.isEmpty)
        critical.insertEffect(.bleed(4), to: enemy, sourceID: critical.roster[owner].id, remainingTurns: 2)
        try play(attack(.physical, amount: 5), owner: owner, critical: true, in: &critical)
        #expect(!critical.roster.hasAffliction(.bleed, on: enemy))

        var ordinary = try prepared()
        try play(attack(.physical, amount: 5), owner: owner, in: &ordinary)
        #expect(ordinary.roster.hasAffliction(.bleed, on: enemy))

        var blocked = try prepared()
        block(100, owner: .enemy, in: &blocked)
        try play(attack(.physical, amount: 5), owner: owner, critical: true, in: &blocked)
        #expect(blocked.roster.hasAffliction(.bleed, on: enemy))
    }

    @Test func `Physical Crits repeatedly draw from the Companion deck`() throws {
        var context = try battle(["huntsmasters_call"])
        context.companionDeck = CombatDeck(abilities: [attack(id: "companion-a"), attack(id: "companion-b")])

        try play(attack(.physical, id: "ordinary"), in: &context)
        #expect(context.hand.isEmpty)
        #expect(context.companionDeck.count == 2)

        let first = try play(attack(.physical, id: "critical-a"), critical: true, in: &context)
        #expect(first.contains { $0.abilityName == "Huntsmaster’s Call" && $0.effectKind == .cardsDrawn })
        #expect(context.hand.cards.count { $0.owner == .companion } == 1)

        try play(attack(.physical, id: "critical-b"), critical: true, in: &context)
        #expect(context.hand.cards.count { $0.owner == .companion } == 2)
        #expect(context.companionDeck.isEmpty)

        var other = try battle(["huntsmasters_call"], owner: .companion)
        other.companionDeck = CombatDeck(abilities: [attack(id: "not-drawn")])
        try play(attack(.physical), owner: .companion, critical: true, in: &other)
        #expect(other.hand.isEmpty)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Threefold restores its wearer Mana from either party member's elemental damage`(owner: BattleParticipant) throws {
        var context = try battle(
            ["threefold_grace"],
            owner: owner,
            extra: .withTriggers { $0.threefoldElementalDamageManaChancePercent = 0.90 },
        )
        let attacker: BattleParticipant = owner == .hero ? .companion : .hero
        let target = context.roster.enemy.combatant

        for keyword in [Keyword.burn, .freeze, .holy] {
            _ = context.resolveTestDamage(
                5,
                to: target,
                keyword: keyword,
                sourceActorID: context.roster[attacker].id,
                options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
            )
        }
        #expect(context.roster[owner].currentMana == 3)
        #expect(context.roster[attacker].currentMana == 0)

        _ = context.resolveTestDamage(
            5,
            to: target,
            keyword: .physical,
            sourceActorID: context.roster[attacker].id,
            options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
        #expect(context.roster[owner].currentMana == 3)
    }

    @Test func `Golden Verdict's Holy Stun pays Gold theft bonuses`() throws {
        var context = try battle(["golden_verdict"], extra: .withTriggers { $0.goldStealFlatBonus = 2 })
        let target = context.roster.enemy.combatant
        let threshold = ControlMeterEngine.threshold(for: target, in: context)

        let outcome = context.recordingResult { context in context.resolveTestDamage(
            threshold,
            to: target,
            keyword: .holy,
            sourceActorID: context.roster.hero.id,
            options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }

        #expect(context.roster.hasControlStatus(for: target, keyword: .stun))
        #expect(context.gold == 3)
        #expect(outcome.events.contains { $0.abilityName == "Golden Verdict" && $0.keyword == .gold })
    }
}
