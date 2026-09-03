import Testing
import TrinketCore
@testable import TrinketContent

struct AbilityCatalogTests {
    @Test func `catalog I ds are unique and unknown lookup returns nil`() throws {
        let ids = AbilityCatalog.all.map(\.id)
        try #expect(
            Set(ids).count == ids.count,
            "Duplicate ability IDs: \(Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys)",
        )
        try #expect(AbilityCatalog.ability(id: "missing-ability") == nil)
    }

    @Test func `catalog passes validation`() throws {
        let issues = AbilityValidator.validateCatalog()
        try #expect(issues.isEmpty, "\(issues.map(\.description).joined(separator: "\n"))")
    }

    @Test func `direct hit builder does not add targeted do T`() throws {
        let ability = AbilityBuilder.directHit(
            id: "burn-hit",
            name: "Burn Hit",
            tier: .skill,
            amount: 3,
            keyword: .burn,
        )
        try #expect(ability.damageComponents == [DamageComponent(3, keyword: .burn)])
        try #expect(ability.targetedEffects.isEmpty)
        try #expect(ability.summary == "Deal 3 Burn damage.")

        let bleedHit = AbilityBuilder.directHit(
            id: "bleed-hit",
            name: "Bleed Hit",
            tier: .basic,
            amount: 2,
            keyword: .bleed,
        )
        try #expect(bleedHit.damageComponents == [DamageComponent(2, keyword: .bleed)])
        try #expect(bleedHit.targetedEffects.isEmpty)
        try #expect(bleedHit.summary == "Deal 2 Bleed damage.")
    }

    @Test func `empowered by mana raises burn and freeze numbers`() throws {
        let empowered = Ability.fireArrow.empoweredByMana()
        try #expect(Ability.fireArrow.hasManaEmpowerableBurnOrFreezeDamage)
        try #expect(empowered.damageComponents == [
            DamageComponent(2, keyword: .burn, bonusAmount: 2, condition: .enemyBurning),
        ])
        try #expect(empowered.targetedEffects.isEmpty)
        try #expect(!Ability.slash.hasManaEmpowerableBurnOrFreezeDamage)
        try #expect(Ability.slash.empoweredByMana() == Ability.slash)
        try #expect(
            Ability.blizzard.empoweredByMana().targetedEffects
                == [TargetedEffect(.recurringDamage(.freeze, 5, 2))],
        )
    }

    @Test func `buff only builder produces generated description`() throws {
        let ability = AbilityBuilder.buffOnly(
            id: "block",
            name: "Block",
            tier: .basic,
            effects: [.shield(.block, 2)],
        )
        try #expect(ability.summary == "Gain 2 Block.")
    }

    @Test func `multi damage builder formats summary`() throws {
        let ability = AbilityBuilder.multiDamage(
            id: "bloodthorn",
            name: "Bloodthorn",
            tier: .ultimate,
            damageComponents: [
                DamageComponent(2, keyword: .bleed),
                DamageComponent(2, keyword: .poison),
            ],
        )
        try #expect(
            ability.summary == "Deal 2 Bleed damage and deal 2 Poison damage.",
        )
    }

    @Test func `representative abilities keep typed contracts`() throws {
        try #expect(!Ability.hemorrhage.hasLeech)
        try #expect(Ability.hemorrhage.criticalChanceBonus == 0)
        try #expect(Ability.hemorrhage.targetedEffects == [
            TargetedEffect(.hemorrhage(4)),
        ])
        try #expect(Ability.serratedEdge.criticalChanceBonus == 0)
        try #expect(Ability.stab.directDamage == 2)
        try #expect(!Ability.bloodOffering.hasLeech)
        try #expect(!Ability.darkPact.hasLeech)
        try #expect(AbilityCatalog.all.contains { $0.id == "grave-pact" } == false)
        try #expect(Ability.heal.directDamage == 0)
        try #expect(Ability.fangs.hasLeech)
    }

    @Test func `glacial ward is skill with block and freeze retaliation`() throws {
        try #expect(Ability.glacialWard.tier == .skill)
    }

    @Test func `astral arrow offers stun freeze or burn branches`() throws {
        let ability = try #require(AbilityCatalog.ability(id: "astral-arrow"))
        let branches = try #require(ability.outcomeBranches)
        try #expect(branches.count == 3)
        try #expect(branches.map(\.damageComponents) == [
            [DamageComponent(7, keyword: .stun)],
            [DamageComponent(7, keyword: .freeze)],
            [DamageComponent(7, keyword: .burn)],
        ])
        try #expect(AbilityCatalog.ability(id: "concussive-shot") == nil)
        let ranger = try #require(GameContent.heroes.first { $0.id == "ranger" })
        try #expect(ranger.abilityChoices.ultimates.map(\.id).contains("astral-arrow"))
    }

    @Test func `description overrides are allowlisted`() throws {
        for ability in AbilityCatalog.all where ability.descriptionOverride != nil {
            try #expect(
                AbilityValidator.descriptionOverrideIDs.contains(ability.id),
                "\(ability.id) should not carry a manual description override",
            )
        }
    }

    @Test func `deals combat damage counts opponent hits not heals or block`() throws {
        try #expect(Ability.bash.dealsCombatDamage)
        try #expect(Ability.blizzard.dealsCombatDamage)
        try #expect(Ability.sunburst.dealsCombatDamage)
        try #expect(Ability.bloodOffering.dealsCombatDamage)
        try #expect(!Ability.apple.dealsCombatDamage)
        try #expect(!Ability.block.dealsCombatDamage)
        try #expect(!Ability.heal.dealsCombatDamage)
        try #expect(!Ability.briarShield.dealsCombatDamage)
        try #expect(!Ability.packTactics.dealsCombatDamage)
    }

    @Test func `validator allows condition-gated damage line`() throws {
        let ability = Ability(
            id: "gated-pounce",
            name: "Gated Pounce",
            tier: .skill,
            damageComponents: [
                DamageComponent(3, keyword: .stun, condition: .firstTurn),
            ],
        )
        let issues = AbilityValidator.validate(ability)
        try #expect(issues.isEmpty, "\(issues.map(\.description).joined(separator: "\n"))")
    }

    @Test func `ice shot shatters frozen enemies`() throws {
        let iceShot = try #require(AbilityCatalog.ability(id: "ice-shot"))
        try #expect(iceShot.summary == "Deal 2 Freeze damage. If this Freezes the enemy, deal 2 Physical damage.")
        try #expect(iceShot.damageComponents == [
            DamageComponent(2, keyword: .freeze),
            DamageComponent(2, keyword: .physical, condition: .enemyFrozen),
        ])
        try #expect(iceShot.keywords.contains(.physical))
        try #expect(iceShot.identityKeywords == [.freeze])
    }

    @Test func `serrated edge weakens enemy healing`() throws {
        try #expect(Ability.serratedEdge.summary == "Deal 2 Bleed damage. Reduces enemy Healing by 25% for 3 turns.")
        try #expect(Ability.serratedEdge.targetedEffects == [
            TargetedEffect(.healingReductionPercent(0.25, 3), target: .enemy),
        ])
    }

    @Test func `combustion detonates burning enemies`() throws {
        let combustion = try #require(AbilityCatalog.ability(id: "combustion"))
        try #expect(combustion.summary == "Deal 4 Burn damage. If the enemy is Burning, detonate all its remaining Burn at once, doubled.")
        try #expect(combustion.damageComponents == [DamageComponent(4, keyword: .burn)])
        try #expect(combustion.targetedEffects == [
            TargetedEffect(.detonateDoT(.burn, 2), target: .enemy, condition: .enemyBurning),
        ])
    }

    @Test func `validator rejects purge on ally in outcome branch`() throws {
        let ability = Ability(
            id: "bad-branch-purge",
            name: "Bad Branch Purge",
            tier: .skill,
            outcomeBranches: [
                AbilityOutcomeBranch(
                    targetedEffects: [TargetedEffect(.purgeRandom, target: .actor)],
                ),
            ],
        )
        let issues = AbilityValidator.validate(ability)
        try #expect(issues.contains { $0.message.contains("purge effects must target enemies") })
    }

    @Test func `resolving outcome branch picks branch using RNG`() {
        var rng = SeededRandomNumberGenerator(seed: 42)
        let resolvedTithe = Ability.tithe.resolvingOutcomeBranch(using: &rng)
        #expect(resolvedTithe.outcomeBranches == nil)
        #expect(resolvedTithe.damageComponents.count == 1 || resolvedTithe.targetedEffects.count == 1)

        let resolvedBash = Ability.bash.resolvingOutcomeBranch(using: &rng)
        #expect(resolvedBash.damageComponents == Ability.bash.damageComponents)
    }

    @Test func `locked revisions keep summaries and mechanics`() throws {
        try #expect(Ability.kindling.summary == "Deal 1 Burn damage. Your next Burn card deals +1 Burn damage.")
        try #expect(Ability.kindling.damageComponents == [DamageComponent(1, keyword: .burn)])
        try #expect(Ability.kindling.targetedEffects == [TargetedEffect(.nextBurnBonus(1), target: .actor)])
        try #expect(Ability.fireball.summary == "Deal 2 to 4 Burn damage.")
        try #expect(Ability.fireball.outcomeBranches?.map(\.damageComponents) == [
            [DamageComponent(2, keyword: .burn)],
            [DamageComponent(3, keyword: .burn)],
            [DamageComponent(4, keyword: .burn)],
        ])
        try #expect(Ability.slash.summary == "Deal 2 to 3 Physical damage.")
        try #expect(Ability.slash.outcomeBranches?.map(\.damageComponents) == [
            [DamageComponent(2, keyword: .physical)],
            [DamageComponent(3, keyword: .physical)],
        ])
        try #expect(Ability.stab.summary == "Deal 2 Physical damage with a +25% chance to Critically Hit.")
        try #expect(Ability.stab.damageComponents == [DamageComponent(2, keyword: .physical)])
        try #expect(Ability.stab.criticalChanceBonus == 0.25)
    }

    @Test func `sap arrow takes gold from stunned enemies`() throws {
        try #expect(Ability.sapArrow.summary == "Deal 3 Stun damage. If the enemy is Stunned, gain 2 Gold.")
        try #expect(Ability.sapArrow.damageComponents == [DamageComponent(3, keyword: .stun)])
        try #expect(Ability.sapArrow.targetedEffects == [
            TargetedEffect(.resourceGain(.gold, 2), condition: .enemyStunned),
        ])
    }

    @Test func `variable damage branches resolve within locked ranges`() throws {
        var rng = SeededRandomNumberGenerator(seed: 7)
        for _ in 0 ..< 12 {
            let resolvedFireball = Ability.fireball.resolvingOutcomeBranch(using: &rng)
            let fireballDamage = try #require(resolvedFireball.damageComponents.first?.amount)
            try #expect((2 ... 4).contains(fireballDamage))
            try #expect(resolvedFireball.outcomeBranches == nil)
            let resolvedSlash = Ability.slash.resolvingOutcomeBranch(using: &rng)
            let slashDamage = try #require(resolvedSlash.damageComponents.first?.amount)
            try #expect((2 ... 3).contains(slashDamage))
            try #expect(resolvedSlash.outcomeBranches == nil)
        }
    }

    @Test func `bloodthorn deals fixed bleed and poison with leech`() throws {
        let bloodthorn = try #require(AbilityCatalog.ability(id: "bloodthorn"))
        try #expect(bloodthorn.outcomeBranches == nil)
        try #expect(bloodthorn.damageComponents == [
            DamageComponent(3, keyword: .bleed),
            DamageComponent(3, keyword: .poison),
        ])
        try #expect(bloodthorn.hasLeech)
    }

    @Test func `branched abilities show shared riders`() throws {
        let bloodthorn = try #require(AbilityCatalog.ability(id: "bloodthorn"))
        try #expect(bloodthorn.summary == "Deal 3 Bleed damage and deal 3 Poison damage. Leech.")
        for ability in AbilityCatalog.all where ability.descriptionOverride == nil {
            if ability.hasLeech {
                try #expect(ability.summary.contains("Leech"), "\(ability.id) hides Leech")
            }
            if ability.repeatsManaEmpowerment {
                try #expect(ability.summary.contains("Mana"), "\(ability.id) hides empowerment")
            }
            if ability.criticalChanceBonus > 0 || ability.guaranteedCriticalIfEnemyBuffed {
                try #expect(ability.summary.contains("Critical"), "\(ability.id) hides critical rider")
            }
        }
    }
}
