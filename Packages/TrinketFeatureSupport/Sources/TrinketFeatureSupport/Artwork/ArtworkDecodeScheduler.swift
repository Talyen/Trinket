import Foundation

@MainActor
final class ArtworkDecodeScheduler {
    enum Priority: Int {
        case imminent, viewport, deferred
    }

    @MainActor
    private final class Request {
        var pendingNames: Set<String> = []
        let priority: Priority
        let didPrepare: @MainActor () -> Void
        var continuation: CheckedContinuation<Void, Never>?

        init(priority: Priority, didPrepare: @escaping @MainActor () -> Void) {
            self.priority = priority
            self.didPrepare = didPrepare
        }

        func finish(name: String) {
            guard pendingNames.remove(name) != nil else { return }
            didPrepare()
            if pendingNames.isEmpty {
                resume()
            }
        }

        func resume() {
            continuation?.resume()
            continuation = nil
        }
    }

    @MainActor
    private final class Job {
        let name: String
        let sequence: UInt64
        var requests: [Request] = []
        var priority: Priority = .deferred

        init(name: String, sequence: UInt64) {
            self.name = name
            self.sequence = sequence
        }
    }

    private let decode: @Sendable (String) async -> PreparedArtwork
    private let publish: @MainActor (PreparedArtwork) -> Void
    /// At most two concurrent decodes bound decode latency without
    /// oversubscribing the cooperative pool; deferred work additionally
    /// yields while any deferred decode is already running.
    private static let maxConcurrentDecodes = 2
    // The index includes running jobs so overlapping callers share their decode.
    // Request cancellation detaches consumers without releasing running decode slots.
    private var jobsByName: [String: Job] = [:]
    private var queuedJobs: [Job] = []
    private var nextSequence: UInt64 = 0
    private var runningPriorities: [String: Priority] = [:]

    init(
        decode: @escaping @Sendable (String) async -> PreparedArtwork,
        publish: @escaping @MainActor (PreparedArtwork) -> Void,
    ) {
        self.decode = decode
        self.publish = publish
    }

    func prepare(_ names: [String], priority: Priority, didPrepare: @escaping () -> Void) async {
        guard !Task.isCancelled, !names.isEmpty else { return }
        let request = Request(priority: priority, didPrepare: didPrepare)
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume()
                    return
                }
                request.continuation = continuation
                var seen = Set<String>()
                for name in names where seen.insert(name).inserted {
                    let job: Job
                    if let existing = jobsByName[name] {
                        job = existing
                    } else {
                        job = Job(name: name, sequence: nextSequence)
                        nextSequence += 1
                        jobsByName[name] = job
                    }
                    job.requests.append(request)
                    if request.priority.rawValue < job.priority.rawValue {
                        job.priority = request.priority
                    }
                    request.pendingNames.insert(name)
                    if runningPriorities[name] == nil, !queuedJobs.contains(where: { $0 === job }) {
                        queuedJobs.append(job)
                    }
                }
                startAvailableJobs()
            }
        } onCancel: {
            Task { @MainActor in self.cancel(request) }
        }
    }

    private func startAvailableJobs() {
        while runningPriorities.count < Self.maxConcurrentDecodes {
            let hasDeferred = runningPriorities.values.contains(.deferred)
            guard let index = bestQueuedIndex() else { return }
            let next = queuedJobs[index]
            // A deferred candidate means no higher-priority work remains queued.
            guard !hasDeferred || next.priority != .deferred else { return }
            queuedJobs.remove(at: index)
            runningPriorities[next.name] = next.priority
            let priority = next.priority
            Task(priority: priority == Priority.deferred ? .utility : .userInitiated) {
                let prepared = await decode(next.name)
                assert(prepared.name == next.name, "Artwork decode returned mismatched name")
                // Publish and bookkeeping touch MainActor-owned scheduler, request,
                // and cache state; an unstructured task does not inherit isolation.
                await MainActor.run {
                    publish(prepared)
                    jobsByName.removeValue(forKey: next.name)
                    runningPriorities.removeValue(forKey: next.name)
                    for request in next.requests {
                        request.finish(name: next.name)
                    }
                    startAvailableJobs()
                }
            }
        }
    }

    private func precedes(_ lhs: Job, _ rhs: Job) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority.rawValue < rhs.priority.rawValue
        }
        return lhs.sequence < rhs.sequence
    }

    private func bestQueuedIndex() -> Int? {
        var best: Int?
        for index in queuedJobs.indices {
            guard let current = best else {
                best = index
                continue
            }
            if precedes(queuedJobs[index], queuedJobs[current]) {
                best = index
            }
        }
        return best
    }

    private func cancel(_ request: Request) {
        let names = request.pendingNames
        request.pendingNames.removeAll()
        for name in names {
            guard let job = jobsByName[name] else { continue }
            job.requests.removeAll { $0 === request }
            // Shared started jobs still publish and occupy their slots until decoding ends.
            guard !job.requests.isEmpty else {
                if let index = queuedJobs.firstIndex(where: { $0 === job }) {
                    queuedJobs.remove(at: index)
                }
                jobsByName.removeValue(forKey: name)
                continue
            }
            job.priority = job.requests.lazy.map(\.priority).min { $0.rawValue < $1.rawValue } ?? .deferred
        }
        request.resume()
        startAvailableJobs()
    }
}
