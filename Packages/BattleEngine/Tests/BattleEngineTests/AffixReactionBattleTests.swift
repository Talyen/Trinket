import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct AffixReactionBattleTests {
    private func hero(
        abilities: [Ability],
        maxHealth: Int = 20
    ) -> Combatant {
        Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: maxHealth,
            abilities: abilities
        )
    }

    private func passivePet(maxHealth: Int = 20) -> Combatant {
        BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, maxHealth: maxHealth)
    }

    private func passiveEnemy(maxHealth: Int = 100) -> Combatant {
        BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: maxHealth)
    }

    private func bleedAbility(potency: Int) -> Ability {
        Ability(
            id: "bleed-\(potency)",
            name: "Bleed",
            tier: .basic,
            directDamage: 0,
            description: "Bleed",
            effects: [.bleed(potency)]
        )
    }

    private func healAbility(amount: Int) -> Ability {
        Ability(
            id: "heal-\(amount)",
            name: "Heal",
            tier: .basic,
            directDamage: 0,
            description: "Heal",
            effects: [.instantHeal(.health, amount)]
        )
    }

    @Test func infectedAppliesPoisonWhenBleedIsApplied() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [bleedAbility(potency: 1)]),
            pet: passivePet(),
            enemy: passiveEnemy(),
            heroModifiers: CombatModifierProfile(onBleedApplyPoison: 1)
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        let poison = battle.activeEffects(of: battle.enemy).first { $0.keyword == .poison }
        try #expect(poison?.effect.potency == 1)
    }

    @Test func relentlessRefreshesBleedInsteadOfAddingAStack() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [bleedAbility(potency: 2)]),
            pet: passivePet(),
            enemy: passiveEnemy(),
            heroModifiers: CombatModifierProfile(refreshBleedOnReapply: true)
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        if try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle) == nil {
            _ = BattleTestFixtures.endTurn(on: &battle)
            _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        }

        let bleeds = battle.activeEffects(of: battle.enemy).filter { $0.keyword == .bleed }
        try #expect(bleeds.count == 1)
        try #expect(bleeds.first?.remainingTicks == Effect.bleedDoTTickCount)
    }

    @Test func frostburnDealsFreezeDamageEveryThirdBurnTick() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: []),
            pet: passivePet(),
            enemy: passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(8), remainingTicks: 0, sourceActorID: "hero")
            ],
            heroModifiers: CombatModifierProfile(
                everyNthBurnTickCount: 3,
                everyNthBurnTickFreezeDamage: 1
            )
        )

        var events: [ActionEvent] = []
        for _ in 0 ..< 3 {
            events.append(contentsOf: BattleTestFixtures.endTurn(on: &battle))
        }

        try #expect(events.contains { $0.kind == .status && $0.keyword == .freeze && $0.amount == 1 })
    }

    @Test func cascadingGrantsArmorWhenBlockBreaks() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [
                Ability(id: "strike", name: "Strike", tier: .basic, directDamage: 2, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: []),
            pet: passivePet(maxHealth: 1),
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTicks: 6)
            ],
            heroModifiers: CombatModifierProfile(blockBrokenArmorFlat: 1)
        )

        _ = BattleTestFixtures.endTurn(on: &battle)

        let armor = battle.activeEffects(of: battle.hero).first { active in
            if case let .mitigation(keyword, points) = active.effect {
                return keyword == .armor && points == 1
            }
            return false
        }
        try #expect(armor != nil)
    }

    @Test func symbiosisSharesHeroHealingWithPet() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [
                Ability(id: "strike", name: "Strike", tier: .basic, directDamage: 5, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [healAbility(amount: 10)]),
            pet: passivePet(maxHealth: 20),
            enemy: enemy,
            activePetEffects: [
                ActiveEffect(id: 1, effect: .bleed(4), remainingTicks: 1, sourceActorID: "enemy")
            ],
            heroModifiers: CombatModifierProfile(petHealSharePercent: 0.50)
        )

        // Enemy strike + bleed tick damage the pet during endTurn.
        _ = BattleTestFixtures.endTurn(on: &battle)
        let damagedPetHealth = battle.health(of: battle.pet)
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.pet) > damagedPetHealth)
    }

    @Test func secondWindHealsOnlyOnceWhenHealthFallsLow() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [
                // Non-lethal: drop below 25% without killing so Death's Door does not own the hit.
                Ability(id: "chip", name: "Chip", tier: .basic, directDamage: 16, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [], maxHealth: 20),
            pet: passivePet(maxHealth: 1),
            enemy: enemy,
            heroModifiers: CombatModifierProfile(
                onceBelowHealthPercentThreshold: 0.25,
                onceBelowHealthPercentHeal: 3
            )
        )

        let first = BattleTestFixtures.endTurn(on: &battle)
        let second = BattleTestFixtures.endTurn(on: &battle)

        try #expect(first.contains { $0.abilityName == "Second Wind" && $0.amount == 3 })
        try #expect(!second.contains { $0.abilityName == "Second Wind" })
        // Second chip is lethal after the heal; Death's Door owns that hit and leaves 1 HP.
        try #expect(second.contains { $0.effectKind == .deathsDoorTriggered })
        try #expect(battle.health(of: battle.hero) == 1)
    }

    @Test func deathsDoorProcsBeforeSecondWindOnLethalHit() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [
                Ability(id: "execute", name: "Execute", tier: .basic, directDamage: 40, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [], maxHealth: 20),
            pet: passivePet(maxHealth: 1),
            enemy: enemy,
            heroModifiers: CombatModifierProfile(
                onceBelowHealthPercentThreshold: 0.25,
                onceBelowHealthPercentHeal: 3
            )
        )

        let events = BattleTestFixtures.endTurn(on: &battle)

        try #expect(battle.health(of: battle.hero) == 1)
        try #expect(events.contains { $0.effectKind == .deathsDoorTriggered })
        try #expect(!events.contains { $0.abilityName == "Second Wind" })
    }

    @Test func shatterAddsFreezeDamageWhileEnemyIsFrozen() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [
                Ability(id: "frost", name: "Frost", tier: .basic, directDamage: 1, damageKeyword: .freeze)
            ]),
            pet: passivePet(),
            enemy: passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 1), remainingTicks: 0)
            ],
            heroModifiers: CombatModifierProfile(freezeDamageWhileFrozenBonus: 1)
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 2)
    }
}
