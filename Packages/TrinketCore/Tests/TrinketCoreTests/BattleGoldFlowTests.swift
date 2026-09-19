import Testing
import TrinketCore

struct BattleGoldFlowTests {
    @Test func `defaults start at zero`() {
        let flow = BattleGoldFlow()
        #expect(flow.gained == 0)
        #expect(flow.spent == 0)
        #expect(flow.net == 0)
    }

    @Test func `net subtracts spent from gained`() {
        #expect(BattleGoldFlow(gained: 50, spent: 5).net == 45)
    }

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
    }

    @Test func `record saturates instead of trapping`() {
        var flow = BattleGoldFlow(gained: Int.max, spent: Int.max)
        flow.record(delta: 1)
        flow.record(delta: -1)
        #expect(flow.gained == Int.max)
        #expect(flow.spent == Int.max)
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

        var minGain = BattleGoldFlow()
        minGain.record(delta: Int.min)
        #expect(minGain.gained == 0)
        #expect(minGain.spent == Int.max)
    }

    @Test func `net can go negative when spending exceeds gains`() {
        #expect(BattleGoldFlow(gained: 5, spent: 50).net == -45)
    }
}
