import Foundation

@MainActor
final class ArtworkDecodeScheduler {
    enum Priority: Int {
        case imminent, viewport, deferred
    }

    @MainActor
    private final class Request {
        var remaining = 0
        let priority: Priority
        let didPrepare: () -> Void
        var continuation: CheckedContinuation<Void, Never>?

        init(priority: Priority, didPrepare: @escaping () -> Void) {
            self.priority = priority
            self.didPrepare = didPrepare
        }

        func finish(prepared: Bool) {
            if prepared {
                didPrepare()
            }
            remaining -= 1
            if remaining == 0 {
                continuation?.resume()
                continuation = nil
            }
        }
    }

    @MainActor
    private final class Job {
        let name: String
        var requests: [Request] = []

        init(name: String) {
            self.name = name
        }

        var priority: Priority {
            requests.lazy.map(\.priority).min { $0.rawValue < $1.rawValue } ?? .deferred
        }
    }

    private let decode: @Sendable (String) async -> PreparedArtwork
    private let publish: (PreparedArtwork) -> Void
    // The index includes running jobs so overlapping callers share their decode.
    // Only queued jobs participate in ordered admission and cancellation.
    private var jobsByName: [String: Job] = [:]
    private var queuedJobs: [Job] = []
    private var runningPriorities: [String: Priority] = [:]

    init(
        decode: @escaping @Sendable (String) async -> PreparedArtwork,
        publish: @escaping (PreparedArtwork) -> Void,
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
                        job = Job(name: name)
                        jobsByName[name] = job
                        queuedJobs.append(job)
                    }
                    job.requests.append(request)
                    request.remaining += 1
                }
                startAvailableJobs()
            }
        } onCancel: {
            Task { @MainActor in self.cancel(request) }
        }
    }

    private func startAvailableJobs() {
        while runningPriorities.count < 2 {
            let hasDeferred = runningPriorities.values.contains(.deferred)
            guard let (index, priority) = nextQueuedJob(hasDeferred: hasDeferred) else { return }
            let next = queuedJobs.remove(at: index)
            runningPriorities[next.name] = priority
            Task(priority: priority == Priority.deferred ? .utility : .userInitiated) {
                let prepared = await decode(next.name)
                assert(prepared.name == next.name, "Artwork decode returned mismatched name")
                publish(prepared)
                jobsByName.removeValue(forKey: next.name)
                runningPriorities.removeValue(forKey: next.name)
                for request in next.requests {
                    request.finish(prepared: true)
                }
                startAvailableJobs()
            }
        }
    }

    private func nextQueuedJob(hasDeferred: Bool) -> (Int, Priority)? {
        var next: (index: Int, priority: Priority)?
        for (index, job) in queuedJobs.enumerated() {
            let priority = job.priority
            guard !hasDeferred || priority != .deferred else { continue }
            if priority.rawValue < (next?.priority.rawValue ?? Int.max) {
                next = (index, priority)
                // Keep the first job at equal priority, including promoted demand.
                if priority == .imminent {
                    break
                }
            }
        }
        return next
    }

    private func cancel(_ request: Request) {
        // Started decodes still publish and balance their consumers' pin demand.
        for job in queuedJobs where job.requests.contains(where: { $0 === request }) {
            job.requests.removeAll { $0 === request }
            request.finish(prepared: false)
            if job.requests.isEmpty {
                jobsByName.removeValue(forKey: job.name)
            }
        }
        queuedJobs.removeAll { $0.requests.isEmpty }
        startAvailableJobs()
    }
}
