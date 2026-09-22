import Testing
import TrinketCore
@testable import TrinketContent

struct KeywordCohesionTests {
    @Test func `keyword mechanics name their keywords`() throws {
        var missing: [String] = []
        for ability in AbilityCatalog.all where Keyword.referenced(in: ability.summary).isEmpty {
            missing.append("ability:\(ability.id)")
        }
        for (nodeID, talent) in CombatantTalentCatalog.signatureTalents where Keyword.referenced(in: talent.description).isEmpty {
            missing.append("talent:\(nodeID)")
        }
        for trait in GameContent.traits where Keyword.referenced(in: trait.description).isEmpty {
            // Ambush doubles any attack damage; its former Holy weakness is now a separate trait.
            if trait.id == "ambush" {
                #expect(trait.modifiers.isEmpty)
                #expect(trait.triggers == CombatTraitTriggers(damage: DamageTriggers(firstHitDoubleDamage: true)))
            } else {
                missing.append("trait:\(trait.id)")
            }
        }
        for definition in GameContent.itemAffixDefinitions {
            if Keyword.referenced(in: definition.basic.description).isEmpty {
                missing.append("affix-basic:\(definition.id)")
            }
            if Keyword.referenced(in: definition.astral.description).isEmpty {
                missing.append("affix-astral:\(definition.id)")
            }
        }
        for item in GameContent.uniqueItems {
            for affix in item.affixes where affix.id == item.id && Keyword.referenced(in: affix.description).isEmpty {
                missing.append("unique:\(item.id)")
            }
        }
        try #expect(missing.isEmpty, "Missing keywords: \(missing.sorted())")
    }

    @Test func `locked ability text and magnitudes match explicit choices`() throws {
        try #expect(Ability.pixieDust.summary == "Deal 1 Burn damage\nRestore 1 Mana")
        try #expect(Ability.astralArrow.summary == "Deal 7 Burn, Freeze, or Bleed damage")
        try #expect(Ability.tithe.summary == "Deal 2 Holy damage\nSteal 2 Gold")
        try #expect(Ability.bountyShot.summary == "Deal 3 Stun damage\nSteal 2 Gold")
        try #expect(Ability.avatarOfJustice.summary == "Deal 6 Holy damage\nYour next attack deals Holy damage\nGain 6 Block")
        try #expect(Ability.tithe.damageComponents == [DamageComponent(2, keyword: .holy)])
        try #expect(Ability.bountyShot.damageComponents == [DamageComponent(3, keyword: .stun)])
        try #expect(Ability.avatarOfJustice.operations == [
            .damage(DamageComponent(6, keyword: .holy)),
            .effect(TargetedEffect(.nextStrikeDamageKeywordOverride(.holy), target: .actor)),
            .effect(TargetedEffect(.shield(.block, 6), target: .actor)),
        ])
    }
}
