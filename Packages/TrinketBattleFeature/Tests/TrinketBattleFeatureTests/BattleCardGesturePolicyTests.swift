import CoreGraphics
import Testing
@testable import TrinketBattleFeature

struct BattleCardGesturePolicyTests {
    @Test func `shouldPlay honors currently armed card on release`() {
        // When card was armed, release commits play even if translation eased slightly below 80pt
        let easedTranslation = CGSize(width: 0, height: -65)
        let deceleratedPredicted = CGSize(width: 0, height: -50)

        #expect(
            BattleCardGesturePolicy.shouldPlay(
                translation: easedTranslation,
                predictedEndTranslation: deceleratedPredicted,
                isPlayable: true,
                threshold: 80,
                currentlyArmed: true,
            ),
        )
    }

    @Test func `shouldPlay rejects unplayable card even if armed state requested`() {
        #expect(
            !BattleCardGesturePolicy.shouldPlay(
                translation: CGSize(width: 0, height: -100),
                predictedEndTranslation: CGSize(width: 0, height: -100),
                isPlayable: false,
                threshold: 80,
                currentlyArmed: true,
            ),
        )
    }

    @Test func `shouldPlay without armed state requires upward distance threshold`() {
        // 75pt upward (< 80pt) without being armed does not play
        #expect(
            !BattleCardGesturePolicy.shouldPlay(
                translation: CGSize(width: 0, height: -75),
                predictedEndTranslation: CGSize(width: 0, height: -75),
                isPlayable: true,
                threshold: 80,
                currentlyArmed: false,
            ),
        )

        // 85pt upward (>= 80pt) plays
        #expect(
            BattleCardGesturePolicy.shouldPlay(
                translation: CGSize(width: 0, height: -85),
                predictedEndTranslation: CGSize(width: 0, height: -85),
                isPlayable: true,
                threshold: 80,
                currentlyArmed: false,
            ),
        )
    }

    @Test func `shouldPlay rejects predominantly horizontal drags`() {
        #expect(
            !BattleCardGesturePolicy.shouldPlay(
                translation: CGSize(width: 90, height: -85),
                predictedEndTranslation: CGSize(width: 90, height: -85),
                isPlayable: true,
                threshold: 80,
                currentlyArmed: false,
            ),
        )
    }

    @Test func `shouldRemainPlayArmed uses hysteresis to sustain armed state`() {
        // Initial arming requires >= 80pt
        #expect(
            !BattleCardGesturePolicy.shouldRemainPlayArmed(
                translation: CGSize(width: 0, height: -75),
                isPlayable: true,
                threshold: 80,
                currentlyArmed: false,
            ),
        )
        #expect(
            BattleCardGesturePolicy.shouldRemainPlayArmed(
                translation: CGSize(width: 0, height: -80),
                isPlayable: true,
                threshold: 80,
                currentlyArmed: false,
            ),
        )

        // Once armed, release threshold is 80 * 0.72 = 57.6pt
        // 65pt stays armed
        #expect(
            BattleCardGesturePolicy.shouldRemainPlayArmed(
                translation: CGSize(width: 0, height: -65),
                isPlayable: true,
                threshold: 80,
                currentlyArmed: true,
            ),
        )

        // Below 57.6pt disarms
        #expect(
            !BattleCardGesturePolicy.shouldRemainPlayArmed(
                translation: CGSize(width: 0, height: -55),
                isPlayable: true,
                threshold: 80,
                currentlyArmed: true,
            ),
        )
    }

    @Test func `tap gesture recognition respects tap slop`() {
        #expect(
            BattleCardGesturePolicy.isTapGesture(
                translation: CGSize(width: 5, height: -5),
                didExceedTapSlop: false,
                minimumDistance: 12,
            ),
        )

        #expect(
            !BattleCardGesturePolicy.isTapGesture(
                translation: CGSize(width: 15, height: 0),
                didExceedTapSlop: true,
                minimumDistance: 12,
            ),
        )
    }

    @Test func `ability detail inspection requires stationary hold within tap slop`() {
        // Stationary hold within slop opens detail
        #expect(
            BattleCardGesturePolicy.shouldOpenAbilityDetail(
                didRecognizeLongPress: true,
                translation: CGSize(width: 2, height: -3),
                didExceedTapSlop: false,
                minimumDistance: 12,
            ),
        )

        // Hold does not open detail if movement exceeded tap slop
        #expect(
            !BattleCardGesturePolicy.shouldOpenAbilityDetail(
                didRecognizeLongPress: true,
                translation: CGSize(width: 20, height: -5),
                didExceedTapSlop: true,
                minimumDistance: 12,
            ),
        )

        // Hold does not open detail if translation itself exceeds slop
        #expect(
            !BattleCardGesturePolicy.shouldOpenAbilityDetail(
                didRecognizeLongPress: true,
                translation: CGSize(width: 0, height: -14),
                didExceedTapSlop: false,
                minimumDistance: 12,
            ),
        )
    }
}
