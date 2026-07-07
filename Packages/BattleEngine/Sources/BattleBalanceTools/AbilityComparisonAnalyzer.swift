import BattleEngine
import Foundation
import Synchronization
import TrinketContent
import TrinketCore

enum AbilityComparisonAnalyzer {
    private struct WorkItem: Sendable {
        let comparisonIndex: Int
        let tier: SimulationPowerTier
        let combatant: Combatant
        let defaultHero: Combatant
        let defaultPet: Combatant
        let abilityTier: AbilityTier
        let abilityA: Ability
        let abilityB: Ability
    }

    static func analyze(request: BalanceSweepRequest) -> [AbilityComparisonRow] {
        guard
            let representativeHero = BalanceSweepCatalog.representativeHero(id: request.representativeHeroID),
            let representativePet = BalanceSweepCatalog.representativePet(id: request.representativePetID)
        else {
            return []
        }

        let workItems = buildWorkItems(
            request: request,
            representativeHero: representativeHero,
            representativePet: representativePet
        )
        guard !workItems.isEmpty else { return [] }

        let enemies = GameContent.enemies
        let collector = AbilityComparisonRowCollector(capacity: workItems.count)

        // Concurrency-Safety: concurrentPerform is intentional for CLI parallelism; rows are stored via Mutex-backed collector.
        DispatchQueue.concurrentPerform(iterations: workItems.count) { index in
            let rows = evaluate(workItems[index], enemies: enemies, request: request)
            collector.store(rows, at: index)
        }

        return collector.rows
    }

    private static func buildWorkItems(
        request: BalanceSweepRequest,
        representativeHero: Combatant,
        representativePet: Combatant
    ) -> [WorkItem] {
        let playerCombatants: [(Combatant, Combatant, Combatant)] = GameContent.heroes.map {
            ($0, representativeHero, representativePet)
        } + GameContent.pets.map {
            ($0, representativeHero, representativePet)
        }

        var workItems: [WorkItem] = []
        var comparisonIndex = 0

        for tier in request.tiers {
            let progression = CombatantProgression(level: tier.level, currentXP: 0, requiredXP: 100)

            for (combatant, defaultHero, defaultPet) in playerCombatants {
                for abilityTier in AbilityTier.allCases {
                    let choices = combatant.abilityChoices.abilities(for: abilityTier)
                    guard choices.count == 2 else { continue }
                    guard progression.unlocks(abilityTier) else { continue }

                    workItems.append(
                        WorkItem(
                            comparisonIndex: comparisonIndex,
                            tier: tier,
                            combatant: combatant,
                            defaultHero: defaultHero,
                            defaultPet: defaultPet,
                            abilityTier: abilityTier,
                            abilityA: choices[0],
                            abilityB: choices[1]
                        )
                    )
                    comparisonIndex += 1
                }
            }
        }

        return workItems
    }

    private static func evaluate(
        _ workItem: WorkItem,
        enemies: [Enemy],
        request: BalanceSweepRequest
    ) -> [AbilityComparisonRow] {
        let tier = workItem.tier
        let combatant = workItem.combatant
        let abilityTier = workItem.abilityTier
        let abilityA = workItem.abilityA
        let abilityB = workItem.abilityB
        let progression = CombatantProgression(level: tier.level, currentXP: 0, requiredXP: 100)
        let gearGenerator = ThemedGearGenerator()

        var winsA = 0
        var winsB = 0

        for enemy in enemies {
            let hero = combatant.role == .hero ? combatant : workItem.defaultHero
            let pet = combatant.role == .pet ? combatant : workItem.defaultPet

            let loadoutA = AbilityLoadoutSampler.loadout(
                for: combatant,
                selecting: abilityA,
                progression: progression
            )
            let loadoutB = AbilityLoadoutSampler.loadout(
                for: combatant,
                selecting: abilityB,
                progression: progression
            )

            let heroLoadoutA = combatant.role == .hero ? loadoutA : AbilityLoadoutSampler.defaultLoadout(
                for: hero,
                progression: progression
            )
            let petLoadoutA = combatant.role == .pet ? loadoutA : AbilityLoadoutSampler.defaultLoadout(
                for: pet,
                progression: progression
            )
            let heroLoadoutB = combatant.role == .hero ? loadoutB : AbilityLoadoutSampler.defaultLoadout(
                for: hero,
                progression: progression
            )
            let petLoadoutB = combatant.role == .pet ? loadoutB : AbilityLoadoutSampler.defaultLoadout(
                for: pet,
                progression: progression
            )

            var heroGearA: ThemedGearBuild?
            var petGearA: ThemedGearBuild?
            var heroGearB: ThemedGearBuild?
            var petGearB: ThemedGearBuild?

            if tier.includesGear,
               let rarity = tier.rarity,
               let affixCount = tier.fixedAffixCount {
                let gearSeed = request.baseSeed &+ UInt64(workItem.comparisonIndex) &+ 200_000
                var heroARNG = SeededRandomNumberGenerator(seed: gearSeed)
                var petARNG = SeededRandomNumberGenerator(seed: gearSeed &+ 1)
                var heroBRNG = SeededRandomNumberGenerator(seed: gearSeed &+ 2)
                var petBRNG = SeededRandomNumberGenerator(seed: gearSeed &+ 3)
                heroGearA = gearGenerator.generate(
                    for: hero,
                    rarity: rarity,
                    fixedAffixCount: affixCount,
                    idPrefix: "ability-a-hero",
                    using: &heroARNG
                )
                petGearA = gearGenerator.generate(
                    for: pet,
                    rarity: rarity,
                    fixedAffixCount: affixCount,
                    idPrefix: "ability-a-pet",
                    using: &petARNG
                )
                heroGearB = gearGenerator.generate(
                    for: hero,
                    rarity: rarity,
                    fixedAffixCount: affixCount,
                    idPrefix: "ability-b-hero",
                    using: &heroBRNG
                )
                petGearB = gearGenerator.generate(
                    for: pet,
                    rarity: rarity,
                    fixedAffixCount: affixCount,
                    idPrefix: "ability-b-pet",
                    using: &petBRNG
                )
            }

            let configuredA = SimulationMatchupAssembler.assemble(
                hero: hero,
                pet: pet,
                enemy: enemy,
                tier: tier,
                heroLoadout: heroLoadoutA,
                petLoadout: petLoadoutA,
                heroGear: heroGearA,
                petGear: petGearA,
                loadoutSampleIndex: 0,
                seed: request.baseSeed &+ UInt64(workItem.comparisonIndex)
            )
            let configuredB = SimulationMatchupAssembler.assemble(
                hero: hero,
                pet: pet,
                enemy: enemy,
                tier: tier,
                heroLoadout: heroLoadoutB,
                petLoadout: petLoadoutB,
                heroGear: heroGearB,
                petGear: petGearB,
                loadoutSampleIndex: 0,
                seed: request.baseSeed &+ UInt64(workItem.comparisonIndex)
            )

            let seed = request.baseSeed &+ UInt64(workItem.comparisonIndex) &+ 300_000
            let options = BalanceSweepRunner.sweepOptions(maxTicks: request.maxTicks, seed: seed)
            if BattleSimulator.run(configuredA, options: options).didWin {
                winsA += 1
            }
            if BattleSimulator.run(configuredB, options: options).didWin {
                winsB += 1
            }
        }

        return [
            AbilityComparisonRow(
                tier: tier,
                combatantID: combatant.id,
                combatantName: combatant.name,
                abilityTier: abilityTier,
                abilityID: abilityA.id,
                abilityName: abilityA.name,
                siblingAbilityID: abilityB.id,
                siblingAbilityName: abilityB.name,
                winCount: winsA,
                lossCount: winsB
            ),
            AbilityComparisonRow(
                tier: tier,
                combatantID: combatant.id,
                combatantName: combatant.name,
                abilityTier: abilityTier,
                abilityID: abilityB.id,
                abilityName: abilityB.name,
                siblingAbilityID: abilityA.id,
                siblingAbilityName: abilityA.name,
                winCount: winsB,
                lossCount: winsA
            )
        ]
    }
}

private final class AbilityComparisonRowCollector: Sendable {
    private let storage: Mutex<[[AbilityComparisonRow]?]>

    init(capacity: Int) {
        storage = Mutex(Array(repeating: nil, count: capacity))
    }

    func store(_ rows: [AbilityComparisonRow], at index: Int) {
        storage.withLock { array in
            array[index] = rows
        }
    }

    var rows: [AbilityComparisonRow] {
        storage.withLock { array in
            array.compactMap { $0 }.flatMap { $0 }
        }
    }
}
