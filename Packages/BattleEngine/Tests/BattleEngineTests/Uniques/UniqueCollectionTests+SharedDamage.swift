import Testing
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

extension UniqueCollectionTests {
    @Test(arguments: [false, true])
    func `bloodember spends Ashen Vitality on Bleed only when sharing is equipped`(shared: Bool) throws {
        var battle = try battle(
            shared ? ["bloodember_pendant"] : [],
            owner: .companion,
            extra: CombatantTalentCatalog.profile(for: ["phoenix_health_t3_2"]),
        )
        CombatExecutor.run { await battle.healEmitting(
            amount: 1, target: battle.companion, source: battle.companion, abilityName: "Heal",
        ) }
        #expect(battle.roster.companion.talents.pending.nextBurnDamageBonus?.value == 2)

        try play(attack(.bleed, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == (shared ? 1978 : 1980))
        #expect((battle.roster.companion.talents.pending.nextBurnDamageBonus == nil) == shared)
        try play(attack(.burn, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == 1958)
    }

    @Test(arguments: [false, true])
    func `bloodember spends Redline on Burn only when sharing is equipped`(shared: Bool) throws {
        var battle = try battle(
            shared ? ["bloodember_pendant"] : [],
            owner: .companion,
            extra: CombatantTalentCatalog.profile(for: ["panther_bleed_t4_2"]),
        )
        _ = enemyHit(110, target: .companion, in: &battle)
        #expect(battle.roster.companion.talents.pending.doubleNextBleedAttack != nil)

        try play(attack(.burn, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == (shared ? 1960 : 1980))
        #expect((battle.roster.companion.talents.pending.doubleNextBleedAttack == nil) == shared)
        try play(attack(.bleed, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == 1940)
    }

    @Test(arguments: [false, true])
    func `oathkeeper spends Feigned Miss on Holy only when sharing is equipped`(shared: Bool) throws {
        var battle = try battle(
            shared ? ["oathkeeper"] : [],
            extra: CombatantTalentCatalog.profile(for: ["wildcard_physical_t3_2"]),
        )
        block(20, owner: .enemy, in: &battle)
        try play(attack(.physical, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == 2000)
        #expect(battle.roster.hero.talents.pending.doubleNextPhysicalAttack != nil)

        try play(attack(.holy, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == (shared ? 1960 : 1980))
        #expect((battle.roster.hero.talents.pending.doubleNextPhysicalAttack == nil) == shared)
        try play(attack(.physical, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == 1940)
    }

    @Test(arguments: ["wolf_dodge_t1_2", "wolf_dodge_t4_1"], [false, true])
    func `shared attacks spend Nimble Fang and Phantom Counter once`(talentID: String, shared: Bool) throws {
        let nimble = talentID == "wolf_dodge_t1_2"
        let item = nimble ? "bloodember_pendant" : "oathkeeper"
        let sharedKeyword: Keyword = nimble ? .burn : .holy
        let originalKeyword: Keyword = nimble ? .bleed : .physical
        var battle = try battle(shared ? [item] : [], owner: .companion, extra: CombatantTalentCatalog.profile(for: [talentID]))
        battle.insertEffect(.evadeNextHit, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)
        let avoided = battle.resolveTestDamage(
            1,
            from: .enemy,
            to: .companion,
            options: .attack(tier: .basic, abilityCriticalChanceBonus: -1),
        )
        #expect(avoided.flags.contains(.dodged))
        let prepared = nimble ? battle.roster.companion.talents.pending.nextBleedAttackMultiplier?.value
            : battle.roster.companion.talents.pending.nextPhysicalAttackMultiplier?.value
        #expect(prepared == (nimble ? 1.25 : 1.5))

        try play(attack(sharedKeyword, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == (shared ? (nimble ? 1975 : 1970) : 1980))
        try play(attack(originalKeyword, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == (nimble ? 1955 : 1950))
        #expect(battle.roster.companion.talents.pending.nextBleedAttackMultiplier == nil)
        #expect(battle.roster.companion.talents.pending.nextPhysicalAttackMultiplier == nil)
    }

    @Test(arguments: [false, true])
    func `bloodember spends Temper Cycle on Burn only when sharing is equipped`(shared: Bool) throws {
        var battle = try battle(shared ? ["bloodember_pendant"] : [])
        battle.roster.hero.talents.pending.nextBleedDamageBonus = PreparedTalentBonus(value: 5)
        try play(attack(.burn, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == (shared ? 1975 : 1980))
        #expect((battle.roster.hero.talents.pending.nextBleedDamageBonus == nil) == shared)
    }

    @Test(arguments: [false, true])
    func `oathkeeper shares physicalDamageVsBlockedBonus with Holy damage`(shared: Bool) throws {
        var battle = try battle(shared ? ["oathkeeper"] : [], extra: .withTriggers { $0.physicalDamageVsBlockedBonus = 5 })
        block(20, owner: .enemy, in: &battle)
        try play(attack(.holy, amount: 10), in: &battle)
        #expect(blockAmount(.enemy, in: battle) == (shared ? 5 : 10))
        #expect(battle.health(of: battle.enemy) == 2000)
    }

    @Test(arguments: [false, true])
    func `bloodember shares manaEmpowerBurnFreezeDamageMultiplier with Bleed damage`(shared: Bool) throws {
        var battle = try battle(
            shared ? ["bloodember_pendant"] : [],
            owner: .companion,
            extra: .withTriggers { $0.manaEmpowerBurnFreezeDamageMultiplier = 2.0 },
        )
        battle.resolution.beginAction(BattleActionContext(actor: battle.companion, in: battle), origin: .ability)
        battle.resolution.prepareActionTalents(TalentActionFacts(actorID: battle.companion.id, empoweredByMana: true))
        defer { battle.resolution.endAction() }
        let options = DamageOperation.attack(scaling: .flat, accuracy: .unavoidable)
        battle.resolveTestDamage(10, from: .companion, keyword: .bleed, options: options)
        #expect(battle.health(of: battle.enemy) == (shared ? 1980 : 1990))
    }

    @Test(arguments: [false, true])
    func `oathkeeper consumes storedImpact on Holy attacks`(shared: Bool) throws {
        var battle = try battle(shared ? ["oathkeeper"] : [], extra: .withTriggers { $0.storedImpact = true })
        block(15, owner: .hero, in: &battle)
        _ = enemyHit(10, in: &battle)
        #expect(battle.roster.hero.talents.battle.storedBlockedDamage == 10)

        try play(attack(.holy, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == (shared ? 1970 : 1980))
        #expect((battle.roster.hero.talents.battle.storedBlockedDamage == 0) == shared)
    }

    @Test func `companion profile companionBleedDamageDealtBonus increases bleed damage`() throws {
        var profile = CombatModifierProfile.zero
        profile.companionBleedDamageDealtBonus = 4
        var battle = try battle([], owner: .companion, extra: profile)
        try play(attack(.bleed, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == 1976)
    }

    @Test(arguments: [UInt64(1), 2, 3, 4])
    func `oathkeeper shares legacy Standard Deviation with holy damage`(seed: UInt64) throws {
        let profile = CombatModifierProfile.withTriggers { $0.standardDeviation = true }
        var shared = try battle(["oathkeeper"], extra: profile)
        var physical = try battle([], extra: profile)
        shared.rng = SeededRandomNumberGenerator(seed: seed)
        physical.rng = SeededRandomNumberGenerator(seed: seed)
        try play(attack(.holy, amount: 20), in: &shared)
        try play(attack(.physical, amount: 20), in: &physical)
        #expect(shared.health(of: shared.enemy) == physical.health(of: physical.enemy))
        #expect([1960, 1990].contains(shared.health(of: shared.enemy)))
    }

    @Test func `oathkeeper shares Shatterguards block damage with holy damage`() throws {
        let charm = try #require(GameContent.trinketItems.first { $0.templateID == "sundering_charm" })
        let power = try #require(charm.resolvedPower(at: 0))
        var profile = CombatModifierProfile.zero
        power.triggers.apply(to: &profile)
        var shared = try battle(["oathkeeper"], extra: profile)
        DefensePoolEngine.set(40, on: shared.enemy, in: &shared)
        try play(attack(.holy), in: &shared)
        #expect(DefensePoolEngine.blockPoints(in: shared.activeEffects(of: shared.enemy)) == 20)
        #expect(shared.health(of: shared.enemy) == 2000)

        var ordinary = try battle([], extra: profile)
        DefensePoolEngine.set(40, on: ordinary.enemy, in: &ordinary)
        try play(attack(.holy), in: &ordinary)
        #expect(DefensePoolEngine.blockPoints(in: ordinary.activeEffects(of: ordinary.enemy)) == 30)
    }

    @Test func `bloodember shares Flaming Arrows block damage with bleed attacks`() throws {
        try sharedBlockDamage(talentID: "ranger_burn_t1_1", keyword: .bleed, owner: .hero, remainingBlock: 22)
    }

    @Test func `bloodember shares Armor Shreds block damage with burn attacks`() throws {
        try sharedBlockDamage(talentID: "lizard_scout_bleed_t3_2", keyword: .burn, owner: .companion, remainingBlock: 25)
    }

    private func sharedBlockDamage(talentID: String, keyword: Keyword, owner: BattleParticipant, remainingBlock: Int) throws {
        let profile = CombatantTalentCatalog.profile(for: [talentID])
        var shared = try battle(["bloodember_pendant"], owner: owner, extra: profile)
        DefensePoolEngine.set(40, on: shared.enemy, in: &shared)
        try play(attack(keyword), owner: owner, in: &shared)
        #expect(DefensePoolEngine.blockPoints(in: shared.activeEffects(of: shared.enemy)) == remainingBlock)
        #expect(shared.health(of: shared.enemy) == 2000)

        var ordinary = try battle([], owner: owner, extra: profile)
        DefensePoolEngine.set(40, on: ordinary.enemy, in: &ordinary)
        try play(attack(keyword), owner: owner, in: &ordinary)
        #expect(DefensePoolEngine.blockPoints(in: ordinary.activeEffects(of: ordinary.enemy)) == 30)
    }

    @Test(arguments: ["bear_physical_t2_2", "risen_skeleton_physical_t4_1"])
    func `oathkeeper shares companion conditional physical damage bonuses`(talentID: String) throws {
        let profile = CombatantTalentCatalog.profile(for: [talentID])
        let critical = talentID == "risen_skeleton_physical_t4_1"
        let status: Effect = critical ? .poison(1) : .controlMeter(.stun, 400, 400)
        var shared = try battle(["oathkeeper"], owner: .companion, extra: profile)
        shared.insertEffect(status, to: shared.enemy, sourceID: shared.companion.id, remainingTurns: 0)
        try play(attack(.holy, amount: 20), owner: .companion, critical: critical, in: &shared)
        #expect(shared.health(of: shared.enemy) == (critical ? 1940 : 1975))

        var ordinary = try battle([], owner: .companion, extra: profile)
        ordinary.insertEffect(status, to: ordinary.enemy, sourceID: ordinary.companion.id, remainingTurns: 0)
        try play(attack(.holy, amount: 20), owner: .companion, critical: critical, in: &ordinary)
        #expect(ordinary.health(of: ordinary.enemy) == (critical ? 1960 : 1980))
    }

    @Test func `bloodember shares Supernovas damage roll with Bleed without changing other keywords`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wizard_burn_t3_1"])
        // Guarantee the proc to isolate keyword eligibility from the random roll.
        profile.triggers.burnAttackDoubleChancePercent = 1
        var shared = try battle(["bloodember_pendant"], extra: profile)
        try play(attack(.bleed), in: &shared)
        #expect(shared.health(of: shared.enemy) == 1980)
        try play(attack(.physical), in: &shared)
        #expect(shared.health(of: shared.enemy) == 1970)

        var ordinary = try battle([], extra: profile)
        try play(attack(.bleed), in: &ordinary)
        #expect(ordinary.health(of: ordinary.enemy) == 1990)
    }

    @Test(arguments: [Keyword.burn, .poison])
    func `adding allied damage preserves the original decaying stack owners rules`(keyword: Keyword) throws {
        var context = try battle([], extra: .withTriggers {
            $0.burnDecaySlowPercent = 0.4
            $0.poisonDecaySlowPercent = 0.4
        })
        for owner in [BattleParticipant.hero, .companion] {
            CombatExecutor.run { await DoTApplicator.applyDecayingDoT(
                keyword: keyword, potency: 10, to: context.enemy,
                sourceActorID: context.roster[owner].id, application: .attached, in: &context,
            ) }
        }
        let active = try #require(context.activeEffects(of: context.enemy).first { $0.keyword == keyword })
        #expect(active.sourceActorID == context.hero.id)
        let expected = active.effect.potencyAfterTurn(burnDecaySlowPercent: 0.4, poisonDecaySlowPercent: 0.4)
        let before = context.health(of: context.enemy)
        CombatExecutor.run { await EffectHandlers.advanceTurn(active, on: context.enemy, in: &context) }
        #expect(before - context.health(of: context.enemy) == expected)
    }

    @Test func `bloodember shares razor claws with burn attacks and stores the resolved bonus once`() throws {
        let profile = CombatantTalentCatalog.profile(for: ["panther_bleed_t1_1"])
        var context = try battle(["bloodember_pendant"], owner: .companion, extra: profile)

        try play(attack(.burn), owner: .companion, in: &context)

        #expect(context.roster.enemy.currentHealth == 1989)
        #expect(context.roster.enemy.activeEffects.first { $0.effect.kind == .burn }?.effect.potency == 11)

        var ordinary = try battle([], owner: .companion, extra: profile)
        try play(attack(.burn), owner: .companion, in: &ordinary)
        #expect(ordinary.roster.enemy.currentHealth == 1990)
    }

    @Test(arguments: [false, true])
    func `bloodember shares thermal shock only against frozen targets`(frozen: Bool) throws {
        var context = try battle(["bloodember_pendant"], extra: CombatantTalentCatalog.profile(for: ["wizard_freeze_t2_1"]))
        if frozen {
            context.insertEffect(
                .controlMeter(.freeze, 400, 400), to: context.enemy,
                sourceID: context.hero.id, remainingTurns: 0,
            )
        }

        try play(attack(.bleed, amount: 20), in: &context)

        #expect(context.roster.enemy.currentHealth == (frozen ? 1970 : 1980))
    }

    @Test(arguments: [99, 100])
    func `bloodember shares scorching ash below the sources half health boundary`(health: Int) throws {
        var context = try battle(["bloodember_pendant"], extra: CombatantTalentCatalog.profile(for: ["warlock_burn_t1_2"]))
        context.roster.hero.currentHealth = health

        try play(attack(.bleed, amount: 20), in: &context)

        #expect(context.roster.enemy.currentHealth == (health < 100 ? 1975 : 1980))
    }

    @Test func `oathkeeper shares guarded impact block damage with holy hits`() throws {
        let profile = CombatantTalentCatalog.profile(for: ["knight_block_t2_2"])
        var context = try battle(["oathkeeper"], extra: profile)
        block(20, owner: .hero, in: &context)

        try play(attack(.holy), in: &context)

        #expect(context.roster.enemy.currentHealth == 1985)

        var ordinary = try battle([], extra: profile)
        block(20, owner: .hero, in: &ordinary)
        try play(attack(.holy), in: &ordinary)
        #expect(ordinary.roster.enemy.currentHealth == 1990)
    }

    @Test(arguments: ["warlock_mana_t4_1", "ranger_burn_t2_1"])
    func `bloodember shares Void Focus and Woundfire with Bleed`(talentID: String) throws {
        var context = try battle(["bloodember_pendant"], extra: CombatantTalentCatalog.profile(for: [talentID]))
        context.insertEffect(.bleed(1), to: context.enemy, sourceID: context.hero.id, remainingTurns: 2)
        try play(attack(.bleed, amount: 20), in: &context)
        #expect(context.roster.enemy.currentHealth == 1975)
    }

    @Test func `bloodember shares Inferno Barrages Critical damage with Bleed`() throws {
        var context = try battle(["bloodember_pendant"], extra: CombatantTalentCatalog.profile(for: ["ranger_burn_t3_2"]))
        try play(attack(.bleed), critical: true, in: &context)
        #expect(context.roster.enemy.currentHealth == 1976)
    }

    @Test func `bloodember shares Savage Tears Critical damage with Burn`() throws {
        var context = try battle(
            ["bloodember_pendant"],
            owner: .companion,
            extra: CombatantTalentCatalog.profile(for: ["wolf_bleed_t3_2"]),
        )
        try play(attack(.burn), owner: .companion, critical: true, in: &context)
        #expect(context.roster.enemy.currentHealth == 1970)
    }

    @Test(arguments: [Keyword.holy, .burn, .bleed], [BattleParticipant.hero, .companion])
    func `shared damage includes both keyword percentages and universal bonuses once`(
        keyword: Keyword,
        owner: BattleParticipant,
    ) throws {
        let sharedKeyword: Keyword = switch keyword {
        case .holy: .physical
        case .burn: .bleed
        default: .burn
        }
        let unique = keyword == .holy ? "oathkeeper" : "bloodember_pendant"
        let profile = CombatModifierProfile(
            damageDealtPercents: [keyword: 0.1, sharedKeyword: 0.2],
            companionDamageDealtPercent: 0.3,
        )
        var context = try battle([unique], owner: owner, extra: profile)

        try play(attack(keyword, amount: 100), owner: owner, in: &context)

        #expect(context.roster.enemy.currentHealth == 1840)

        var ordinary = try battle([], owner: owner, extra: profile)
        try play(attack(keyword, amount: 100), owner: owner, in: &ordinary)
        #expect(ordinary.roster.enemy.currentHealth == 1860)
    }
}

extension UniqueCollectionTests {
    @Test(arguments: ["wolf_physical_t4_1", "bear_physical_t4_1", "wolf_physical_t3_1"])
    func `oathkeeper shares first attack and burst damage while retaining their allowances`(talentID: String) throws {
        var profile = CombatantTalentCatalog.profile(for: [talentID])
        if talentID == "wolf_physical_t3_1" {
            profile.triggers.physicalAttackBurstChancePercent = 1
        }
        var battle = try battle(["oathkeeper"], owner: .companion, extra: profile)
        block(20, owner: .companion, in: &battle)

        try play(attack(.holy, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == (talentID == "wolf_physical_t4_1" ? 1960 : 1970))

        // Shared hits spend the same first-attack allowance; a later Physical hit cannot earn it again.
        try play(attack(.physical, amount: 20), owner: .companion, in: &battle)
        #expect(battle.health(of: battle.enemy) == (talentID == "wolf_physical_t3_1" ? 1940 :
                talentID == "wolf_physical_t4_1" ? 1940 : 1950))
    }

    @Test func `oathkeeper consumes Bounty Blades prepared damage on a Holy attack`() throws {
        var battle = try battle(["oathkeeper"], extra: CombatantTalentCatalog.profile(for: ["rogue_gold_t4_1"]))
        battle.grantGoldEvent(1, to: battle.hero, abilityName: "Steal", isTheft: true)

        try play(attack(.holy, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == 1975)
        #expect(battle.roster.hero.talents.pending.nextPhysicalDamageBonus == nil)
        try play(attack(.physical, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == 1953)
    }

    @Test func `bloodember shares Soul Burns prepared bonus with the next Bleed attack`() throws {
        var battle = try battle(["bloodember_pendant"], extra: CombatantTalentCatalog.profile(for: ["warlock_burn_t2_2"]))
        battle.roster.hero.currentMana = 3

        // Empowering this Burn card spends the last Mana and prepares a later attack.
        try play(attack(.burn), in: &battle)
        #expect(battle.health(of: battle.enemy) == 1989)
        #expect(battle.mana(of: battle.hero) == 0)
        try play(attack(.bleed, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == 1959)
        #expect(battle.roster.hero.talents.pending.nextBurnAttackPercent == nil)
        try play(attack(.burn, amount: 20), in: &battle)
        #expect(battle.health(of: battle.enemy) == 1939)
    }
}
