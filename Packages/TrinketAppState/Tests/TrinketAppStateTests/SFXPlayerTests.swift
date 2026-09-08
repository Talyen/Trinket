import Testing
@testable import TrinketAppState

@MainActor
struct SFXPlayerTests {
    @Test func `disabled player accepts calls without error`() {
        let player = SFXPlayer(isDisabled: true)
        player.play("sword_hit", volume: 0.8)
        player.playAll(["sword_hit", "shield_block"], volume: 0.8)
        player.warm(["sword_hit"], concurrentPlayerCount: 2)
        player.warmAllCatalog(concurrentPlayerCount: 1)
        player.stopAll()
        player.releaseResources()
    }
}
