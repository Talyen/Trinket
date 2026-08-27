import Foundation
import SwiftData
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Shared temp-directory save-store harness for Persistence and AppState tests.
///
/// Lives as its own target in this package (not `TrinketTestSupport`) so
/// TestSupport stays Persistence-free and the package graph stays acyclic.
/// Hosting it in the Persistence package lets `TrinketPersistenceTests`
/// `@testable`-import the store without SwiftPM linking two copies.
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

    public static func makeSideContext(storeURL: URL) throws -> ModelContext {
        let schema = PlayerSaveGraph.schema
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        )
        return ModelContext(container)
    }

    @MainActor
    public static func makeSaveStore(directoryURL: URL, persistImmediately: Bool = true) throws -> PlayerSaveStore {
        try PlayerSaveStore(
            storeURL: makeStoreURL(directoryURL: directoryURL),
            disableCloudSync: true,
            persistSaveImmediately: persistImmediately
        )
    }

    public static func makeSave(modifiedAt: Date, gold: Int = 0) -> PlayerSave {
        var save = PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: modifiedAt,
            worldSeed: PlayerSave.testWorldSeed,
            journey: .initial,
            roster: .freshStart,
            inventory: .freshStart
        )
        save.roster.gold = gold
        return save
    }

    /// Shared `PlayerSave` fixture with the deterministic test-seed defaults used
    /// across Persistence applier tests. Overrides let a test swap a slice.
    public static func makeSave(
        roster: PlayerRosterState = .testSeed,
        inventory: PlayerInventoryState = PlayerInventoryState(items: []),
        homestead: PlayerHomesteadState = .freshStart,
        journey: JourneyProgressState = .initial
    ) -> PlayerSave {
        PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            worldSeed: PlayerSave.testWorldSeed,
            journey: journey,
            roster: roster,
            inventory: inventory,
            homestead: homestead
        )
    }

    public static func writeRoot(
        _ save: PlayerSave,
        to storeURL: URL,
        schema: Schema = PlayerSaveGraph.schema,
        additionalInserts: ((ModelContext) throws -> Void)? = nil
    ) throws {
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        )
        let context = ModelContext(container)
        context.insert(PlayerSaveRoot(save: save))
        try additionalInserts?(context)
        try context.save()
    }

    public static func makeGeneratedItem(
        baseID: String,
        rarity: Rarity,
        id: String? = nil,
        templateID: String? = nil,
        seed: UInt64 = 11
    ) throws -> InventoryItem {
        guard let baseType = GameContent.itemBaseTypes.first(where: { $0.id == baseID }) else {
            throw PlayerSavePersistenceError.invalidSave("Unknown item base \(baseID)")
        }
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
        return ItemGenerator().generate(
            id: id ?? "\(baseID)-\(rarity.rawValue)",
            templateID: templateID ?? "\(baseID)-\(rarity.rawValue)",
            baseType: baseType,
            rarity: rarity,
            using: &randomNumberGenerator
        )
    }
}
