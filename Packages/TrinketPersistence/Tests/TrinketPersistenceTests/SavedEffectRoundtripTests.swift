import XCTest
import TrinketCore
import TrinketContent
@testable import TrinketPersistence

final class SavedEffectRoundtripTests: XCTestCase {
    func testAllEffectKindsRoundTrip() {
        let effects: [Effect] = [
            .burn(2),
            .poison(3),
            .bleed(4),
            .controlMeter(.stun, 3, 10),
            .controlMeter(.freeze, 7, 20),
            .shield(.block, 5, 2),
            .mitigation(.armor, 0.5, 3),
            .instantHeal(.nature, 10),
            .leech(.leech, Effect.standardLeechPercent, Effect.standardLeechDuration),
            .resourceGain(.gold, 3),
            .cleanse(.poison),
            .cleanse(nil),
            .cleanseRandom,
            .purge(.block),
            .purge(nil),
            .purgeRandom,
            .halveMitigation(.armor)
        ]

        for effect in effects {
            let roundTripped = SavedEffect(effect).effect()
            XCTAssertEqual(roundTripped, effect)
        }
    }

    func testLegacyDodgeEffectDecodesToNil() {
        let saved = SavedEffect.dodge(keyword: Keyword.dodge.rawValue, duration: 3)
        XCTAssertNil(saved.effect())
    }

    func testActiveEffectRoundTrip() {
        let active = ActiveEffect(id: 9, effect: .poison(6), remainingTicks: 0)
        let roundTripped = SavedActiveEffect(active).activeEffect()
        XCTAssertEqual(roundTripped, active)
    }

    func testInventoryItemWithAffixEffectsRoundTripsThroughSave() throws {
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.slot == .weapon })
        let affixDefinition = try XCTUnwrap(
            GameContent.itemAffixDefinitions.first { $0.id == "serrated" }
        )
        let affix = affixDefinition.resolved(for: .basic)
        let item = InventoryItem(
            id: "roundtrip-item",
            templateID: "roundtrip-template",
            baseType: baseType,
            rarity: .basic,
            displayName: "Bleeding Blade",
            affixes: [affix]
        )

        var save = PlayerSave.fresh
        save.inventory = SavedInventoryState(PlayerInventoryState(items: [item]))

        let encoder = PlayerSaveCoding.makeEncoder()
        let decoder = PlayerSaveCoding.makeDecoder()
        let data = try encoder.encode(save)
        let decoded = try decoder.decode(PlayerSave.self, from: data)
        let restored = try XCTUnwrap(decoded.inventory.inventory().items.first)

        XCTAssertEqual(restored.id, item.id)
        XCTAssertEqual(restored.affixes.count, 1)
        XCTAssertEqual(restored.affixes[0].description, affix.description)
    }
}
