import BattleBalanceTools
import Foundation

#if os(macOS)
enum BalanceSweepProcessOrchestrator {
    static func run(
        config: BalanceSweepConfig,
        executablePath: String,
    ) throws -> BalanceSweepReport {
        let jobs = BalanceSweepWorkPlan.workerJobs(config: config)
        let started = ContinuousClock.now
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("BalanceSweep-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        FileHandle.standardError.write(Data(
            """
            Spawning \(jobs.count) worker process(es), \
            \(config.resolvedJobs) at a time …\n
            """.utf8,
        ))

        var slices: [BalanceSweepReport] = []
        slices.reserveCapacity(jobs.count)
        var nextIndex = 0
        var chunkIndex = 0
        while nextIndex < jobs.count {
            let waveEnd = min(nextIndex + config.resolvedJobs, jobs.count)
            let waveSlices = try runWave(
                jobs: jobs[nextIndex ..< waveEnd],
                config: config,
                executablePath: executablePath,
                tempRoot: tempRoot,
                chunkIndex: &chunkIndex,
            )
            slices.append(contentsOf: waveSlices)
            nextIndex = waveEnd
        }

        let elapsed = ContinuousClock.now - started
        let elapsedSeconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18
        return BalanceSweepReport.merged(
            slices,
            config: unsliced(config),
            policyID: slices.first?.policyID ?? "greedy-v1",
            elapsedSeconds: elapsedSeconds,
        )
    }

    private static func runWave(
        jobs: ArraySlice<BalanceSweepWorkerJob>,
        config: BalanceSweepConfig,
        executablePath: String,
        tempRoot: URL,
        chunkIndex: inout Int,
    ) throws -> [BalanceSweepReport] {
        var launched: [(process: Process, output: URL)] = []
        launched.reserveCapacity(jobs.count)
        defer {
            for item in launched where item.process.isRunning {
                item.process.terminate()
                item.process.waitUntilExit()
            }
        }
        for job in jobs {
            let output = tempRoot.appendingPathComponent("chunk-\(chunkIndex).json")
            chunkIndex += 1
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            let input = output.deletingPathExtension().appendingPathExtension("config.json")
            var workerConfig = config
            workerConfig.mode = job.mode
            workerConfig.jobs = 1
            workerConfig.workOffset = job.offset
            workerConfig.workLimit = job.limit
            try JSONEncoder().encode(workerConfig).write(to: input)
            process.arguments = ["--worker", input.path, output.path]
            process.standardOutput = FileHandle.nullDevice
            try process.run()
            launched.append((process, output))
        }
        var waveError: OrchestratorError?
        for item in launched {
            item.process.waitUntilExit()
            let status = item.process.terminationStatus
            if status != 0, waveError == nil {
                waveError = .workerFailed(status: status, output: item.output.path)
            }
        }
        if let waveError {
            throw waveError
        }
        return try launched.map { item in
            let data = try Data(contentsOf: item.output)
            return try JSONDecoder().decode(BalanceSweepReport.self, from: data)
        }
    }

    private static func unsliced(_ config: BalanceSweepConfig) -> BalanceSweepConfig {
        var copy = config
        copy.workOffset = 0
        copy.workLimit = nil
        return copy
    }
}

private enum OrchestratorError: Error, CustomStringConvertible {
    case workerFailed(status: Int32, output: String)

    var description: String {
        switch self {
        case let .workerFailed(status, output):
            "worker exited \(status) (\(output))"
        }
    }
}
#endif
