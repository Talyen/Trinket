import Foundation
import Testing
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct PlaythroughWorkerRequest: Codable {
    var scenarioPath: String?
    var operation: String
    var output: String
    var seed: UInt64
    var horizon: Int
    var fullAccess: Bool
    var mode: String?
    var policy: String?
    var hero: String?
    var companion: String?
    var source: String?
    var crashAfter: Int?
    var crashSettlement: Bool?
    var expected: String?
}

@Suite(.serialized)
@MainActor
struct PlaythroughSweepTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TRINKET_PLAYTHROUGH_REQUEST"] != nil))
    func `run owned worker`() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["TRINKET_PLAYTHROUGH_REQUEST"])
        let request = try JSONDecoder().decode(PlaythroughWorkerRequest.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let output = URL(fileURLWithPath: request.output)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try Data(String(ProcessInfo.processInfo.processIdentifier).utf8).write(
            to: output.appendingPathComponent("worker-pid.txt"),
            options: .atomic,
        )
        do {
            try await executeRequest(request, output: output)
        } catch {
            let summaryURL = output.appendingPathComponent("summary.json")
            if !FileManager.default.fileExists(atPath: summaryURL.path) {
                var summary = PlaythroughSummary()
                summary.termination = (error as? PlaythroughFailure)?.termination ?? "workerFailure"
                summary.diagnostic = String(describing: error)
                try JSONEncoder().encode(summary).write(to: summaryURL, options: .atomic)
            }
            throw error
        }
    }

    private func executeRequest(_ request: PlaythroughWorkerRequest, output: URL) async throws {
        if request.operation == "recover" {
            try recover(request, output: output)
            return
        }
        var scenario = PlaythroughScenario()
        scenario.worldSeed = request.seed
        scenario.combatSeed ^= request.seed
        scenario.attempts = request.horizon
        scenario.fullAccess = request.fullAccess
        scenario.mode = request.mode ?? "campaign"
        scenario.policy = request.policy ?? "greedy-v1"
        scenario.heroID = request.hero ?? "knight"
        scenario.companionID = request.companion ?? "wolf"
        if let path = request.scenarioPath {
            scenario = try JSONDecoder().decode(PlaythroughScenario.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            scenario.worldSeed = request.seed
        }
        if let source = request.source {
            scenario = try JSONDecoder().decode(
                PlaythroughScenario.self,
                from: Data(contentsOf: URL(fileURLWithPath: source).appendingPathComponent("scenario.json")),
            )
        }
        let career = try PlaythroughCareer(scenario: scenario, output: output)
        defer { career.close() }
        career.crashAfter = request.crashAfter
        career.crashOnSettlement = request.crashSettlement ?? false
        if let source = request.source {
            try await replay(career, source: URL(fileURLWithPath: source))
        } else {
            _ = try await career.run(reload: true)
        }
    }

    private func replay(_ career: PlaythroughCareer, source: URL) async throws {
        let data = try Data(contentsOf: source.appendingPathComponent("actions.jsonl"))
        let records = try data.split(separator: 0x0A).map { try PlaythroughJournal.decodeRecord(Data($0)) }
        var index = 0
        while index < records.count {
            let attempt = records[index]
            guard attempt.result == nil, attempt.sequence == career.sequence + 1,
                  attempt.state == career.snapshot,
                  attempt.battle == career.battleObservation else { throw PlaythroughFailure.divergence(attempt.sequence) }
            var commandResult = "committed"
            do { try await career.perform(attempt.action) } catch { commandResult = String(describing: error) }
            index += 1
            if index < records.count {
                let result = records[index]
                guard result.sequence == attempt.sequence, result.action == attempt.action,
                      result.result == commandResult, result.state == career.snapshot, result.battle == career.battleObservation else {
                    throw PlaythroughFailure.divergence(attempt.sequence)
                }
                index += 1
                if commandResult != "committed" {
                    guard index == records.count else { throw PlaythroughFailure.divergence(attempt.sequence) }
                    career.summary.diagnostic = commandResult
                }
            } else if commandResult != "committed" {
                throw PlaythroughFailure.divergence(attempt.sequence)
            }
        }
        career.summary.termination = career.summary.diagnostic != nil ? "reproducedFailure"
            : records.last?.result == nil ? "replayedUnknownOutcome" : "replayedRecordedActions"
        try career.journal.finish(career.summary)
        try JSONEncoder().encode(career.snapshot).write(
            to: career.journal.directory.appendingPathComponent("final-save.json"),
            options: .atomic,
        )
    }

    private func recover(_ request: PlaythroughWorkerRequest, output: URL) throws {
        let source = try #require(request.source)
        // The wrapper archives raw files before this disposable copy is opened.
        let storeDirectory = output.appendingPathComponent("store")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: source).appendingPathComponent("store"), to: storeDirectory)
        let store = try SaveTestSupport.makeSaveStore(directoryURL: storeDirectory)
        let records = try Data(contentsOf: URL(fileURLWithPath: source).appendingPathComponent("actions.jsonl"))
            .split(separator: 0x0A).map { try PlaythroughJournal.decodeRecord(Data($0)) }
        let last = try #require(records.last)
        // A launch consumes its recorded seed but does not commit save changes.
        // Other interrupted commands require a replayed post-command snapshot.
        let expected: CloudSaveSnapshot
        if let path = request.expected {
            expected = try JSONDecoder().decode(CloudSaveSnapshot.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        } else if case .campaign = last.action {
            expected = last.state
        } else if last.result == "committed" {
            expected = last.state
        } else {
            throw PlaythroughFailure.unsupported("unknown committed state requires replay evidence")
        }
        #expect(PlaythroughJournal.semantic(store.currentSave) == expected)
        #expect(!store.isPersistenceDegraded)
        var summary = PlaythroughSummary()
        summary.termination = "recoveredCapturedStore"
        try JSONEncoder().encode(summary).write(to: output.appendingPathComponent("summary.json"), options: .atomic)
    }
}
