import Testing
import TrinketCore
@testable import TrinketContent

struct AbilityPresentationCacheTests {
    @Test(arguments: [(Ability.bloodOffering, Keyword.bleed), (Ability.darkPact, Keyword.burn)])
    func `health costs do not give authored cards a physical identity`(ability: Ability, keyword: Keyword) {
        #expect(ability.keywords == [keyword])
        #expect(ability.identityKeywords == [keyword])
        #expect(ability.presentationKeywords.contains(.health))
        #expect(!ability.presentationKeywords.contains(.physical))
    }

    @Test(arguments: [false, true])
    func `health costs stay outside keywords across all outcome paths`(contributesToIdentity: Bool) {
        let cost = AbilityOperation.damage(DamageComponent(2, keyword: .physical, target: .actor))
        let ability = Ability(
            id: "branched-health-cost", name: "Branched Health Cost", tier: .skill,
            outcomeBranches: [AbilityOutcomeBranch(operations: [
                cost, .damage(DamageComponent(3, keyword: .freeze)),
                .effect(TargetedEffect(.shield(.block, 2), target: .actor)),
            ])],
            operations: [
                cost, .damage(DamageComponent(3, keyword: .bleed)),
                .damage(DamageComponent(2, keyword: .stun, condition: .enemyStunned)),
            ],
            conditionalOutcome: AbilityConditionalOutcome(
                condition: .enemyHasBlock,
                operations: [
                    cost, .damage(DamageComponent(3, keyword: .holy)),
                    .effect(TargetedEffect(.resourceGain(.mana, 2), target: .actor)),
                ],
                contributesToIdentity: contributesToIdentity,
            ),
        )
        #expect(ability.keywords == [.bleed, .stun, .freeze, .block, .holy, .mana])
        let identity: [Keyword] = contributesToIdentity
            ? [.bleed, .freeze, .block, .holy, .mana] : [.bleed, .freeze, .block]
        #expect(ability.identityKeywords == identity)
        #expect(ability.presentationKeywords.contains(.health))
        #expect(!ability.presentationKeywords.contains(.physical))
    }

    @Test func `multi hit damage totals stay inspectable after saturated empowerment`() {
        let ability = Ability(
            id: "saturated-hits", name: "Saturated Hits", tier: .skill,
            damageComponents: [DamageComponent(2, keyword: .burn), DamageComponent(3, keyword: .burn)],
        )
        #expect(ability.directDamage == 5)
        #expect(ability.empoweredByMana(amount: Int.max).directDamage == Int.max)
        #expect(ability.directDamage == 5)
    }

    @Test func `warm caches stay isolated across transformations and value equality`() {
        let original = Ability(
            id: "cached-presentation", name: "Cached Presentation", tier: .basic,
            directDamage: 4, damageKeyword: .burn, description: "Gain Gold and Mana",
        )
        let copy = original
        #expect(original.generatedDescription == "Deal 4 Burn damage")
        #expect(original.presentationKeywords == [.burn, .gold, .mana])
        #expect(original.keywords == [.burn])
        #expect(original.identityKeywords == [.burn])
        let replaced = original.replacingOperations([.damage(DamageComponent(9, keyword: .freeze))])
        #expect(replaced.generatedDescription == "Deal 9 Freeze damage")
        #expect(replaced.presentationKeywords == [.freeze, .gold, .mana])
        #expect(replaced.keywords == [.freeze])
        #expect(replaced.identityKeywords == [.freeze])
        #expect(replaced.summary == original.summary)
        #expect(copy.generatedDescription == "Deal 4 Burn damage")
        #expect(copy.presentationKeywords == [.burn, .gold, .mana])
        #expect(copy.keywords == [.burn])
        #expect(copy.identityKeywords == [.burn])

        let rebuilt = original.replacingOperations(original.operations)
        #expect(rebuilt == original)
        #expect(Set([original, rebuilt]).count == 1)
        #expect(rebuilt.presentationKeywords == original.presentationKeywords)
    }

    @Test func `empowerment and branch resolution refresh warmed presentation`() {
        let original = Ability(id: "empowered-cache", name: "Empowered", tier: .basic, directDamage: 2, damageKeyword: .burn)
        #expect(original.summary == "Deal 2 Burn damage")
        #expect(original.presentationKeywords == [.burn])
        let empowered = original.empoweredByMana(amount: 3)
        #expect(empowered.summary == "Deal 5 Burn damage")
        #expect(original.summary == "Deal 2 Burn damage")

        let branch = AbilityOutcomeBranch(damageComponents: [DamageComponent(6, keyword: .freeze)])
        let branched = Ability(
            id: "branched-cache", name: "Branched", tier: .skill,
            outcomeBranches: [branch, AbilityOutcomeBranch(damageComponents: [DamageComponent(4, keyword: .poison)])],
        )
        let originalSummary = branched.summary
        #expect(branched.presentationKeywords == [.freeze, .poison])
        #expect(branched.keywords == [.freeze, .poison])
        #expect(branched.identityKeywords == [.freeze, .poison])
        var rng = SeededRandomNumberGenerator(seed: 42)
        let resolved = branched.resolving(branch: branch, using: &rng)
        #expect(resolved.summary == "Deal 6 Freeze damage")
        #expect(resolved.presentationKeywords == [.freeze])
        #expect(resolved.keywords == [.freeze])
        #expect(resolved.identityKeywords == [.freeze])
        #expect(branched.summary == originalSummary)
        #expect(branched.presentationKeywords == [.freeze, .poison])
    }
}
