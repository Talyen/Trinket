import Testing
import TrinketCore
@testable import TrinketContent

struct AbilityValidationTests {
    @Test func `catalog passes validation`() throws {
        let issues = AbilityValidator.validateCatalog()
        try #expect(issues.isEmpty, "\(issues.map(\.description).joined(separator: "\n"))")
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

    @Test func `validator rejects redundant description override matching generated copy`() throws {
        let ability = Ability(
            id: "bash",
            name: "Bash",
            tier: .basic,
            directDamage: 3,
            damageKeyword: .stun,
            description: "Deal 3 Stun damage",
        )
        let issues = AbilityValidator.validate(ability)
        try #expect(issues.contains { $0.message.contains("description override is redundant") })
    }

    @Test(arguments: [
        TargetedEffect(.cleanse(nil), target: .enemy),
        TargetedEffect(.purgeRandom, target: .actor),
        TargetedEffect(.panacea(baseHeal: 2, healPerDebuff: 1), target: .enemy),
    ])
    func `validator rejects misplaced cleansing and purge in every authored path`(targeted: TargetedEffect) {
        for ability in abilities(with: [.effect(targeted)]) {
            let issues = AbilityValidator.validate(ability)
            #expect(issues.contains { $0.message.contains("must target") }, "\(ability.id): \(targeted)")
        }
    }

    @Test func `validator permits cleansing all allies`() {
        for ability in abilities(with: [.effect(TargetedEffect(.cleanse(nil), target: .eachAlly))]) {
            let issues = AbilityValidator.validate(ability)
            #expect(issues.isEmpty, "\(issues)")
        }
    }

    @Test(arguments: [EffectTarget.abilityTarget, .enemy])
    func `validator checks enemy damage tier in every authored path`(target: EffectTarget) {
        for ability in abilities(with: [.damage(DamageComponent(9, target: target))]) {
            let issues = AbilityValidator.validate(ability)
            #expect(issues.contains { $0.message.contains("enemy damage total 9 is unusual") }, "\(ability.id)")
        }
    }

    private func abilities(with operations: [AbilityOperation]) -> [Ability] {
        [
            Ability(id: "fixed", name: "Fixed", tier: .skill, operations: operations),
            Ability(
                id: "branched", name: "Branched", tier: .skill,
                outcomeBranches: [AbilityOutcomeBranch(operations: operations)],
            ),
            Ability(
                id: "conditional", name: "Conditional", tier: .skill,
                conditionalOutcome: AbilityConditionalOutcome(condition: .enemyHasBlock, operations: operations),
            ),
        ]
    }
}
