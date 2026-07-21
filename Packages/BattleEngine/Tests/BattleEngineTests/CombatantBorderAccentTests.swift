import BattleEngine
import Testing
import TrinketCore

struct CombatantBorderAccentTests {
    @Test func emptyEffectsYieldNoAccent() {
        #expect(CombatantBorderAccent.keyword(from: []) == nil)
    }

    @Test func ignoresBuffsControlBuildUpAndDoTs() {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTicks: 6),
            ActiveEffect(id: 2, effect: .thorns(.physical, 1, 4), remainingTicks: 4),
            ActiveEffect(id: 3, effect: .controlMeter(.stun, 4, 10), remainingTicks: 0),
            ActiveEffect(id: 4, effect: .marked(2, 3), remainingTicks: 3),
            ActiveEffect(id: 5, effect: .burn(4), remainingTicks: 0),
            ActiveEffect(id: 6, effect: .bleed(3), remainingTicks: 2),
            ActiveEffect(id: 7, effect: .poison(2), remainingTicks: 0)
        ]
        #expect(CombatantBorderAccent.keyword(from: effects) == nil)
    }

    @Test func deathsDoorOutranksTriggeredControl() {
        let effects = [
            ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0),
            ActiveEffect(id: 3, effect: .deathsDoor, remainingTicks: 4),
            ActiveEffect(id: 4, effect: .bleed(3), remainingTicks: 2)
        ]
        #expect(CombatantBorderAccent.keyword(from: effects) == .deathsDoor)
    }

    @Test func triggeredControlYieldsAccent() {
        let effects = [
            ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .controlMeter(.freeze, 10, 10), remainingTicks: 0),
            ActiveEffect(id: 3, effect: .bleed(2), remainingTicks: 1)
        ]
        #expect(CombatantBorderAccent.keyword(from: effects) == .freeze)
    }
}
