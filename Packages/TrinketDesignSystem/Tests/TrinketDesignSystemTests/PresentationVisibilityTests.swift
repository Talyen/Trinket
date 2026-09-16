import Testing
@testable import TrinketDesignSystem

struct PresentationVisibilityTests {
    @Test(arguments: [
        (ancestor: true, scope: true, expected: true),
        (ancestor: true, scope: false, expected: false),
        (ancestor: false, scope: true, expected: false),
        (ancestor: false, scope: false, expected: false),
    ])
    private func `decorative motion suppression composes with AND`(
        ancestor: Bool,
        scope: Bool,
        expected: Bool,
    ) {
        #expect(DecorativeMotionContract.isActive(ancestor: ancestor, scope: scope) == expected)
    }
}
