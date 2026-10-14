import Foundation

/// Serializes legacy authoritative commands through receipt acknowledgement.
/// Background upload synchronization can still coalesce independently.
@MainActor
final class CloudSaveOperationQueue {
    private var tasks: [UUID: Task<CloudSaveReceipt.Outcome?, Never>] = [:]
    private var tail: Task<CloudSaveReceipt.Outcome?, Never>?
    private var tailID: UUID?

    func perform(
        _ operation: @escaping @MainActor () async -> CloudSaveReceipt.Outcome?,
    ) async -> CloudSaveReceipt.Outcome? {
        let id = UUID()
        let previous = tail
        let work = Task { @MainActor in
            if let previous {
                _ = await previous.value
            }
            guard !Task.isCancelled else { return nil as CloudSaveReceipt.Outcome? }
            return await operation()
        }
        tasks[id] = work
        tail = work
        tailID = id
        let result = await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }
        tasks[id] = nil
        if tailID == id {
            tail = nil
            tailID = nil
        }
        return result
    }

    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        tail = nil
        tailID = nil
    }
}
