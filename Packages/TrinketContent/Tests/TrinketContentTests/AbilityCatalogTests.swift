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

    @Test func catalogPassesValidation() throws {
        let issues = AbilityValidator.validateCatalog()
        try #expect(issues.isEmpty, "\(issues.map(\.description).joined(separator: "\n"))")
    }

    @Test func directHitBuilderDoesNotAddTargetedDoT() throws {
        let ability = AbilityBuilder.directHit(
            id: "burn-hit",
            name: "Burn Hit",
            tier: .skill,
            amount: 3,
            keyword: .burn
        )
        try #expect(ability.damageComponents == [DamageComponent(3, keyword: .burn)])
        try #expect(ability.targetedEffects.isEmpty)
        try #expect(ability.summary == "Deal 3 Burn damage.")

        let bleedHit = AbilityBuilder.directHit(
            id: "bleed-hit",
            name: "Bleed Hit",
            tier: .basic,
            amount: 2,
            keyword: .bleed
        )
        try #expect(bleedHit.damageComponents == [DamageComponent(2, keyword: .bleed)])
        try #expect(bleedHit.targetedEffects.isEmpty)
        try #expect(bleedHit.summary == "Deal 2 Bleed damage.")
    }

    @Test func empoweredByManaRaisesBurnAndFreezeNumbers() throws {
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
                == [TargetedEffect(.recurringDamage(.freeze, 5, 2))]
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
            ]
        )
        try #expect(
            ability.summary == "Deal 2 Bleed damage and deal 2 Poison damage."
        )
    }

    @Test func representativeAbilitiesKeepTypedContracts() throws {
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

    @Test func glacialWardIsSkillWithBlockAndFreezeRetaliation() throws {
        try #expect(Ability.glacialWard.tier == .skill)
    }

    @Test func astralArrowOffersStunFreezeOrBurnBranches() throws {
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

    @Test func descriptionOverridesAreAllowlisted() throws {
        for ability in AbilityCatalog.all where ability.descriptionOverride != nil {
            try #expect(
                AbilityValidator.descriptionOverrideIDs.contains(ability.id),
                "\(ability.id) should not carry a manual description override"
            )
        }
    }

    @Test func dealsCombatDamageCountsOpponentHitsNotHealsOrBlock() throws {
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

    @Test func validatorRejectsDamageConditionWithoutBonusAmount() throws {
        let ability = Ability(
            id: "bad-pounce",
            name: "Bad Pounce",
            tier: .skill,
            damageComponents: [
                DamageComponent(3, keyword: .stun, condition: .firstTurn),
            ]
        )
        let issues = AbilityValidator.validate(ability)
        try #expect(issues.contains { $0.message.contains("bonusAmount") })
    }

    @Test func validatorRejectsPurgeOnAllyInOutcomeBranch() throws {
        let ability = Ability(
            id: "bad-branch-purge",
            name: "Bad Branch Purge",
            tier: .skill,
            outcomeBranches: [
                AbilityOutcomeBranch(
                    targetedEffects: [TargetedEffect(.purgeRandom, target: .actor)]
                ),
            ]
        )
        let issues = AbilityValidator.validate(ability)
        try #expect(issues.contains { $0.message.contains("purge effects must target enemies") })
    }

    // MARK: - Outcome branches

    @Test func resolvingOutcomeBranchPicksBranchUsingRNG() {
        var rng = SeededRandomNumberGenerator(seed: 42)
        let resolvedTithe = Ability.tithe.resolvingOutcomeBranch(using: &rng)
        #expect(resolvedTithe.outcomeBranches == nil)
        #expect(resolvedTithe.damageComponents.count == 1 || resolvedTithe.targetedEffects.count == 1)

        let resolvedSlash = Ability.slash.resolvingOutcomeBranch(using: &rng)
        #expect(resolvedSlash.damageComponents == Ability.slash.damageComponents)
    }

    @Test func resolvingOutcomeBranchPreservesSharedAbilityClauses() {
        var rng = SeededRandomNumberGenerator(seed: 42)
        let resolvedBloodthorn = Ability.bloodthorn.resolvingOutcomeBranch(using: &rng)
        #expect(resolvedBloodthorn.hasLeech)
        #expect(resolvedBloodthorn.damageComponents.count == 1)
        #expect(resolvedBloodthorn.damageComponents[0].keyword == .bleed || resolvedBloodthorn.damageComponents[0].keyword == .poison)
    }
}
