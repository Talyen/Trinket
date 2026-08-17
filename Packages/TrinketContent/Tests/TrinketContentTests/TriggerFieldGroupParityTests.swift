import Foundation
import Testing
@testable import TrinketContent

struct TriggerFieldGroupParityTests {
    @Test func everyTriggerStoredPropertyMapsToMatchingFIELD_GROUPFamily() throws {
        let repo = try #require(Self.repositoryRoot())
        let swiftFields = try Self.swiftFamilyByField(repo: repo)
        let fieldGroup = try Self.fieldGroupFromCodegen(repo: repo)
        #expect(Set(swiftFields.keys) == Set(fieldGroup.keys))
        for (field, family) in swiftFields {
            #expect(fieldGroup[field] == family, "\(field) Swift family \(family) vs FIELD_GROUP \(fieldGroup[field] ?? "missing")")
        }
    }

    @Test func boolTalentFlagsSurviveMergeIntoEmptyProfile() {
        var merged = CombatTraitTriggers()
        merged.merge(CombatTraitTriggers(gold: GoldTriggers(goldDoubledWhileFullHealth: true)))
        merged.merge(CombatTraitTriggers(attack: AttackTriggers(criticalPurgeAll: true)))
        #expect(merged.goldDoubledWhileFullHealth)
        #expect(merged.criticalPurgeAll)
    }

    @Test func sparseTriggerEncodingOmitsDefaultZeros() throws {
        let triggers = CombatTraitTriggers(block: BlockTriggers(holyIgnoresBlock: true))
        let data = try JSONEncoder().encode(triggers)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("holyIgnoresBlock"))
        #expect(!json.contains("ambushBonusDamage"))
        let decoded = try JSONDecoder().decode(CombatTraitTriggers.self, from: data)
        #expect(decoded == triggers)
    }

    @Test func everyBoolTriggerFieldORsDuringMerge() throws {
        let repo = try #require(Self.repositoryRoot())
        let content = repo.appendingPathComponent("Packages/TrinketContent/Sources/TrinketContent")
        let families = [
            "DamageTriggers.swift", "AttackTriggers.swift", "BlockTriggers.swift",
            "MitigationTriggers.swift", "DotTriggers.swift", "ControlTriggers.swift",
            "DodgeTriggers.swift", "ManaTriggers.swift", "GoldTriggers.swift",
            "HealingTriggers.swift", "RevivalTriggers.swift", "CleanseTriggers.swift",
            "EnemyTurnTriggers.swift", "OnHitTriggers.swift",
        ]
        let boolPattern = try NSRegularExpression(
            pattern: #"^    public var (\w+): Bool"#,
            options: .anchorsMatchLines
        )
        var missing: [String] = []
        for fileName in families {
            let text = try String(contentsOf: content.appendingPathComponent(fileName), encoding: .utf8)
            guard let mergeStart = text.range(of: "mutating func merge(_ other: Self)"),
                  let mergeBodyStart = text[mergeStart.upperBound...].range(of: "{"),
                  let mergeEnd = text[mergeBodyStart.upperBound...].range(of: "\n    }")
            else {
                throw TestFailure("\(fileName) is missing merge")
            }
            let merge = String(text[mergeBodyStart.upperBound ..< mergeEnd.lowerBound])
            let range = NSRange(text.startIndex..., in: text)
            for match in boolPattern.matches(in: text, range: range) {
                guard let nameRange = Range(match.range(at: 1), in: text) else { continue }
                let name = String(text[nameRange])
                let expected = "\(name) = \(name) || other.\(name)"
                if !merge.contains(expected) {
                    missing.append("\(fileName): \(name)")
                }
            }
        }
        #expect(missing.isEmpty, "Bool trigger fields missing OR merge: \(missing.joined(separator: ", "))")
    }

    @Test func everyTriggerFieldIsReferencedFromBattleEngine() throws {
        let repo = try #require(Self.repositoryRoot())
        let fields = try Self.swiftFamilyByField(repo: repo).keys.sorted()
        let engineRoot = repo.appendingPathComponent("Packages/BattleEngine/Sources/BattleEngine")
        let sources = try FileManager.default.enumerator(at: engineRoot, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        let engineText = try #require(sources)
        let unread = fields.filter { !engineText.contains($0) }
        #expect(unread.isEmpty, "Trigger fields with no BattleEngine reader: \(unread.joined(separator: ", "))")
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
            "DamageTriggers.swift": "damage",
            "AttackTriggers.swift": "attack",
            "BlockTriggers.swift": "block",
            "MitigationTriggers.swift": "mitigation",
            "DotTriggers.swift": "dot",
            "ControlTriggers.swift": "control",
            "DodgeTriggers.swift": "dodge",
            "ManaTriggers.swift": "mana",
            "GoldTriggers.swift": "gold",
            "HealingTriggers.swift": "healing",
            "RevivalTriggers.swift": "revival",
            "CleanseTriggers.swift": "cleanse",
            "EnemyTurnTriggers.swift": "enemyTurn",
            "OnHitTriggers.swift": "onHit",
        ]
        let content = repo.appendingPathComponent("Packages/TrinketContent/Sources/TrinketContent")
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

    private static func fieldGroupFromCodegen(repo: URL) throws -> [String: String] {
        let text = try String(contentsOf: repo.appendingPathComponent("Scripts/content_codegen.py"), encoding: .utf8)
        guard let start = text.range(of: "FIELD_GROUP = {"),
              let end = text[start.upperBound...].range(of: "\n    }")
        else {
            throw TestFailure("FIELD_GROUP not found")
        }
        let body = String(text[start.lowerBound ..< end.upperBound])
        let pattern = try NSRegularExpression(pattern: #""(\w+)": "(\w+)""#)
        let range = NSRange(body.startIndex..., in: body)
        var result: [String: String] = [:]
        let nsBody = body as NSString
        for match in pattern.matches(in: body, range: range) {
            result[nsBody.substring(with: match.range(at: 1))] = nsBody.substring(with: match.range(at: 2))
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
