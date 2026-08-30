import Testing
@testable import TrinketFeatureSupport

struct PreparedArtworkMemoryBudgetTests {
    @Test func `budgets match 6 GB typical targets`() {
        #expect(PreparedArtworkMemoryBudget.residentArtworkByteCount == 320 * 1024 * 1024)
        #expect(PreparedArtworkMemoryBudget.steadyStateProcessByteCount == 550 * 1024 * 1024)
    }

    @Test func `cache budget uses 260 mi B cap with 160 mi B floor`() {
        let limit6GB = PreparedArtworkCache.totalCostLimit(forPhysicalMemory: 6 * 1024 * 1024 * 1024)
        #expect(limit6GB == 256 * 1024 * 1024)

        let limit8GB = PreparedArtworkCache.totalCostLimit(forPhysicalMemory: 8 * 1024 * 1024 * 1024)
        #expect(limit8GB == 260 * 1024 * 1024)

        let limit4GB = PreparedArtworkCache.totalCostLimit(forPhysicalMemory: 4 * 1024 * 1024 * 1024)
        #expect(limit4GB == 4 * 1024 * 1024 * 1024 / 24)

        let limitFloor = PreparedArtworkCache.totalCostLimit(forPhysicalMemory: 1 * 1024 * 1024 * 1024)
        #expect(limitFloor == 160 * 1024 * 1024)
    }
}
