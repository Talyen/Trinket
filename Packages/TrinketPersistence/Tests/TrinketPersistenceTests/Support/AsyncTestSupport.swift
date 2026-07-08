import Testing

@MainActor
enum AsyncTestSupport {
    static func waitUntil(
        _ description: String,
        timeout: Duration = .seconds(1),
        pollInterval: Duration = .milliseconds(5),
        condition: () async -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(for: pollInterval)
        }
        Issue.record("Timed out waiting for \(description)")
    }
}
