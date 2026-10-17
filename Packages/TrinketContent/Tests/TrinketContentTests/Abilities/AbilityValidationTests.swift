import Testing
import TrinketCore
@testable import TrinketContent

struct AbilityValidationTests {
    @Test func `catalog operations target the correct side in every outcome`() {
        for ability in AbilityCatalog.all {
            let alternatives = [ability.operations] + (ability.outcomeBranches?.map(\.operations) ?? [])
                + (ability.conditionalOutcome.map { [$0.operations] } ?? [])
            for operation in alternatives.joined() {
                guard case let .effect(targeted) = operation else { continue }
                switch targeted.effect {
                case .cleanse, .cleanseRandom, .cleanseHealPerDebuff, .panacea:
                    #expect(
                        [.actor, .hero, .companion, .lowestHealthAlly, .eachAlly].contains(targeted.target),
                        "\(ability.id): Cleanse must target allies",
                    )
                case .purge, .purgeRandom:
                    #expect([.abilityTarget, .enemy].contains(targeted.target), "\(ability.id): Purge must target enemies")
                default: break
                }
            }
            if let override = ability.descriptionOverride {
                #expect(override != ability.generatedDescription, "\(ability.id): redundant description override")
            }
        }
    }

    @Test(arguments: [
        (0, "Deal 3 Stun damage if played on the first turn"),
        (2, "Deal 3 Stun damage\nDeal 2 extra Stun damage if played on the first turn"),
    ])
    func `conditional damage distinguishes a gated hit from bonus damage`(bonus: Int, expected: String) {
        let ability = Ability(
            id: "gated-pounce",
            name: "Gated Pounce",
            tier: .skill,
            damageComponents: [
                DamageComponent(3, keyword: .stun, bonusAmount: bonus, condition: .firstTurn),
            ],
        )
        #expect(ability.summary == expected)
    }
}
