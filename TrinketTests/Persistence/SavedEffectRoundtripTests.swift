import XCTest
@testable import Trinket

final class SavedEffectRoundtripTests: XCTestCase {
    func testAllEffectKindsRoundTrip() {
        let effects: [Effect] = [
            .burn(2),
            .poison(3),
            .bleed(4),
            .prevention(.stun, 1),
            .shield(.block, 5, 2),
            .mitigation(.armor, 0.5, 3),
            .instantHeal(.nature, 10),
            .leech(.holy, 0.25, 2),
            .resourceGain(.gold, 3),
            .cleanse(.poison, 1)
        ]

        for effect in effects {
            let roundTripped = SavedEffect(effect).effect()
            XCTAssertEqual(roundTripped, effect)
        }
    }

    func testCleanseAllRoundTrip() {
        let effect = Effect.cleanse(nil, 1)
        XCTAssertEqual(SavedEffect(effect).effect(), effect)
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
        XCTAssertEqual(restored.affixes[0].effect, affix.effect)
    }
}
