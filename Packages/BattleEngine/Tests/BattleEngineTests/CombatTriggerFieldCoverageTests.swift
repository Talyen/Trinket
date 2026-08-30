import Foundation
import Testing
import TrinketContent

struct CombatTriggerFieldCoverageTests {
    @Test func `every trigger field is read by battle engine`() throws {
        let names = CombatTraitTriggers.allFieldNames
        try #expect(!names.isEmpty)
        try #expect(Set(names).count == names.count, "duplicate trigger field names: \(duplicateNames(names))")

        let referencedIdentifiers = try engineReferencedIdentifiers()
        let missing = names.filter { name in
            !referencedIdentifiers.contains(name)
        }
        try #expect(missing.isEmpty, "Trigger fields never read by BattleEngine: \(missing.sorted())")
    }

    private func duplicateNames(_ names: [String]) -> [String] {
        Dictionary(grouping: names, by: { $0 }).compactMap { key, values in
            values.count > 1 ? key : nil
        }
        .sorted()
    }

    private func engineReferencedIdentifiers() throws -> Set<String> {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let engineDirectory = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/BattleEngine", isDirectory: true)
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: engineDirectory,
                includingPropertiesForKeys: nil,
            ),
            "BattleEngine sources missing at \(engineDirectory.path)",
        )
        var files: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            if item.pathExtension == "swift" {
                files.append(item)
            }
        }
        try #expect(!files.isEmpty, "BattleEngine sources missing at \(engineDirectory.path)")
        var identifiers = Set<String>()
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            var index = content.startIndex
            while let dotIndex = content[index...].firstIndex(of: ".") {
                let afterDot = content.index(after: dotIndex)
                var endIndex = afterDot
                while endIndex < content.endIndex {
                    let char = content[endIndex]
                    if char.isLetter || char.isNumber || char == "_" {
                        endIndex = content.index(after: endIndex)
                    } else {
                        break
                    }
                }
                if afterDot < endIndex {
                    identifiers.insert(String(content[afterDot ..< endIndex]))
                }
                index = endIndex < content.endIndex ? endIndex : content.endIndex
            }
        }
        return identifiers
    }
}
