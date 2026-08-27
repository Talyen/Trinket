import Testing
@testable import TrinketFeatureSupport

struct PreparedArtworkMemoryBudgetTests {
    @Test func budgetsMatch6GBTypicalTargets() {
        #expect(PreparedArtworkMemoryBudget.residentArtworkByteCount == 320 * 1024 * 1024)
        #expect(PreparedArtworkMemoryBudget.steadyStateProcessByteCount == 550 * 1024 * 1024)
    }

    @Test func cacheBudgetUses260MiBCapWith160MiBFloor() {
        #expect(PreparedArtworkMemoryBudget.residentArtworkByteCount == 320 * 1024 * 1024)
        #expect(PreparedArtworkMemoryBudget.steadyStateProcessByteCount == 550 * 1024 * 1024)
    }
}
