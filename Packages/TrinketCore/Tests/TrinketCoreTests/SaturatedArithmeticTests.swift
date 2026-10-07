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

    @Test func `percentage scaling preserves identity and rounds fractional bonuses`() {
        #expect(SaturatedArithmetic.scaled(10, byPercent: 0) == 10)
        #expect(SaturatedArithmetic.scaled(10, byPercent: 25) == 13)
        #expect(SaturatedArithmetic.scaled(10, byPercent: 50) == 15)
        #expect(SaturatedArithmetic.scaled(10, byPercent: -50) == 5)
        #expect(SaturatedArithmetic.scaled(0, byPercent: 50) == 0)
        #expect(SaturatedArithmetic.scaled(-10, byPercent: 50) == 0)
        #expect(SaturatedArithmetic.scaled(Int.max, byPercent: 100) == Int.max)
    }

    @Test func `rounding handles invalid values and integer limits without trapping`() {
        #expect(SaturatedArithmetic.rounded(2.4) == 2)
        #expect(SaturatedArithmetic.rounded(2.5) == 3)
        for value in [-100.0, 0, .infinity, -.infinity, .nan] {
            #expect(SaturatedArithmetic.rounded(value) == 0)
        }
        #expect(SaturatedArithmetic.rounded(Double(Int.max)) == Int.max)
        #expect(SaturatedArithmetic.rounded(Double(Int.max) * 2) == Int.max)
    }

    @Test func `scaling shares rounding saturation and invalid-input rules`() {
        #expect(SaturatedArithmetic.scaled(3, multiplier: 0.8) == 2)
        #expect(SaturatedArithmetic.scaled(2, multiplier: 1.3) == 3)
        #expect(SaturatedArithmetic.scaled(0, multiplier: 0.8) == 0)
        #expect(SaturatedArithmetic.scaled(Int.min, multiplier: 0.8) == 0)
        #expect(SaturatedArithmetic.scaled(Int.max, multiplier: 2) == Int.max)
        for multiplier in [Double.infinity, -.infinity, .nan, -0.5] {
            #expect(SaturatedArithmetic.scaled(10, multiplier: multiplier) == 0)
        }
    }
}
