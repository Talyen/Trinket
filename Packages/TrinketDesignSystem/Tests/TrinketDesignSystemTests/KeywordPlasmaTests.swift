import SwiftUI
import Testing
import TrinketCore
@testable import TrinketDesignSystem

struct KeywordPlasmaTests {
    @Test func `plasma clock preserves phase across repeated pauses`() {
        let origin = Date(timeIntervalSinceReferenceDate: 0)
        var clock = DecorativeLoopClock()
        clock.setActive(true, at: origin)
        #expect(clock.elapsed(at: origin.addingTimeInterval(5)) == 5)
        clock.setActive(false, at: origin.addingTimeInterval(5))
        #expect(clock.elapsed(at: origin.addingTimeInterval(20)) == 5)
        clock.setActive(false, at: origin.addingTimeInterval(20))
        clock.setActive(true, at: origin.addingTimeInterval(30))
        #expect(clock.elapsed(at: origin.addingTimeInterval(30)) == 5)
        clock.setActive(true, at: origin.addingTimeInterval(32))
        clock.setActive(false, at: origin.addingTimeInterval(35))
        #expect(clock.elapsed(at: origin.addingTimeInterval(50)) == 10)
        clock.setActive(true, at: origin.addingTimeInterval(60))
        #expect(clock.elapsed(at: origin.addingTimeInterval(62)) == 12)
    }

    @Test func `plasma clock starts paused and handles stale timeline dates`() {
        let origin = Date(timeIntervalSinceReferenceDate: 0)
        var clock = DecorativeLoopClock()
        clock.setActive(false, at: origin)
        #expect(clock.elapsed(at: origin.addingTimeInterval(20)) == 0)
        clock.setActive(true, at: origin.addingTimeInterval(30))
        #expect(clock.elapsed(at: origin.addingTimeInterval(20)) == 0)
        #expect(clock.elapsed(at: origin.addingTimeInterval(32)) == 2)
    }

    @Test func `plasma palette uses the first two styles with a single keyword fallback`() {
        let empty = KeywordPlasmaBackground.colors(for: [])
        #expect(empty.primary == TrinketDesign.Colors.accent)
        #expect(empty.secondary == empty.primary)
        let single = KeywordPlasmaBackground.colors(for: [.burn])
        #expect(single.primary == Keyword.burn.visualStyle.color)
        #expect(single.secondary == Keyword.burn.visualStyle.secondaryColor)
        let multiple = KeywordPlasmaBackground.colors(for: [.burn, .stun, .block])
        #expect(multiple.primary == single.primary)
        #expect(multiple.secondary == Keyword.stun.visualStyle.color)
    }
}
