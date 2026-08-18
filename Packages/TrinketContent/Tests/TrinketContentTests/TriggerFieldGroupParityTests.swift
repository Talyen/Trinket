import Foundation
import Testing
@testable import TrinketContent

struct TriggerFieldGroupParityTests {
    @Test func everyTriggerStoredPropertyMapsToMatchingSchemaFamily() throws {
        let repo = try #require(Self.repositoryRoot())
        let swiftFields = try Self.swiftFamilyByField(repo: repo)
        let fieldGroup = try Self.fieldGroupFromSchema(repo: repo)
        #expect(Set(swiftFields.keys) == Set(fieldGroup.keys))
        for (field, family) in swiftFields {
            #expect(fieldGroup[field] == family, "\(field) Swift family \(family) vs schema \(fieldGroup[field] ?? "missing")")
        }
    }

    @Test func boolTalentFlagsSurviveMergeIntoEmptyProfile() {
        var merged = CombatTraitTriggers()
        merged.merge(CombatTraitTriggers(gold: GoldTriggers(goldDoubledWhileFullHealth: true)))
        merged.merge(CombatTraitTriggers(attack: AttackTriggers(criticalPurgeAll: true)))
        #expect(merged.goldDoubledWhileFullHealth)
        #expect(merged.criticalPurgeAll)
    }

    private static func repositoryRoot() -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 5 {
            url.deleteLastPathComponent()
        }
        let codegen = url.appendingPathComponent("Scripts/content_codegen.py")
        return FileManager.default.fileExists(atPath: codegen.path) ? url : nil
    }

    private static func swiftFamilyByField(repo: URL) throws -> [String: String] {
        let families = [
            "DamageTriggers.generated.swift": "damage",
            "AttackTriggers.generated.swift": "attack",
            "BlockTriggers.generated.swift": "block",
            "MitigationTriggers.generated.swift": "mitigation",
            "DotTriggers.generated.swift": "dot",
            "ControlTriggers.generated.swift": "control",
            "DodgeTriggers.generated.swift": "dodge",
            "ManaTriggers.generated.swift": "mana",
            "GoldTriggers.generated.swift": "gold",
            "HealingTriggers.generated.swift": "healing",
            "RevivalTriggers.generated.swift": "revival",
            "CleanseTriggers.generated.swift": "cleanse",
            "EnemyTurnTriggers.generated.swift": "enemyTurn",
            "OnHitTriggers.generated.swift": "onHit",
        ]
        let content = repo.appendingPathComponent("Packages/TrinketContent/Sources/TrinketContent/Generated")
        var result: [String: String] = [:]
        let pattern = try NSRegularExpression(pattern: #"^    public var (\w+):"#, options: .anchorsMatchLines)
        for (fileName, family) in families {
            let text = try String(contentsOf: content.appendingPathComponent(fileName), encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for match in pattern.matches(in: text, range: range) {
                guard let nameRange = Range(match.range(at: 1), in: text) else { continue }
                result[String(text[nameRange])] = family
            }
        }
        return result
    }

    private static func fieldGroupFromSchema(repo: URL) throws -> [String: String] {
        let data = try Data(contentsOf: repo.appendingPathComponent("Scripts/trigger_family_schema.json"))
        guard let families = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw TestFailure("trigger_family_schema.json is not an array")
        }
        var result: [String: String] = [:]
        for family in families {
            guard let familyID = family["family"] as? String,
                  let fields = family["fields"] as? [[String: Any]]
            else {
                throw TestFailure("Malformed trigger family in schema")
            }
            for field in fields {
                guard let name = field["name"] as? String else {
                    throw TestFailure("Trigger field missing name")
                }
                result[name] = familyID
            }
        }
        return result
    }
}

private struct TestFailure: Error {
    let message: String
    init(_ message: String) {
        self.message = message
    }
}
