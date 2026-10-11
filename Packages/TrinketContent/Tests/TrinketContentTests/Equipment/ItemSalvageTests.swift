import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct ItemSalvageTests {
    @Test func `yields match slot and rarity table`() throws {
        let basicWeapon = try ItemFixtures.makeBareItem("longsword", rarity: .basic)
        let astralAccessory = try ItemFixtures.makeBareItem("sapphire_ring", rarity: .astral)
        let basicArmor = try ItemFixtures.makeBareItem("leather_armor", rarity: .basic)

        #expect(ItemSalvage.yields(for: basicWeapon) == [
            ResourceAmount(.iron, 8),
            ResourceAmount(.wood, 4),
        ])
        #expect(ItemSalvage.yields(for: astralAccessory) == [
            ResourceAmount(.herbs, 16),
            ResourceAmount(.gems, 8),
        ])
        #expect(ItemSalvage.yields(for: basicArmor) == [
            ResourceAmount(.hide, 8),
            ResourceAmount(.stone, 4),
        ])
    }
}
