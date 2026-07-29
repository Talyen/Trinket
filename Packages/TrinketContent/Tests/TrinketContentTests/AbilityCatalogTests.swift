import Testing
import TrinketCore
@testable import TrinketContent

struct AbilityCatalogTests {
    @Test func catalogIDsAreUniqueAndUnknownLookupReturnsNil() throws {
        let ids = AbilityCatalog.all.map(\.id)
        try #expect(
            Set(ids).count == ids.count,
            "Duplicate ability IDs: \(Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys)"
        )
        try #expect(AbilityCatalog.ability(id: "missing-ability") == nil)
    }

    @Test func doTPairingMatchesDamageComponents() throws {
        for ability in AbilityCatalog.all {
            if ["mana-berries", "pixie-dust", "faustian-bargain", "serrated-edge", "hemorrhage"].contains(ability.id) {
                continue
            }
            for component in ability.damageComponents where component.target == .abilityTarget {
                guard Effect.pairedDoT(keyword: component.keyword, potency: component.amount) != nil else {
                    continue
                }
                try #expect(
                    ability.effects.contains {
                        $0.keyword == component.keyword && $0.potency == component.amount
                    },
                    "\(ability.id) should pair \(component.keyword.rawValue) damage with .\(String(describing: component.keyword).lowercased())(\(component.amount))"
                )
            }
        }
    }

    @Test func catalogPassesValidation() throws {
        let issues = AbilityValidator.validateCatalog()
        try #expect(issues.isEmpty, "\(issues.map(\.description).joined(separator: "\n"))")
    }

    @Test func directHitBuilderAddsPairedDoT() throws {
        let ability = AbilityBuilder.directHit(
            id: "burn-hit",
            name: "Burn Hit",
            tier: .skill,
            amount: 3,
            keyword: .burn
        )
        try #expect(ability.damageComponents == [DamageComponent(3, keyword: .burn)])
        try #expect(ability.effects.contains {
            if case .burn(3) = $0 {
                return true
            }; return false
        })
        try #expect(ability.summary == "Deal 3 Burn damage.")
    }

    @Test func empoweredByManaRaisesBurnAndFreezeNumbers() throws {
        let empowered = Ability.fireArrow.empoweredByMana()
        try #expect(Ability.fireArrow.hasManaEmpowerableBurnOrFreezeDamage)
        try #expect(empowered.damageComponents == [DamageComponent(2, keyword: .burn)])
        try #expect(empowered.targetedEffects == [
            TargetedEffect(.burn(2)),
            TargetedEffect(.burn(2), condition: .enemyBurning),
        ])
        try #expect(!Ability.slash.hasManaEmpowerableBurnOrFreezeDamage)
        try #expect(Ability.slash.empoweredByMana() == Ability.slash)
        try #expect(
            Ability.blizzard.empoweredByMana().targetedEffects
                == [TargetedEffect(.recurringDamage(.freeze, 3, 2))]
        )
    }

    @Test func buffOnlyBuilderProducesGeneratedDescription() throws {
        let ability = AbilityBuilder.buffOnly(
            id: "block",
            name: "Block",
            tier: .basic,
            effects: [.shield(.block, 2)]
        )
        try #expect(ability.summary == "Gain 2 Block.")
    }

    @Test func multiDamageBuilderFormatsSummary() throws {
        let ability = AbilityBuilder.multiDamage(
            id: "bloodthorn",
            name: "Bloodthorn",
            tier: .ultimate,
            damageComponents: [
                DamageComponent(2, keyword: .bleed),
                DamageComponent(2, keyword: .poison),
            ],
            effects: [
                TargetedEffect(.bleed(2)),
                TargetedEffect(.poison(2)),
            ]
        )
        try #expect(
            ability.summary == "Deal 2 Bleed damage and Deal 2 Poison damage."
        )
    }

    @Test func representativeAbilitySummariesPreserveProductContracts() throws {
        try #expect(Ability.hemorrhage.summary == "Applies Bleeding.")
        try #expect(!Ability.hemorrhage.hasLeech)
        try #expect(Ability.hemorrhage.criticalChanceBonus == 0)
        try #expect(Ability.serratedEdge.summary == "Applies Bleeding.")
        try #expect(Ability.serratedEdge.criticalChanceBonus == 0)
        try #expect(Ability.stab.summary == "Deal 2 Physical damage.")
        try #expect(Ability.stab.directDamage == 2)
        try #expect(Ability.bloodOffering.summary == "Lose 1 Health. Deal 4 Bleed damage.")
        try #expect(Ability.darkPact.summary == "Lose 1 Health. Draw 2 cards.")
        try #expect(!Ability.bloodOffering.hasLeech)
        try #expect(!Ability.darkPact.hasLeech)
        try #expect(AbilityCatalog.all.contains { $0.id == "grave-pact" } == false)
        try #expect(Ability.heal.summary == "Restore 5 Health.")
        try #expect(Ability.heal.directDamage == 0)
        try #expect(Ability.fangs.hasLeech)
        try #expect(Ability.rendingSlash.name == "Rend")
    }

    @Test func astralArrowOffersStunFreezeOrBurnBranches() throws {
        let ability = try #require(AbilityCatalog.ability(id: "astral-arrow"))
        let branches = try #require(ability.outcomeBranches)
        try #expect(branches.count == 3)
        try #expect(branches.map(\.damageComponents) == [
            [DamageComponent(6, keyword: .stun)],
            [DamageComponent(6, keyword: .freeze)],
            [DamageComponent(6, keyword: .burn)],
        ])
        try #expect(AbilityCatalog.ability(id: "concussive-shot") == nil)
        let ranger = try #require(GameContent.heroes.first { $0.id == "ranger" })
        try #expect(ranger.abilityChoices.ultimates.map(\.id).contains("astral-arrow"))
    }

    @Test func descriptionOverridesAreAllowlisted() throws {
        for ability in AbilityCatalog.all where ability.descriptionOverride != nil {
            try #expect(
                AbilityValidator.descriptionOverrideIDs.contains(ability.id),
                "\(ability.id) should not carry a manual description override"
            )
        }
    }
}
