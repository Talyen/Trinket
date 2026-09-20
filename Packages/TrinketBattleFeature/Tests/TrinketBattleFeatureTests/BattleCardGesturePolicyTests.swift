import CoreGraphics
import Testing
@testable import TrinketBattleFeature

struct BattleCardGesturePolicyTests {
    @Test func `drag release requires actual upward position beyond the play boundary`() {
        for translation in [CGSize.zero, CGSize(width: 0, height: -65), CGSize(width: 90, height: -85)] {
            #expect(!BattleCardGesturePolicy.shouldPlay(translation: translation, isPlayable: true))
        }
        #expect(BattleCardGesturePolicy.shouldPlay(translation: CGSize(width: 0, height: -80), isPlayable: true))
        #expect(!BattleCardGesturePolicy.shouldPlay(translation: CGSize(width: 0, height: -100), isPlayable: false))
    }

    @Test func `movement boundary includes diagonal travel and excludes finger drift`() {
        #expect(!BattleCardGesturePolicy.exceedsTapSlop(translation: CGSize(width: 2, height: -3)))
        #expect(BattleCardGesturePolicy.exceedsTapSlop(translation: CGSize(width: 10, height: 0)))
        #expect(BattleCardGesturePolicy.exceedsTapSlop(translation: CGSize(width: 8, height: 8)))
    }

    @Test func `returning a drag to its origin never becomes a tap`() {
        #expect(!BattleCardGesturePolicy.isTapGesture(translation: .zero, didExceedTapSlop: true))
        #expect(!BattleCardGesturePolicy.isTapGesture(
            translation: CGSize(width: 11, height: 0),
            didExceedTapSlop: false,
        ))
        #expect(BattleCardGesturePolicy.isTapGesture(
            translation: CGSize(width: 2, height: -3),
            didExceedTapSlop: false,
        ))
    }
}
