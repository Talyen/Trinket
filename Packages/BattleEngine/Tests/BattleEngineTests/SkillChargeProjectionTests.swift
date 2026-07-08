import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

@Suite("SkillChargeProjection")
struct SkillChargeProjectionTests {
    @Test func projectsNilOnBasicTurn() throws {
        let battle = makeSkillBattle()
        // actionCount 0 → next turn 1 (basic)
        try #expect(battle.skillChargeProjection(of: battle.hero) == nil)
    }

    @Test func projectsSkillOnTurn3WithProgress() throws {
        var battle = makeSkillBattle()
        seedActionCount(2, on: &battle, combatant: battle.hero)

        // After two acts, next turn is 3 (skill). Mid-cycle progress depends on schedule.
        let runtime = try #require(battle.roster.runtime(for: battle.hero))
        battle.tickCount = runtime.nextReadyAtTick - 1

        let projection = try #require(battle.skillChargeProjection(of: battle.hero))
        try #expect(projection.ability.tier == .skill)
        try #expect(projection.ability.id == "skill-atk")
        try #expect(projection.progress > 0)
        try #expect(projection.progress < 1)
    }

    @Test func projectsFullProgressWhenReady() throws {
        var battle = makeSkillBattle()
        seedActionCount(2, on: &battle, combatant: battle.hero)
        let runtime = try #require(battle.roster.runtime(for: battle.hero))
        battle.tickCount = runtime.nextReadyAtTick

        let projection = try #require(battle.skillChargeProjection(of: battle.hero))
        try #expect(projection.progress == 1)
    }

    @Test func projectsNilOnUltimateTurnEvenWhenMultipleOfSkillCadence() throws {
        var battle = makeSkillBattle()
        // turn 6 is ultimate (also multiple of 3)
        seedActionCount(5, on: &battle, combatant: battle.hero)

        try #expect(battle.skillChargeProjection(of: battle.hero) == nil)
    }

    @Test func projectsNilWhenManaForcesBasicFallback() throws {
        let basic = Ability(id: "basic", name: "Basic", tier: .basic, directDamage: 1, description: "Basic")
        let skill = Ability(
            id: "mana-skill",
            name: "Mana Skill",
            tier: .skill,
            directDamage: 5,
            description: "Skill",
            manaCost: 3
        )
        let ultimate = Ability(id: "ult", name: "Ult", tier: .ultimate, directDamage: 8, description: "Ult")
        let wizard = Combatant(
            id: "wizard",
            name: "Wizard",
            role: .hero,
            maxHealth: 20,
            maxMana: 5,
            abilities: [basic, skill, ultimate]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: wizard,
            pet: CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 20),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        )
        seedActionCount(2, on: &battle, combatant: wizard)
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: wizard) { $0.currentMana = 0 }
        }

        try #expect(battle.skillChargeProjection(of: wizard) == nil)
    }

    @Test func actionChargeProgressUsesScheduledInterval() throws {
        let combatant = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            maxHealth: 20,
            actionIntervalTicks: 4
        )
        var runtime = CombatantRuntime(combatant: combatant)
        try #expect(runtime.scheduledActionInterval == 4)
        try #expect(runtime.actionChargeProgress(atTick: 0) == 0)
        try #expect(runtime.actionChargeProgress(atTick: 2) == 0.5)
        try #expect(runtime.actionChargeProgress(atTick: 4) == 1)

        runtime.markActed(atTick: 4)
        try #expect(runtime.scheduledActionInterval == 4)
        try #expect(runtime.actionChargeProgress(atTick: 4) == 0)
        try #expect(runtime.actionChargeProgress(atTick: 6) == 0.5)
        try #expect(runtime.actionChargeProgress(atTick: 8) == 1)
    }

    @Test func markActedRecordsScheduledIntervalWithHaste() throws {
        let combatant = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            maxHealth: 20,
            actionIntervalTicks: 4
        )
        var runtime = CombatantRuntime(combatant: combatant)
        let haste = ActiveEffect(id: 1, effect: .haste(2), remainingTicks: 4)
        runtime.markActed(atTick: 4, activeEffects: [haste])
        try #expect(runtime.scheduledActionInterval == 3)
        try #expect(runtime.nextReadyAtTick == 7)
    }

    @Test func preferredTierMatchesCadence() {
        #expect(BattleTurnEngine.preferredTier(for: 1) == .basic)
        #expect(BattleTurnEngine.preferredTier(for: 2) == .basic)
        #expect(BattleTurnEngine.preferredTier(for: 3) == .skill)
        #expect(BattleTurnEngine.preferredTier(for: 6) == .ultimate)
        #expect(BattleTurnEngine.preferredTier(for: 9) == .skill)
    }
}

private extension SkillChargeProjectionTests {
    func makeSkillBattle() -> BattleState {
        let basic = Ability(id: "basic-atk", name: "BasicAtk", tier: .basic, directDamage: 1, description: "Basic")
        let skill = Ability(id: "skill-atk", name: "SkillAtk", tier: .skill, directDamage: 3, description: "Skill")
        let ultimate = Ability(id: "ult-atk", name: "UltAtk", tier: .ultimate, directDamage: 5, description: "Ult")
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 40,
            actionIntervalTicks: 4,
            abilities: [basic, skill, ultimate]
        )
        return BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 20),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        )
    }

    func seedActionCount(_ count: Int, on battle: inout BattleState, combatant: Combatant) {
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: combatant) { runtime in
                runtime.actionCount = count
                // Keep a coherent schedule: just acted at tick 0 of a fresh interval.
                let interval = max(1, runtime.actionSpeed.effectiveInterval)
                runtime.scheduledActionInterval = interval
                runtime.nextReadyAtTick = context.tickCount + interval
            }
        }
    }
}
