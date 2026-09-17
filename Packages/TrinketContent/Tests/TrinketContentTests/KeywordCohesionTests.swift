import Testing
import TrinketCore
@testable import TrinketContent

struct KeywordCohesionTests {
    @Test func `every ability talent trait affix and unique signature has a keyword`() throws {
        var missing: [String] = []
        for ability in AbilityCatalog.all where Keyword.referenced(in: ability.summary).isEmpty {
            missing.append("ability:\(ability.id)")
        }
        for (nodeID, talent) in CombatantTalentCatalog.signatureTalents where Keyword.referenced(in: talent.description).isEmpty {
            missing.append("talent:\(nodeID)")
        }
        for trait in GameContent.traits where Keyword.referenced(in: trait.description).isEmpty {
            missing.append("trait:\(trait.id)")
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
        try #expect(Ability.pixieDust.summary == "Deal 1 Burn damage and restore 1 Mana.")
        try #expect(Ability.astralArrow.summary == "Deal 7 Burn, Freeze, or Bleed damage.")
        try #expect(Ability.tithe.summary == "Deal 2 Holy damage and Steal 2 Gold.")
        try #expect(Ability.bountyShot.summary == "Deal 3 Physical damage and Steal 2 Gold.")
        try #expect(Ability.avatarOfJustice.summary == "Deal 6 Holy damage now and for 2 more turns.")
        // sapArrow identity (id/name) is locked in AbilityCatalogTests; only
        // mechanics live here so wording tweaks break one suite.
        try #expect(Ability.tithe.damageComponents == [DamageComponent(2, keyword: .holy)])
        try #expect(Ability.bountyShot.damageComponents == [DamageComponent(3, keyword: .physical)])
        try #expect(Ability.avatarOfJustice.targetedEffects == [
            TargetedEffect(.avatar(holyDamage: 6, blockPerTurn: 0, turns: 2)),
        ])
    }
}
