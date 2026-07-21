import BattleEngine
import Testing
import TrinketCore

struct CombatantBorderAccentTests {
    @Test func emptyEffectsYieldNoAccent() {
        #expect(CombatantBorderAccent.keyword(from: []) == nil)
    }

    @Test func ignoresBuffsControlBuildUpAndDoTs() {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 6),
            ActiveEffect(id: 2, effect: .thorns(1), remainingTurns: 4),
            ActiveEffect(id: 3, effect: .controlMeter(.stun, 4, 10), remainingTurns: 0),
            ActiveEffect(id: 4, effect: .marked(2, 3), remainingTurns: 3),
            ActiveEffect(id: 5, effect: .burn(4), remainingTurns: 0),
            ActiveEffect(id: 6, effect: .bleed(3), remainingTurns: 2),
            ActiveEffect(id: 7, effect: .poison(2), remainingTurns: 0)
        ]
        #expect(CombatantBorderAccent.keyword(from: effects) == nil)
    }

    @Test func deathsDoorOutranksTriggeredControl() {
        let effects = [
            ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0),
            ActiveEffect(id: 2, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ActiveEffect(id: 3, effect: .deathsDoor, remainingTurns: 4),
            ActiveEffect(id: 4, effect: .bleed(3), remainingTurns: 2)
        ]
        #expect(CombatantBorderAccent.keyword(from: effects) == .deathsDoor)
    }

    @Test func triggeredControlYieldsAccent() {
        let effects = [
            ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0),
            ActiveEffect(id: 2, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0),
            ActiveEffect(id: 3, effect: .bleed(2), remainingTurns: 1)
        ]
        #expect(CombatantBorderAccent.keyword(from: effects) == .freeze)
    }
}
