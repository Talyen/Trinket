import Foundation

@MainActor
final class ArtworkDecodeScheduler {
    enum Priority: Int {
        case imminent, viewport, deferred
    }

    private struct Request {
        var remaining: Set<String>
        let priority: Priority
        let didPrepare: () -> Void
        let continuation: CheckedContinuation<Void, Never>
    }

    private struct Job {
        let order: Int
        var requests: Set<UUID>
        var startedPriority: Priority?
    }

    private let decode: @Sendable (String) async -> PreparedArtwork
    private let publish: (PreparedArtwork) -> Void
    private var requests: [UUID: Request] = [:]
    private var jobs: [String: Job] = [:]
    private var nextOrder = 0
    private var activeCount = 0
    private var activeDeferredCount = 0

    init(
        decode: @escaping @Sendable (String) async -> PreparedArtwork,
        publish: @escaping (PreparedArtwork) -> Void,
    ) {
        self.decode = decode
        self.publish = publish
    }

    func prepare(_ names: [String], priority: Priority, didPrepare: @escaping () -> Void) async {
        guard !Task.isCancelled, !names.isEmpty else { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume()
                    return
                }
                requests[id] = Request(remaining: Set(names), priority: priority, didPrepare: didPrepare, continuation: continuation)
                for name in names {
                    if jobs[name] == nil {
                        jobs[name] = Job(order: nextOrder, requests: [])
                        nextOrder += 1
                    }
                    jobs[name]?.requests.insert(id)
                }
                startAvailableJobs()
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    private func priority(of job: Job) -> Priority {
        job.requests.compactMap { requests[$0]?.priority }.min { $0.rawValue < $1.rawValue } ?? .deferred
    }

    private func startAvailableJobs() {
        while activeCount < 2 {
            let next = jobs.filter { _, job in
                job.startedPriority == nil
                    && (priority(of: job) != .deferred || activeDeferredCount == 0)
            }.min { lhs, rhs in
                let left = priority(of: lhs.value)
                let right = priority(of: rhs.value)
                return left == right ? lhs.value.order < rhs.value.order : left.rawValue < right.rawValue
            }
            guard let (name, job) = next else { return }
            let priority = priority(of: job)
            jobs[name]?.startedPriority = priority
            activeCount += 1
            if priority == .deferred {
                activeDeferredCount += 1
            }
            Task(priority: priority == .deferred ? .utility : .userInitiated) {
                let prepared = await decode(name)
                assert(prepared.name == name, "Artwork decode returned mismatched name")
                publish(prepared)
                finish(name)
            }
        }
    }

    private func finish(_ name: String) {
        guard let job = jobs.removeValue(forKey: name) else { return }
        activeCount -= 1
        if job.startedPriority == .deferred {
            activeDeferredCount -= 1
        }
        for id in job.requests {
            requests[id]?.didPrepare()
            finish(name, for: id)
        }
        startAvailableJobs()
    }

    private func finish(_ name: String, for id: UUID) {
        requests[id]?.remaining.remove(name)
        if requests[id]?.remaining.isEmpty == true {
            requests.removeValue(forKey: id)?.continuation.resume()
        }
    }

    private func cancel(_ id: UUID) {
        guard let request = requests[id] else { return }
        for name in request.remaining where jobs[name]?.startedPriority == nil {
            jobs[name]?.requests.remove(id)
            if jobs[name]?.requests.isEmpty == true {
                jobs.removeValue(forKey: name)
            }
            finish(name, for: id)
        }
        startAvailableJobs()
    }
}
