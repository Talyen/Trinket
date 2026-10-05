import Foundation

// Drives one synchronous battle command. Only this loop runs the task's jobs;
// suspended rules retain their local state on the heap and resume depth first.
// Operations must not await I/O, other actors, or tasks outside this executor.
// Concurrency-Safety: queued jobs are lock-protected and executed only by the caller's drain.
package final class CombatExecutor: TaskExecutor, @unchecked Sendable {
    @TaskLocal private static var current: CombatExecutor?

    private enum Work {
        case job(UnownedJob)
        case resume(UnsafeContinuation<Void, Never>)
    }

    private let lock = NSLock()
    private var work: [Work] = []
    private var cursor = 0

    package func enqueue(_ job: consuming ExecutorJob) {
        append(.job(UnownedJob(job)))
    }

    /// End the current job before entering another damage or card-play frame.
    static func suspend() async {
        guard let executor = current else {
            preconditionFailure("Combat work must be driven by CombatExecutor")
        }
        await withUnsafeContinuation { continuation in
            executor.append(.resume(continuation))
        }
    }

    package static func run<Value>(_ body: () async -> Value) -> Value {
        withoutActuallyEscaping(body) { operation in
            let invocation = Invocation(operation: operation)
            let executor = CombatExecutor()
            let task = Task.detached(executorPreference: executor) {
                await $current.withValue(executor) {
                    invocation.value = await invocation.operation()
                }
            }
            executor.drain()
            withExtendedLifetime(task) {}
            guard let value = invocation.value else {
                preconditionFailure("Combat command suspended outside its executor")
            }
            return value
        }
    }

    package static func run<Value>(_ body: () async throws -> Value) throws -> Value {
        let result: Result<Value, Error> = run {
            do { return try await .success(body()) }
            catch { return .failure(error) }
        }
        return try result.get()
    }

    // The operation and result are confined to the caller's drain. The task
    // cannot escape `run`; enqueue never executes jobs on another thread.
    // Concurrency-Safety: operation and result are accessed only by the synchronous calling-thread drain.
    private final class Invocation<Value>: @unchecked Sendable {
        let operation: () async -> Value
        var value: Value?

        init(operation: @escaping () async -> Value) {
            self.operation = operation
        }
    }

    private func append(_ item: Work) {
        lock.withLock { work.append(item) }
    }

    private func next() -> Work? {
        lock.withLock {
            guard cursor < work.count else { return nil }
            defer { cursor += 1 }
            return work[cursor]
        }
    }

    private func drain() {
        while let item = next() {
            switch item {
            case let .job(job):
                job.runSynchronously(on: asUnownedTaskExecutor())
            case let .resume(continuation):
                continuation.resume()
            }
        }
        lock.withLock {
            work.removeAll(keepingCapacity: false)
            cursor = 0
        }
    }
}
