import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct AffixReactionBattleTests {
    private func hero(
        abilities: [Ability],
        actionIntervalTicks: Int = 1,
        maxHealth: Int = 20
    ) -> Combatant {
        Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: maxHealth,
            actionIntervalTicks: actionIntervalTicks,
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

        _ = battle.advanceOneStep()

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

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        let bleeds = battle.activeEffects(of: battle.enemy).filter { $0.keyword == .bleed }
        try #expect(bleeds.count == 1)
        try #expect(bleeds.first?.remainingTicks == Effect.bleedDoTTickCount)
    }

    @Test func frostburnDealsFreezeDamageEveryThirdBurnTick() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [], actionIntervalTicks: 100),
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
            events.append(contentsOf: battle.advanceOneStep().events)
        }

        try #expect(events.contains { $0.kind == .status && $0.keyword == .freeze && $0.amount == 1 })
    }

    @Test func cascadingGrantsArmorWhenBlockBreaks() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [
                Ability(id: "strike", name: "Strike", tier: .basic, directDamage: 2, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [], actionIntervalTicks: 100),
            pet: passivePet(maxHealth: 1),
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 1, 6), remainingTicks: 6)
            ],
            heroModifiers: CombatModifierProfile(blockBrokenArmorPercent: 0.05, blockBrokenArmorDurationTicks: 2)
        )

        _ = battle.advanceOneStep()

        let armor = battle.activeEffects(of: battle.hero).first { active in
            if case let .mitigation(keyword, percent, duration) = active.effect {
                return keyword == .armor && percent == 0.05 && duration == 2
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
            actionIntervalTicks: 1,
            abilities: [
                Ability(id: "strike", name: "Strike", tier: .basic, directDamage: 5, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [healAbility(amount: 10)], actionIntervalTicks: 2),
            pet: passivePet(maxHealth: 20),
            enemy: enemy,
            activePetEffects: [
                ActiveEffect(id: 1, effect: .bleed(4), remainingTicks: 1, sourceActorID: "enemy")
            ],
            heroModifiers: CombatModifierProfile(petHealSharePercent: 0.50)
        )

        _ = battle.advanceOneStep()
        let damagedPetHealth = battle.health(of: battle.pet)
        _ = battle.advanceOneStep()

        try #expect(battle.health(of: battle.pet) > damagedPetHealth)
    }

    @Test func secondWindHealsOnlyOnceWhenHealthFallsLow() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [
                // Non-lethal: drop below 25% without killing so Death's Door does not own the hit.
                Ability(id: "chip", name: "Chip", tier: .basic, directDamage: 16, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [], actionIntervalTicks: 100, maxHealth: 20),
            pet: passivePet(maxHealth: 1),
            enemy: enemy,
            heroModifiers: CombatModifierProfile(
                onceBelowHealthPercentThreshold: 0.25,
                onceBelowHealthPercentHeal: 3
            )
        )

        let first = battle.advanceOneStep()
        let second = battle.advanceOneStep()

        try #expect(first.events.contains { $0.abilityName == "Second Wind" && $0.amount == 3 })
        try #expect(!second.events.contains { $0.abilityName == "Second Wind" })
        try #expect(battle.health(of: battle.hero) > 1)
    }

    @Test func deathsDoorProcsBeforeSecondWindOnLethalHit() throws {
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [
                Ability(id: "execute", name: "Execute", tier: .basic, directDamage: 40, damageKeyword: .physical)
            ]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(abilities: [], actionIntervalTicks: 100, maxHealth: 20),
            pet: passivePet(maxHealth: 1),
            enemy: enemy,
            heroModifiers: CombatModifierProfile(
                onceBelowHealthPercentThreshold: 0.25,
                onceBelowHealthPercentHeal: 3
            )
        )

        let step = battle.advanceOneStep()

        try #expect(battle.health(of: battle.hero) == 1)
        try #expect(step.events.contains { $0.effectKind == .deathsDoorTriggered })
        try #expect(!step.events.contains { $0.abilityName == "Second Wind" })
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

        _ = battle.advanceOneStep()

        try #expect(100 - battle.health(of: battle.enemy) == 2)
    }
}
