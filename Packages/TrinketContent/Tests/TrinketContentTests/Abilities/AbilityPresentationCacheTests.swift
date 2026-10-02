import Testing
import TrinketCore
@testable import TrinketContent

struct AbilityPresentationCacheTests {
    @Test func `cached presentation preserves catalog text and keyword order`() {
        for ability in AbilityCatalog.all {
            let expectedDescription = AbilityDescriptionFormatter.format(ability)
            var expectedKeywords = ability.keywords
            for keyword in Keyword.referenced(in: ability.descriptionOverride ?? expectedDescription)
                where !expectedKeywords.contains(keyword) {
                expectedKeywords.append(keyword)
            }
            #expect(ability.generatedDescription == expectedDescription)
            #expect(ability.presentationKeywords == expectedKeywords)
        }
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
        #expect(Set([original, rebuilt]).count == 1)
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

    @Test func `concurrent first reads share consistent presentation`() async {
        let ability = Ability(id: "concurrent-cache", name: "Concurrent", tier: .basic, directDamage: 7, damageKeyword: .holy)
        let consistent = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for index in 0 ..< 16 {
                group.addTask {
                    // Exercise both acquisition orders while the caches are cold.
                    guard ability.keywords == [.holy], ability.identityKeywords == [.holy] else { return false }
                    if index.isMultiple(of: 2) {
                        return ability.generatedDescription == "Deal 7 Holy damage" && ability.presentationKeywords == [.holy]
                    }
                    return ability.presentationKeywords == [.holy] && ability.generatedDescription == "Deal 7 Holy damage"
                }
            }
            var allConsistent = true
            for await result in group {
                allConsistent = allConsistent && result
            }
            return allConsistent
        }
        #expect(consistent)
    }
}
