import Foundation
import Testing
import TrinketContent

/// Every authored trigger-family field must be read by BattleEngine rule code.
struct CombatTriggerFieldCoverageTests {
    @Test func everyTriggerFieldIsReadByBattleEngine() throws {
        let names = CombatTraitTriggers.allFieldNames
        try #expect(!names.isEmpty)
        try #expect(Set(names).count == names.count, "duplicate trigger field names: \(duplicateNames(names))")

        let sources = try engineSources()
        let missing = names.filter { name in
            !sources.contains("." + name)
        }
        try #expect(missing.isEmpty, "Trigger fields never read by BattleEngine: \(missing.sorted())")
    }

    private func duplicateNames(_ names: [String]) -> [String] {
        Dictionary(grouping: names, by: { $0 }).compactMap { key, values in
            values.count > 1 ? key : nil
        }
        .sorted()
    }

    private func engineSources() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let engineDirectory = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/BattleEngine", isDirectory: true)
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: engineDirectory,
                includingPropertiesForKeys: nil
            ),
            "BattleEngine sources missing at \(engineDirectory.path)"
        )
        var files: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            if item.pathExtension == "swift" {
                files.append(item)
            }
        }
        try #expect(!files.isEmpty, "BattleEngine sources missing at \(engineDirectory.path)")
        return try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }
}
