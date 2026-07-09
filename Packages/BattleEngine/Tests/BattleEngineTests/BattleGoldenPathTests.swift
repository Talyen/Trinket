import Testing
import BattleEngine
import TrinketCore
import TrinketContent

/// End-to-end regression harness for battle simulation. Pins outcomes for a
/// fixed matchup and RNG seed so refactors cannot silently change combat behavior.
@Suite
struct BattleGoldenPathTests {
    private var wizard: Combatant { GameContent.heroes.first { $0.id == "wizard" }! }
    private var wolf: Combatant { GameContent.pets.first { $0.id == "wolf" }! }
    private var goblin: Combatant { GameContent.enemies.first { $0.id == "goblin" }!.combatant }

    private func runGoldenBattle(pet: Combatant? = nil) -> BattleSimulationResult {
        BattleSimulator.run(
            BattleStateTestFactory.makeBattle(hero: wizard, pet: pet ?? wolf, enemy: goblin),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    @Test func goldenPathOutcomeAndCounters() throws {
        let result = runGoldenBattle()

        try #expect(result.outcome == .victory)
        try #expect(result.tickCount == 5)
        try #expect(result.actionCount == 5)
        try #expect(result.finalEnemyHealth == 0)
        try #expect(result.finalHeroHealth == 17)
        try #expect(result.finalPetHealth == 19)
    }

    @Test func goldenPathEventSemantics() throws {
        // Default wolf basic is rendingSlash (physical); select fangs so bleed remains pinned.
        let bleedWolf = wolf.withAbilityLoadout(
            AbilityLoadout(
                basic: .fangs,
                skill: wolf.abilityLoadout.skill,
                ultimate: wolf.abilityLoadout.ultimate
            )
        )
        let result = runGoldenBattle(pet: bleedWolf)
        let events = result.events

        assertEndsWithVictoryMilestone(on: "goblin", events: events)
        try #expect(events.contains { $0.kind == .ability && $0.keyword == .burn })
        try #expect(events.contains { $0.kind == .ability && $0.keyword == .bleed })
    }

    // MARK: - Party defeat

    private func runPartyDefeatBattle() -> BattleSimulationResult {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let helper = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let strong = Combatant(
            id: "strong",
            name: "Strong",
            role: .enemy,
            maxHealth: 100,
            abilities: [.slash]
        )
        return BattleSimulator.run(
            BattleStateTestFactory.makeBattle(hero: fragile, pet: helper, enemy: strong),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    @Test func partyDefeatGoldenPath() throws {
        let result = runPartyDefeatBattle()

        try #expect(result.outcome == .defeat)
        try #expect(result.tickCount == 36)
        try #expect(result.actionCount == 29)
        try #expect(result.finalHeroHealth == 0)
        try #expect(result.finalPetHealth == 0)
        try #expect(result.finalEnemyHealth == 100)
        assertEndsWithVictoryMilestone(on: "strong", events: result.events)
        try #expect(result.events.contains { $0.kind == .ability && $0.keyword == .physical })
        try #expect(result.log.contains { $0.text == "Your party has been defeated by Strong." })
    }

    // MARK: - Stun threshold

    private func runStunThresholdBattle() -> BattleSimulationResult {
        let stunHero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTicks: 1,
            abilities: [
                Ability(
                    id: "test-stun",
                    name: "Test Stun",
                    tier: .basic,
                    directDamage: 1,
                    damageKeyword: .stun,
                    description: "Deal 1 Stun damage."
                )
            ]
        )
        let silentPet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 50, actionIntervalTicks: 100, abilities: [])
        let stunEnemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 5, actionIntervalTicks: 2, abilities: [.slash])
        return BattleSimulator.run(
            BattleStateTestFactory.makeBattle(hero: stunHero, pet: silentPet, enemy: stunEnemy),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    @Test func stunThresholdGoldenPath() throws {
        let result = runStunThresholdBattle()

        try #expect(result.outcome == .victory)
        try #expect(result.tickCount == 9)
        try #expect(result.actionCount == 9)
        try #expect(result.finalEnemyHealth == 0)
        assertEndsWithVictoryMilestone(on: "enemy", events: result.events)
        try #expect(result.events.contains { $0.effectKind == .controlActionSkipped && $0.keyword == .stun })
        try #expect(result.events.contains { $0.effectKind == .controlTriggered && $0.keyword == .stun })
        try #expect(result.events.contains { $0.kind == .ability && $0.keyword == .stun })
    }

    // MARK: - Item modifier (Keen)

    private func runKeenAffixBattle() -> BattleSimulationResult {
        let keen = GameContent.itemAffixDefinitions.first { $0.id == "keen" }!
        let keenHero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.slash]
        )
        let idlePet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, actionIntervalTicks: 100, abilities: [])
        let punchingBag = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        return BattleSimulator.run(
            BattleStateTestFactory.makeBattle(
                hero: keenHero,
                pet: idlePet,
                enemy: punchingBag,
                heroModifiers: CombatModifierProfile(modifiers: keen.basic.modifiers)
            ),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    @Test func keenAffixGoldenPath() throws {
        let result = runKeenAffixBattle()
        let damagingHits = result.events.filter {
            $0.kind == .ability && $0.keyword == .physical && $0.amount > 0
        }

        try #expect(result.outcome == .victory)
        try #expect(result.tickCount == 102)
        try #expect(result.actionCount == 52)
        try #expect(!(damagingHits.isEmpty))
        try #expect(damagingHits.allSatisfy { $0.amount == 2 })
    }

    // MARK: - Poison-heavy

    private func runPoisonHeavyBattle() -> BattleSimulationResult {
        let poisonHero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTicks: 1,
            abilities: [.poisonDagger]
        )
        let poisonPet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 50, actionIntervalTicks: 100, abilities: [])
        let poisonEnemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 40, actionIntervalTicks: 100, abilities: [])
        return BattleSimulator.run(
            BattleStateTestFactory.makeBattle(hero: poisonHero, pet: poisonPet, enemy: poisonEnemy),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    @Test func poisonHeavyGoldenPath() throws {
        let result = runPoisonHeavyBattle()
        let events = result.events

        try #expect(result.outcome == .victory)
        try #expect(result.tickCount == 6)
        try #expect(result.actionCount == 5)
        try #expect(result.finalEnemyHealth == 0)
        assertEndsWithVictoryMilestone(on: "enemy", events: events)
        try #expect(events.filter { $0.kind == .ability && $0.keyword == .poison }.count >= 4)
        try #expect(events.contains { $0.kind == .status && $0.keyword == .poison && $0.targetID == "enemy" })
    }

    // MARK: - Semantic helpers

    private func assertEndsWithVictoryMilestone(
        on targetID: String,
        events: [ActionEvent],
        location: SourceLocation = #_sourceLocation
    ) {
        let milestones = events.filter { $0.kind == .milestone }
        try #expect(!milestones.isEmpty, sourceLocation: location)
        try #expect(milestones.last?.targetID == targetID, sourceLocation: location)
    }

    private func assertContainsEvent(
        kind: ActionEvent.Kind,
        keyword: Keyword,
        targetID: String,
        in events: [ActionEvent],
        location: SourceLocation = #_sourceLocation
    ) {
        try #expect(
            events.contains { $0.kind == kind && $0.keyword == keyword && $0.targetID == targetID },
            sourceLocation: location
        )
    }
}
