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
        var startedPriority: Priority?

        init(name: String) {
            self.name = name
        }

        var priority: Priority {
            requests.lazy.map(\.priority).min { $0.rawValue < $1.rawValue } ?? .deferred
        }
    }

    private let decode: @Sendable (String) async -> PreparedArtwork
    private let publish: (PreparedArtwork) -> Void
    private var jobs: [Job] = []

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
                let existingJobs = Dictionary(uniqueKeysWithValues: jobs.map { ($0.name, $0) })
                var seen = Set<String>()
                for name in names where seen.insert(name).inserted {
                    let job: Job
                    if let existing = existingJobs[name] {
                        job = existing
                    } else {
                        job = Job(name: name)
                        jobs.append(job)
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
        while jobs.count(where: { $0.startedPriority != nil }) < 2 {
            let hasDeferred = jobs.contains { $0.startedPriority == .deferred }
            let queued = jobs.filter { $0.startedPriority == nil && (!hasDeferred || $0.priority != .deferred) }
            guard let next = queued.min(by: { $0.priority.rawValue < $1.priority.rawValue }) else { return }
            let priority = next.priority
            next.startedPriority = priority
            Task(priority: priority == Priority.deferred ? .utility : .userInitiated) {
                let prepared = await decode(next.name)
                assert(prepared.name == next.name, "Artwork decode returned mismatched name")
                publish(prepared)
                jobs.removeAll { $0 === next }
                for request in next.requests {
                    request.finish(prepared: true)
                }
                startAvailableJobs()
            }
        }
    }

    private func cancel(_ request: Request) {
        // Started decodes still publish and balance their consumers' pin demand.
        for job in jobs where job.startedPriority == nil && job.requests.contains(where: { $0 === request }) {
            job.requests.removeAll { $0 === request }
            request.finish(prepared: false)
        }
        jobs.removeAll { $0.requests.isEmpty }
        startAvailableJobs()
    }
}
