import Testing
import TrinketCore
@testable import TrinketContent

struct AbilityCatalogTests {
    @Test func `luck potion covers every die face and combat outcome`() throws {
        let branches = try #require(Ability.luckPotion.outcomeBranches)
        #expect(branches.count == 36)
        var thornsAmounts: [Int] = []
        var blockAmounts: [Int] = []
        var healthAmounts: [Int] = []
        for targeted in branches.flatMap(\.targetedEffects) {
            switch targeted.effect {
            case let .thorns(amount):
                thornsAmounts.append(amount)
            case let .shield(.block, amount):
                blockAmounts.append(amount)
            case let .instantHeal(.health, amount):
                #expect(targeted.target == .lowestHealthAlly)
                healthAmounts.append(amount)
            default:
                Issue.record("Luck Potion branch did not grant Block, Thorns, or Health")
            }
        }
        #expect(thornsAmounts.sorted() == Array(1 ... 12))
        #expect(blockAmounts.sorted() == Array(1 ... 12))
        #expect(healthAmounts.sorted() == Array(1 ... 12))
    }

    @Test func `catalog I ds are unique and unknown lookup returns nil`() throws {
        let ids = AbilityCatalog.all.map(\.id)
        try #expect(
            Set(ids).count == ids.count,
            "Duplicate ability IDs: \(Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys)",
        )
        try #expect(AbilityCatalog.ability(id: "missing-ability") == nil)
    }

    @Test func `ability summaries use period-free nonempty effect lines`() {
        for ability in AbilityCatalog.all {
            #expect(!ability.summary.contains("."), "\(ability.id) contains period")
            let hasBlankLine = ability.summary.split(separator: "\n", omittingEmptySubsequences: false).contains { line in
                line.isEmpty
            }
            #expect(!hasBlankLine, "\(ability.id) has blank line")
        }
    }

    @Test func `direct damage init does not add targeted do T`() throws {
        let ability = Ability(
            id: "burn-hit",
            name: "Burn Hit",
            tier: .skill,
            directDamage: 3,
            damageKeyword: .burn,
        )
        try #expect(ability.damageComponents == [DamageComponent(3, keyword: .burn)])
        try #expect(ability.targetedEffects.isEmpty)
        try #expect(ability.summary == "Deal 3 Burn damage")

        let bleedHit = Ability(
            id: "bleed-hit",
            name: "Bleed Hit",
            tier: .basic,
            directDamage: 2,
            damageKeyword: .bleed,
        )
        try #expect(bleedHit.damageComponents == [DamageComponent(2, keyword: .bleed)])
        try #expect(bleedHit.targetedEffects.isEmpty)
        try #expect(bleedHit.summary == "Deal 2 Bleed damage")
    }

    @Test func `empowered by mana raises burn and freeze numbers`() throws {
        let empowered = Ability.fireArrow.empoweredByMana()
        try #expect(Ability.fireArrow.hasManaEmpowerableBurnOrFreezeDamage)
        try #expect(empowered.damageComponents == [
            DamageComponent(3, keyword: .burn),
        ])
        try #expect(empowered.targetedEffects.isEmpty)
        try #expect(!Ability.slash.hasManaEmpowerableBurnOrFreezeDamage)
        try #expect(Ability.slash.empoweredByMana() == Ability.slash)
        try #expect(
            Ability.blizzard.empoweredByMana().targetedEffects
                == [TargetedEffect(.recurringDamage(.freeze, 7, 1))],
        )
    }

    @Test func `effects init produces generated description`() throws {
        let ability = Ability(
            id: "block",
            name: "Block",
            tier: .basic,
            effects: [.shield(.block, 2)],
        )
        try #expect(ability.summary == "Gain 2 Block")
    }

    @Test func `damage components init formats summary`() throws {
        let ability = Ability(
            id: "bloodthorn",
            name: "Bloodthorn",
            tier: .ultimate,
            damageComponents: [
                DamageComponent(2, keyword: .bleed),
                DamageComponent(2, keyword: .poison),
            ],
        )
        try #expect(
            ability.summary == "Deal 2 Bleed damage\nDeal 2 Poison damage",
        )
    }

    @Test func `representative abilities keep typed contracts`() throws {
        try #expect(!Ability.hemorrhage.hasLeech)
        try #expect(Ability.hemorrhage.criticalChanceBonus == 0)
        try #expect(Ability.hemorrhage.targetedEffects == [
            TargetedEffect(.detonateDoT(.bleed, 1), target: .enemy, condition: .enemyBleeding),
        ])
        try #expect(Ability.serratedEdge.criticalChanceBonus == 0)
        try #expect(Ability.stab.directDamage == 2)
        try #expect(!Ability.bloodOffering.hasLeech)
        try #expect(!Ability.darkPact.hasLeech)
        try #expect(AbilityCatalog.all.contains { $0.id == "grave-pact" } == false)
        try #expect(Ability.heal.directDamage == 0)
        try #expect(Ability.fangs.hasLeech)
    }

    @Test func `shield bash describes ordered block-scaled stun damage`() throws {
        let shieldBash = try #require(AbilityCatalog.ability(id: "shield-bash"))
        try #expect(shieldBash.summary == "Gain 1 Block\nDeal Stun damage equal to half your Block (minimum 1)")
        try #expect(shieldBash.operations == [
            .effect(TargetedEffect(.shield(.block, 1))),
            .damage(DamageComponent(
                0,
                keyword: .stun,
                scaling: .actorBlockFraction(divisor: 2, minimum: 1),
            )),
        ])
    }

    @Test func `astral arrow offers burn freeze or bleed branches`() throws {
        let ability = try #require(AbilityCatalog.ability(id: "astral-arrow"))
        let branches = try #require(ability.outcomeBranches)
        try #expect(branches.count == 3)
        try #expect(branches.map(\.damageComponents) == [
            [DamageComponent(7, keyword: .burn)],
            [DamageComponent(7, keyword: .freeze)],
            [DamageComponent(7, keyword: .bleed)],
        ])
        try #expect(AbilityCatalog.ability(id: "concussive-shot") == nil)
        let ranger = try #require(GameContent.heroes.first { $0.id == "ranger" })
        try #expect(ranger.abilityChoices.ultimates.map(\.id).contains("astral-arrow"))
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
        try #expect(Ability.packTactics.dealsCombatDamage)
    }

    @Test func `ice shot retains freeze identity with doubled freeze damage`() throws {
        let iceShot = try #require(AbilityCatalog.ability(id: "ice-shot"))
        try #expect(iceShot.summary == "Deal 2 Freeze damage\nDoubled against Frozen enemies")
        try #expect(iceShot.damageComponents == [
            DamageComponent(2, keyword: .freeze, bonusAmount: 2, condition: .enemyFrozen),
        ])
        #expect(iceShot.conditionalOutcome == nil)
        try #expect(iceShot.identityKeywords == [.freeze])
    }

    @Test func `enemy-targeted damage appears in card text`() {
        let ability = Ability(
            id: "enemy-aimed-test",
            name: "Enemy Aimed",
            tier: .skill,
            damageComponents: [DamageComponent(3, keyword: .physical, target: .enemy)],
        )
        #expect(ability.generatedDescription == "Deal 3 Physical damage")
    }

    @Test func `serrated edge weakens enemy healing`() throws {
        try #expect(Ability.serratedEdge.summary == "Deal 2 Bleed damage\nReduces Health restored by enemies by 25% for 3 turns")
        try #expect(!Ability.serratedEdge.keywords.contains(.health))
        try #expect(Ability.serratedEdge.presentationKeywords.contains(.health))
        try #expect(Ability.serratedEdge.targetedEffects == [
            TargetedEffect(.healingReductionPercent(0.25, 3), target: .enemy),
        ])
    }

    @Test func `combustion detonates burning enemies`() throws {
        let combustion = try #require(AbilityCatalog.ability(id: "combustion"))
        try #expect(combustion.damageComponents == [DamageComponent(6, keyword: .burn)])
        try #expect(combustion.targetedEffects == [
            TargetedEffect(.detonateDoT(.burn, 1), target: .enemy, condition: .enemyBurning),
        ])
    }

    @Test func `locked revisions keep summaries and mechanics`() throws {
        try #expect(Ability.kindling.summary == "Deal 1 Burn damage\nDoubled if enemy was not Burning")
        try #expect(Ability.kindling.damageComponents == [
            DamageComponent(1, keyword: .burn, bonusAmount: 1, condition: .enemyNotBurning),
        ])
        try #expect(Ability.kindling.targetedEffects.isEmpty)
        try #expect(Ability.fireball.summary == "Deal 1 to 5 Burn damage")
        try #expect(Ability.fireball.outcomeBranches?.map(\.damageComponents) == [
            [DamageComponent(1, keyword: .burn)],
            [DamageComponent(2, keyword: .burn)],
            [DamageComponent(3, keyword: .burn)],
            [DamageComponent(4, keyword: .burn)],
            [DamageComponent(5, keyword: .burn)],
        ])
        try #expect(Ability.frostbolt.summary == "Deal 4 Freeze damage")
        try #expect(Ability.slash.summary == "Deal 3 Physical damage")
        try #expect(Ability.slash.outcomeBranches == nil)
        try #expect(Ability.slash.damageComponents == [DamageComponent(3, keyword: .physical)])
        try #expect(Ability.stab.summary == "Deal 2 Physical damage\nCritically Hit enemies at full Health")
        try #expect(Ability.stab.damageComponents == [DamageComponent(2, keyword: .physical)])
        try #expect(Ability.stab.criticalChanceBonus == 0)
        #expect(Ability.stab.guaranteedCriticalCondition == .enemyFullHealth)
    }

    @Test func `ranger choices exclude the retired theft card`() throws {
        try #expect(AbilityCatalog.ability(id: "sap-arrow") == nil)
        let ranger = try #require(GameContent.hero(matching: "ranger"))
        try #expect(ranger.abilityChoices.skills.map(\.id) == ["bounty-shot", "pounce", "predators-focus", "serrated-edge"])
    }

    @Test func `bloodthorn deals fixed bleed and poison with leech`() throws {
        let bloodthorn = try #require(AbilityCatalog.ability(id: "bloodthorn"))
        try #expect(bloodthorn.outcomeBranches == nil)
        try #expect(bloodthorn.damageComponents == [
            DamageComponent(2, keyword: .bleed),
            DamageComponent(2, keyword: .poison),
        ])
        try #expect(bloodthorn.hasLeech)
    }

    @Test func `branched abilities show shared riders`() throws {
        let bloodthorn = try #require(AbilityCatalog.ability(id: "bloodthorn"))
        try #expect(bloodthorn.summary == "Deal 2 Bleed damage\nDeal 2 Poison damage\nLeech")
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
