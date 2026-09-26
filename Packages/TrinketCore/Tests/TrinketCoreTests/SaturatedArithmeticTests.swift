import Testing
import TrinketCore

struct SaturatedArithmeticTests {
    @Test func `add saturates at Int max`() {
        #expect(SaturatedArithmetic.saturatingAdd(1, 2) == 3)
        #expect(SaturatedArithmetic.saturatingAdd(Int.max, 1) == Int.max)
        #expect(SaturatedArithmetic.saturatingAdd(Int.max, Int.max) == Int.max)
        #expect(SaturatedArithmetic.saturatingAdd(-5, 3) == -2)
        #expect(SaturatedArithmetic.saturatingAdd(Int.min, -1) == Int.min)
        #expect(SaturatedArithmetic.saturatingAdd(Int.min, Int.min) == Int.min)
    }

    @Test func `sub never traps on extreme operands`() {
        #expect(SaturatedArithmetic.saturatingSub(5, 3) == 2)
        #expect(SaturatedArithmetic.saturatingSub(Int.max, Int.min) == Int.max)
        #expect(SaturatedArithmetic.saturatingSub(Int.min, Int.max) == Int.min)
        #expect(SaturatedArithmetic.saturatingSub(0, Int.min) == Int.max)
        #expect(SaturatedArithmetic.saturatingSub(-1, Int.min) == Int.max)
    }

    @Test func `mul saturates at Int max and Int min`() {
        #expect(SaturatedArithmetic.saturatingMul(3, 4) == 12)
        #expect(SaturatedArithmetic.saturatingMul(Int.max, 2) == Int.max)
        #expect(SaturatedArithmetic.saturatingMul(Int.max, Int.max) == Int.max)
        #expect(SaturatedArithmetic.saturatingMul(Int.max, -2) == Int.min)
        #expect(SaturatedArithmetic.saturatingMul(Int.min, 2) == Int.min)
        #expect(SaturatedArithmetic.saturatingMul(Int.min, -1) == Int.max)
        #expect(SaturatedArithmetic.saturatingMul(Int.min, -2) == Int.max)
    }

    @Test func `scaled by percent delegates accurately`() {
        #expect(SaturatedArithmetic.scaled(10, byPercent: 50) == 15)
        #expect(SaturatedArithmetic.scaled(10, byPercent: -50) == 5)
        #expect(SaturatedArithmetic.scaled(0, byPercent: 50) == 0)
        #expect(SaturatedArithmetic.scaled(-10, byPercent: 50) == 0)
        #expect(SaturatedArithmetic.scaled(Int.max, byPercent: 100) == Int.max)
    }
}
