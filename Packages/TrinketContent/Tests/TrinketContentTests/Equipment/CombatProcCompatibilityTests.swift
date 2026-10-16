import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import TrinketContent

struct CombatProcCompatibilityTests {
    @Test(arguments: ["spitebloom", "ashen_wake", "cauterize", "mortar_and_pestle", "beacon"])
    func `saved proc rolls migrate once and remain inspectable and corruptible`(id: String) throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: id))
        var legacy = CombatTraitTriggers()
        switch id {
        case "spitebloom": legacy.poisonOnThornsDamage = 17
        case "ashen_wake":
            legacy.onBurnApplyPoison = 17
            legacy.onBurnDealPoisonChancePercent = 0.35
        case "cauterize":
            legacy.onBleedDealBurnDamage = 17
            legacy.onBleedDealBurnChancePercent = 0.35
        case "mortar_and_pestle": legacy.healthRestoredPoisonPercent = 0.6
        default: legacy.holyDamageHealFlat = 17
        }
        let old = ItemAffixPower(description: "Old proc", modifiers: [.maximumHealth(7)], triggers: legacy)
        let decoded = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([old]))
        let item = try ItemFixtures.makeBareItem("ruby_ring", affixes: [definition.resolved(for: .basic)], affixPowers: decoded)
        let current = try #require(item.resolvedPower(at: 0))
        #expect(current.modifiers == old.modifiers)
        #expect(current.triggers.poisonOnThornsDamage == 0)
        #expect(current.triggers.onBurnApplyPoison == 0)
        #expect(current.triggers.onBleedDealBurnDamage == 0)
        #expect(current.triggers.healthRestoredPoisonPercent == 0)
        #expect(current.triggers.holyDamageHealFlat == 0)
        #expect(current.triggers.onBurnDealPoisonChancePercent == 0)
        #expect(current.triggers.onBleedDealBurnChancePercent == 0)
        let magnitude: Double = switch id {
        case "spitebloom": Double(current.triggers.thornsDamageVsPoisonedFlat)
        case "ashen_wake": Double(current.triggers.burnDamageVsPoisonedFlat)
        case "cauterize": Double(current.triggers.bleedDamageVsBurningFlat)
        case "mortar_and_pestle": current.triggers.healthRestoredNextPoisonDamagePercent
        default: Double(current.triggers.firstHolyAttackHealPerTurn)
        }
        #expect(magnitude == (id == "beacon" ? 34 : id == "mortar_and_pestle" ? 0.6 : 17))
        let migrated = try ItemFixtures.makeBareItem("ruby_ring", affixes: item.affixes, affixPowers: [current])
        #expect(migrated.resolvedPower(at: 0) == current)
        #expect(item.affixPowers == decoded)
        #expect(item.isPerfectAffix(at: 0))
        var rng = SeededRandomNumberGenerator(seed: 3)
        let corrupted = try #require(ItemCorruption.apply(kinds: [.bumpUp], to: item, using: &rng))
        let stored = try #require(corrupted.item.affixPowers?.first)
        #expect(stored != current)
        #expect(stored.triggers == current.triggers || stored.modifiers == current.modifiers)
        #expect(stored.triggers.poisonOnThornsDamage == 0 && stored.triggers.holyDamageHealFlat == 0)
        #expect(stored.triggers.healthRestoredPoisonPercent == 0 && stored.triggers.onBurnApplyPoison == 0)
        #expect(stored.triggers.onBleedDealBurnDamage == 0)
    }

    @Test(arguments: ["ruby_ring", "double_axe"])
    func `Toxic Remedy describes its effective fraction after equipment scaling`(baseID: String) throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: "mortar_and_pestle"))
        let item = try ItemFixtures.makeBareItem(baseID, affixes: [definition.resolved(for: .basic)])
        let power = try #require(item.resolvedPower(at: 0))
        #expect(power.triggers.healthRestoredNextPoisonDamagePercent == 0.5 * Double(item.baseType.affixPowerMultiplier))
        #expect(power.description == (baseID == "ruby_ring"
                ? "Your next Poison attack gains bonus damage equal to half your latest healing received"
                : "Your next Poison attack gains bonus damage equal to 100% of your latest healing received"))
    }
}
