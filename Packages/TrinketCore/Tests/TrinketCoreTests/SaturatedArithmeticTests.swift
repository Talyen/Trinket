import Testing
import TrinketCore

struct SaturatedArithmeticTests {
    @Test func `add saturates at Int max`() {
        #expect(SaturatedArithmetic.saturatingAdd(1, 2) == 3)
        #expect(SaturatedArithmetic.saturatingAdd(Int.max, 1) == Int.max)
        #expect(SaturatedArithmetic.saturatingAdd(Int.max, Int.max) == Int.max)
        #expect(SaturatedArithmetic.saturatingAdd(-5, 3) == -2)
    }

    @Test func `sub never traps on extreme operands`() {
        #expect(SaturatedArithmetic.saturatingSub(5, 3) == 2)
        #expect(SaturatedArithmetic.saturatingSub(Int.max, Int.min) == Int.max)
        #expect(SaturatedArithmetic.saturatingSub(Int.min, Int.max) == Int.min)
        #expect(SaturatedArithmetic.saturatingSub(0, Int.min) == Int.max)
    }

    @Test func `mul saturates at Int max`() {
        #expect(SaturatedArithmetic.saturatingMul(3, 4) == 12)
        #expect(SaturatedArithmetic.saturatingMul(Int.max, 2) == Int.max)
        #expect(SaturatedArithmetic.saturatingMul(Int.max, Int.max) == Int.max)
    }
}
