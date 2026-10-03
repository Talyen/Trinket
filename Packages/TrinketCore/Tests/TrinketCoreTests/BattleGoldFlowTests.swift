import Testing
import TrinketCore

struct BattleGoldFlowTests {
    @Test func `negative inputs clamp to zero`() {
        #expect(BattleGoldFlow(gained: -3).gained == 0)
        #expect(BattleGoldFlow(spent: -3).spent == 0)
        #expect(BattleGoldFlow(gained: -3, spent: -3).net == 0)
    }

    @Test func `record splits gains and spend`() {
        var flow = BattleGoldFlow()
        flow.record(delta: 10)
        flow.record(delta: -4)
        flow.record(delta: 0)
        #expect(flow.gained == 10)
        #expect(flow.spent == 4)
        #expect(flow.net == 6)
        flow.record(delta: -20)
        #expect(flow.gained == 10)
        #expect(flow.spent == 24)
        #expect(flow.net == -14)
    }

    @Test func `record handles extreme deltas without trapping`() {
        var maxGain = BattleGoldFlow()
        maxGain.record(delta: Int.max)
        #expect(maxGain.gained == Int.max)
        maxGain.record(delta: Int.max)
        #expect(maxGain.gained == Int.max)

        var minSpend = BattleGoldFlow()
        minSpend.record(delta: Int.min)
        #expect(minSpend.spent == Int.max)
        #expect(minSpend.net == -Int.max)

        minSpend.record(delta: -1)
        #expect(minSpend.gained == 0)
        #expect(minSpend.spent == Int.max)
    }
}
