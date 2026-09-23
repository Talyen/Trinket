import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct ThemedGearGeneratorTests {
    @Test func `generates fixed affix count per slot`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        var rng = SeededRandomNumberGenerator(seed: 99)
        let generator = ThemedGearGenerator()

        let build = generator.generate(
            for: knight,
            rarity: .basic,
            fixedAffixCount: 1,
            idPrefix: "themed",
            using: &rng,
        )

        let primaryID = try #require(build.loadout.itemID(for: .weapon))
        let primary = try #require(build.inventory.first { $0.id == primaryID })
        let expectedCount = knight.role.equipmentSlots.count(where: { $0 != .trinket })
            - (primary.baseType.weaponKind == .twoHanded ? 1 : 0)

        try #expect(build.inventory.count == expectedCount)
        try #expect(build.inventory.allSatisfy { $0.affixes.count == 1 })
        try #expect(build.loadout.itemIDsBySlot.count == expectedCount)
        try #expect(build.loadout.isAvailable(.secondaryWeapon, inventory: build.inventory)
            == (primary.baseType.weaponKind != .twoHanded))
    }

    @Test func `generates single aligned piece`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        var rng = SeededRandomNumberGenerator(seed: 44)
        let build = ThemedGearGenerator().generateSinglePiece(
            for: knight,
            rarity: .basic,
            fixedAffixCount: 1,
            idPrefix: "starter",
            keywordBias: Set(knight.abilities.flatMap(\.keywords)),
            requireBuildAlignment: true,
            using: &rng,
        )
        try #expect(build.inventory.count == 1)
        try #expect(build.inventory[0].affixes.count == 1)
        try #expect(build.loadout.itemIDsBySlot.count == 1)
    }

    @Test func `ranged loadout equips only a compatible secondary`() throws {
        let crossbow = try #require(GameContent.itemBaseType(matching: "crossbow"))
        let quiver = try #require(GameContent.itemBaseType(matching: "quiver"))
        let shield = try #require(GameContent.itemBaseType(matching: "kite_shield"))
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })

        let scenarios: [([ItemBaseType], String?)] = [
            ([crossbow, shield], nil),
            ([crossbow, shield, quiver], "quiver"),
        ]
        for (bases, expectedSecondary) in scenarios {
            var rng = SeededRandomNumberGenerator(seed: 1)
            let build = ThemedGearGenerator(baseTypes: bases).generate(
                for: knight,
                rarity: .basic,
                fixedAffixCount: 1,
                idPrefix: "ranged",
                keywordBias: [.physical, .bleed, .poison],
                using: &rng,
            )

            #expect(build.loadout.itemID(for: .weapon) != nil)
            let secondaryID = build.loadout.itemID(for: .secondaryWeapon)
            #expect(build.inventory.first { $0.id == secondaryID }?.baseType.id == expectedSecondary)
            #expect(Set(build.inventory.map(\.id)) == Set(build.loadout.itemIDsBySlot.values))
        }
    }

    @Test func `lone quiver cannot become starter gear`() throws {
        let quiver = try #require(GameContent.itemBaseType(matching: "quiver"))
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        var rng = SeededRandomNumberGenerator(seed: 1)

        let build = ThemedGearGenerator(baseTypes: [quiver]).generateSinglePiece(
            for: knight,
            rarity: .basic,
            fixedAffixCount: 1,
            idPrefix: "starter",
            using: &rng,
        )

        #expect(build.inventory.isEmpty)
        #expect(build.loadout.itemIDsBySlot.isEmpty)
    }

    @Test func `companion trinket slots use distinct bases`() throws {
        let boneCharm = try #require(GameContent.itemBaseType(matching: "bone_charm"))
        let collar = try #require(GameContent.itemBaseType(matching: "companions_collar"))
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })

        for bases in [[boneCharm], [boneCharm, collar]] {
            var rng = SeededRandomNumberGenerator(seed: 1)
            let build = ThemedGearGenerator(baseTypes: bases, includeTrinkets: true).generate(
                for: bear,
                rarity: .basic,
                fixedAffixCount: 1,
                idPrefix: "trinkets",
                keywordBias: [.health],
                using: &rng,
            )

            #expect(build.inventory.count == bases.count)
            #expect(Set(build.inventory.map(\.baseType.id)).count == bases.count)
            #expect(Set(build.inventory.map(\.id)) == Set(build.loadout.itemIDsBySlot.values))
        }
    }

    @Test func `keyword profile includes ability keywords`() throws {
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        try #expect(wizard.keywordProfile.contains(.burn))
    }

    @Test func `require build alignment rejects mismatched damage affixes`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let bias = Set(knight.abilityLoadout.abilities.flatMap(\.keywords))
        #expect(!bias.contains(.poison))

        var rng = SeededRandomNumberGenerator(seed: 7)
        let build = ThemedGearGenerator().generate(
            for: knight.withAbilityLoadout(knight.abilityLoadout),
            rarity: .astral,
            fixedAffixCount: 3,
            idPrefix: "aligned",
            keywordBias: bias,
            requireBuildAlignment: true,
            using: &rng,
        )

        let definitions = Dictionary(
            uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) },
        )
        for item in build.inventory {
            for affix in item.affixes {
                let definition = try #require(definitions[affix.id])
                try #expect(definition.isAligned(withBuildKeywords: bias))
                let damageKeywords = definition.keywords.filter { $0.category == .damageType }
                try #expect(damageKeywords.isSubset(of: bias))
            }
        }
    }
}
