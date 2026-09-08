import Testing
@testable import TrinketAppState

@MainActor
struct MusicPlayerTests {
    @Test func `disabled player accepts calls without error`() {
        let player = MusicPlayer(isDisabled: true)
        #expect(!player.canPreviewVolume)

        player.setVolume(0.5)
        player.update(route: .silence(preservingPosition: true), volume: 0.5)
        player.update(route: .silence(preservingPosition: true), volume: 0.5, immediate: true)
        player.silenceImmediately(preservingPosition: true)
        player.cancelActiveFades()
        player.clearEncounterResumePositions()
        player.stop()

        #expect(!player.canPreviewVolume)
    }
}
