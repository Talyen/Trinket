import Foundation
import SwiftData
import TrinketContent
import TrinketCore
import TrinketPersistence

public enum SaveTestSupport {
    public static func makeTempDirectory(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix).\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func removeTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    public static func makeStoreURL(directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent("PlayerSave.sqlite")
    }

    public static func makeUserDefaults(suiteName: String) throws -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    public static func removeUserDefaults(suiteName: String, defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    public static func makeSideContext(storeURL: URL) throws -> ModelContext {
        try ModelContext(makeContainer(storeURL: storeURL))
    }

    @MainActor
    public static func makeSaveStore(
        directoryURL: URL,
        resetState: Bool = false,
        inMemoryOnly: Bool = false,
    ) throws -> PlayerSaveStore {
        try PlayerSaveStore(
            storeURL: makeStoreURL(directoryURL: directoryURL),
            disableCloudSync: true,
            resetState: resetState,
            inMemoryOnly: inMemoryOnly,
        )
    }

    /// Single container-construction truth shared by `makeSideContext` and
    /// `writeRoot` so test harness stays on the production store shape
    /// (same schema, file URL, no CloudKit mirroring).
    public static func makeContainer(
        storeURL: URL,
        schema: Schema = PlayerSaveGraph.schema,
    ) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none,
            ),
        )
    }

    /// Lightweight fixture: fresh roster/inventory plus explicit gold.
    /// For the full seeded roster use the overload below (defaults
    /// `roster: .testSeed`, `inventory: []`). The overloads intentionally
    /// differ: this one isolates gold-cap behavior from catalog content,
    /// the full one exercises realistic roster/inventory shapes.
    public static func makeSave(modifiedAt: Date, gold: Int = 0) -> PlayerSave {
        makeSave(
            modifiedAt: modifiedAt,
            worldSeed: PlayerSave.testWorldSeed,
            journey: .initial,
            roster: .freshStart,
            inventory: .freshStart,
            gold: gold,
        )
    }

    public static func makeSave(
        modifiedAt: Date = Date(),
        worldSeed: UInt64 = PlayerSave.testWorldSeed,
        journey: JourneyProgressState = .initial,
        roster: PlayerRosterState = .testSeed,
        inventory: PlayerInventoryState = PlayerInventoryState(items: []),
        homestead: PlayerHomesteadState = .freshStart,
        spires: PlayerSpiresState = .freshStart,
        labyrinth: PlayerLabyrinthState = .freshStart,
        gold: Int? = nil,
    ) -> PlayerSave {
        var resolvedRoster = roster
        if let gold {
            resolvedRoster.gold = gold
        }
        return PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: modifiedAt,
            sessionGeneration: 0,
            worldSeed: worldSeed,
            journey: journey,
            roster: resolvedRoster,
            inventory: inventory,
            homestead: homestead,
            spires: spires,
            labyrinth: labyrinth,
        )
    }

    public static func writeRoot(
        _ save: PlayerSave,
        to storeURL: URL,
        schema: Schema = PlayerSaveGraph.schema,
        additionalInserts: ((ModelContext) throws -> Void)? = nil,
    ) throws {
        let context = try ModelContext(makeContainer(storeURL: storeURL, schema: schema))
        context.insert(PlayerSaveRoot(save: save))
        try additionalInserts?(context)
        try context.save()
    }

    /// Item produced by the generator (rolled affixes/powers) for tests that
    /// need generated shapes. For a bare catalog item without generation, use
    /// `ItemFixtures.makeBareItem`. The default seed is the generated-item
    /// stream, intentionally distinct from the battle RNG seed
    /// (`CombatantFixtures.deterministicBattleSeed`).
    public static func makeGeneratedItem(
        baseID: String,
        rarity: Rarity,
        id: String? = nil,
        templateID: String? = nil,
        seed: UInt64 = 11,
    ) throws -> InventoryItem {
        guard let baseType = GameContent.itemBaseType(matching: baseID) else {
            throw PlayerSavePersistenceError.invalidSave("Unknown item base \(baseID)")
        }
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
        return ItemGenerator().generate(
            id: id ?? "\(baseID)-\(rarity.rawValue)",
            templateID: templateID ?? "\(baseID)-\(rarity.rawValue)",
            baseType: baseType,
            rarity: rarity,
            using: &randomNumberGenerator,
        )
    }
}
