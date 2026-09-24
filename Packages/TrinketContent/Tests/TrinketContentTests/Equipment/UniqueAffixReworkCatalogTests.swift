import Testing
import TrinketContent

struct UniqueAffixReworkCatalogTests {
    @Test func `reworked signatures use their new triggers`() throws {
        let harvest = try #require(GameContent.unique(matching: "red_harvest")?.affixPowers?.first)
        #expect(harvest.description == "Physical Critical Hits detonate Bleed.")
        #expect(harvest.triggers.redHarvestPhysicalCriticalDetonatesBleed)

        let hunt = try #require(GameContent.unique(matching: "huntsmasters_call")?.affixPowers?.first)
        #expect(hunt.description == "Your Physical Critical Hits draw from your Companion's deck.")
        #expect(hunt.triggers.huntsmasterPhysicalCriticalDrawsCompanion)

        let threefold = try #require(GameContent.unique(matching: "threefold_grace")?.affixPowers?.first)
        #expect(threefold.triggers.threefoldElementalDamageManaChancePercent == 0.10)

        let verdict = try #require(GameContent.unique(matching: "golden_verdict")?.affixPowers?.first)
        #expect(verdict.description == "Holy damage causes Stun build-up and steals 1 Gold when it Stuns an enemy.")
        #expect(verdict.triggers.holyStunBuildupPercent == 1)
        #expect(verdict.triggers.holyTriggeredStunGoldFlat == 1)
    }

    @Test(arguments: ["red_harvest", "huntsmasters_call", "threefold_grace", "golden_verdict"])
    func `owned Uniques resolve reworked signatures from older powers`(id: String) throws {
        let current = try #require(GameContent.unique(matching: id))
        var powers = try #require(current.affixPowers)
        var oldTriggers = CombatTraitTriggers()
        if id == "golden_verdict" {
            oldTriggers.holyStunBuildupPercent = 1
            oldTriggers.holyTriggeredStunGoldFlat = 1
        }
        powers[0] = ItemAffixPower(description: "Older signature", modifiers: [], triggers: oldTriggers)
        let owned = InventoryItem(
            id: "saved-\(id)", templateID: id, baseType: current.baseType,
            rarity: .unique, displayName: current.displayName,
            affixes: current.affixes, affixPowers: powers,
        )
        let restored = try #require(owned.resolvedPower(at: 0))
        #expect(restored.description == current.affixPowers?.first?.description)
        switch id {
        case "red_harvest": #expect(restored.triggers.redHarvestPhysicalCriticalDetonatesBleed)
        case "huntsmasters_call": #expect(restored.triggers.huntsmasterPhysicalCriticalDrawsCompanion)
        case "threefold_grace": #expect(restored.triggers.threefoldElementalDamageManaChancePercent == 0.10)
        case "golden_verdict": #expect(restored.triggers.holyStunBuildupPercent == 1)
        default: break
        }
    }
}
