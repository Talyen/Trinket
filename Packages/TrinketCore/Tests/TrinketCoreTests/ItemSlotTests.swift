import Foundation
import Testing
import TrinketCore

struct ItemSlotTests {
    @Test func `all item slot cases have valid id and display attributes`() {
        for slot in ItemSlot.allCases {
            #expect(slot.id == slot.rawValue)
            #expect(slot.accessibilityIdentifier == "\(slot.rawValue) item slot")
            #expect(slot.displayName == slot.baseItemSlot.rawValue)
        }
    }

    @Test func `base slots resolution and secondary identification`() {
        #expect(ItemSlot.weapon.baseItemSlot == .weapon)
        #expect(!ItemSlot.weapon.isSecondary)

        #expect(ItemSlot.secondaryWeapon.baseItemSlot == .weapon)
        #expect(ItemSlot.secondaryWeapon.isSecondary)

        #expect(ItemSlot.armor.baseItemSlot == .armor)
        #expect(!ItemSlot.armor.isSecondary)

        #expect(ItemSlot.accessory.baseItemSlot == .accessory)
        #expect(!ItemSlot.accessory.isSecondary)

        #expect(ItemSlot.secondaryAccessory.baseItemSlot == .accessory)
        #expect(ItemSlot.secondaryAccessory.isSecondary)

        #expect(ItemSlot.trinket.baseItemSlot == .trinket)
        #expect(!ItemSlot.trinket.isSecondary)

        #expect(ItemSlot.secondaryTrinket.baseItemSlot == .trinket)
        #expect(ItemSlot.secondaryTrinket.isSecondary)

        #expect(ItemSlot.baseSlots == [.weapon, .armor, .accessory, .trinket])
    }

    @Test func `sibling and family slots resolution`() {
        #expect(ItemSlot.weapon.siblingSlot == .secondaryWeapon)
        #expect(ItemSlot.weapon.siblingSlots == [.secondaryWeapon])
        #expect(ItemSlot.weapon.familySlots == [.weapon, .secondaryWeapon])

        #expect(ItemSlot.secondaryWeapon.siblingSlot == .weapon)
        #expect(ItemSlot.secondaryWeapon.siblingSlots == [.weapon])
        #expect(ItemSlot.secondaryWeapon.familySlots == [.weapon, .secondaryWeapon])

        #expect(ItemSlot.armor.siblingSlot == nil)
        #expect(ItemSlot.armor.siblingSlots.isEmpty)
        #expect(ItemSlot.armor.familySlots == [.armor])

        #expect(ItemSlot.accessory.siblingSlot == .secondaryAccessory)
        #expect(ItemSlot.accessory.siblingSlots == [.secondaryAccessory])
        #expect(ItemSlot.accessory.familySlots == [.accessory, .secondaryAccessory])

        #expect(ItemSlot.secondaryAccessory.siblingSlot == .accessory)
        #expect(ItemSlot.secondaryAccessory.siblingSlots == [.accessory])
        #expect(ItemSlot.secondaryAccessory.familySlots == [.accessory, .secondaryAccessory])

        #expect(ItemSlot.trinket.siblingSlot == .secondaryTrinket)
        #expect(ItemSlot.trinket.siblingSlots == [.secondaryTrinket])
        #expect(ItemSlot.trinket.familySlots == [.trinket, .secondaryTrinket])

        #expect(ItemSlot.secondaryTrinket.siblingSlot == .trinket)
        #expect(ItemSlot.secondaryTrinket.siblingSlots == [.trinket])
        #expect(ItemSlot.secondaryTrinket.familySlots == [.trinket, .secondaryTrinket])
    }

    @Test func `item slot accepts base and secondary equivalents`() {
        #expect(ItemSlot.weapon.accepts(.weapon))
        #expect(ItemSlot.weapon.accepts(.secondaryWeapon))
        #expect(ItemSlot.secondaryWeapon.accepts(.weapon))
        #expect(!ItemSlot.weapon.accepts(.armor))

        #expect(ItemSlot.accessory.accepts(.secondaryAccessory))
        #expect(ItemSlot.secondaryAccessory.accepts(.accessory))
        #expect(!ItemSlot.accessory.accepts(.trinket))

        #expect(ItemSlot.trinket.accepts(.secondaryTrinket))
        #expect(ItemSlot.secondaryTrinket.accepts(.trinket))
        #expect(!ItemSlot.trinket.accepts(.weapon))
    }

    @Test func `item slot codable roundtrip`() throws {
        for slot in ItemSlot.allCases {
            let encoded = try JSONEncoder().encode(slot)
            let decoded = try JSONDecoder().decode(ItemSlot.self, from: encoded)
            #expect(decoded == slot)
        }
    }
}
