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

    @Test func `rebuilt definitions retain value equality and operation order`() {
        let rebuilt = Ability.sunder.replacingOperations(Ability.sunder.operations)
        #expect(rebuilt == Ability.sunder)
        #expect(Set([rebuilt, Ability.sunder]).count == 1)
        #expect(rebuilt.operations.first == .effect(TargetedEffect(.halveShield(.block), target: .enemy)))
    }

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

    @Test func `ultimate reworks match player facing summaries`() throws {
        let expected: [Ability: String] = [
            .avatarOfJustice: "Deal 6 Holy damage\nYour next attack deals Holy damage\nGain 6 Block",
            .blessedAegis: "Gain 5 Block\nRestore 5 Health to the lowest-Health ally\nDeal 5 Holy damage",
            .blizzard: "Deal 6 Freeze damage this turn and next",
            .combustion: "Deal 6 Burn damage\nDetonate all enemy Burn",
            .earthquake: "Deal 6 Stun damage this turn and next",
            .hemorrhage: "Deal 6 Bleed damage\nDetonate all Bleed",
            .luckPotion: "Roll a 12-sided die\nGain that much Block, Thorns, or Health",
            .moltenBulwark: "Deal 3 Burn damage\nGain 4 Block and Thorns",
            .panaceaPotion: "Cleanse the ally with the most status effects\nRestore 6 Health",
            .shadowstep: "Draw and play 1 card from your deck\nDodge the next attack against you",
            .sunburst: "Deal 6 Holy or Burn damage\nRestore 3 Health to each ally",
            .thornMail: "Gain 6 Block\nGain Thorns equal to half your Block",
        ]

        for (ability, summary) in expected {
            try #expect(ability.summary == summary, "Unexpected summary for \(ability.id)")
        }
    }

    @Test func `glacial ward is skill with block and freeze retaliation`() throws {
        try #expect(Ability.glacialWard.tier == .skill)
    }

    @Test func `shield bash describes ordered block-scaled stun damage`() throws {
        let shieldBash = try #require(AbilityCatalog.ability(id: "shield-bash"))
        try #expect(shieldBash.summary == "Gain 1 Block\nDeal Stun damage equal to half your Block")
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
        try #expect(Ability.packTactics.dealsCombatDamage)
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

    @Test func `ability rework summaries match player facing text`() throws {
        let expected: [Ability: String] = [
            .bountyShot: "Deal 3 Stun damage\nSteal 2 Gold",
            .cleanse: "Cleanse a harmful status effect\nRestore 3 Health",
            .coldSnap: "Deal 1 Freeze damage\nDouble the enemy's Freeze build-up",
            .darkPact: "Deal 1 Burn damage\nLose 1 Health\nDraw 2 cards",
            .fireball: "Deal 1 to 5 Burn damage",
            .frostbolt: "Deal 4 Freeze damage",
            .manaShield: "Gain 1 Block\nConvert all Mana into Block",
            .poisonDagger: "Deal 1 Poison damage, twice",
            .predatorsFocus: "Deal 1 Bleed damage\nYour next attack has Leech",
            .serratedEdge: "Deal 2 Bleed damage\nReduces Health restored by enemies by 25% for 3 turns",
            .spikedShield: "Deal 2 Physical damage\nGain 3 Block or Thorns at random",
        ]

        for (ability, summary) in expected {
            try #expect(ability.summary == summary, "Unexpected summary for \(ability.id)")
        }
        try #expect(AbilityCatalog.ability(id: "sap-arrow") == nil)
        let ranger = try #require(GameContent.hero(matching: "ranger"))
        try #expect(ranger.abilityChoices.skills.map(\.id) == ["pounce", "bounty-shot", "predators-focus", "serrated-edge"])
    }

    @Test func `variable damage branches resolve within locked ranges`() throws {
        var rng = SeededRandomNumberGenerator(seed: 7)
        for _ in 0 ..< 12 {
            let resolvedFireball = Ability.fireball.resolvingOutcomeBranch(using: &rng)
            let fireballDamage = try #require(resolvedFireball.damageComponents.first?.amount)
            try #expect((1 ... 5).contains(fireballDamage))
            try #expect(resolvedFireball.outcomeBranches == nil)
            let resolvedSlash = Ability.slash.resolvingOutcomeBranch(using: &rng)
            try #expect(resolvedSlash == Ability.slash)
        }
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
