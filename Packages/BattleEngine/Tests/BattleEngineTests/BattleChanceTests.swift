import Testing
@testable import BattleEngine

struct BattleChanceTests {
    @Test func probabilityEndpointsDoNotDependOnRandomEndpoint() {
        var maximum = EndpointRandomNumberGenerator(value: .max)
        var minimum = EndpointRandomNumberGenerator(value: .min)

        #expect(BattleChance.succeeds(probability: 1, using: &maximum))
        #expect(!BattleChance.succeeds(probability: 0, using: &minimum))
        #expect(BattleChance.succeeds(probability: 0.5, using: &minimum))
        #expect(!BattleChance.succeeds(probability: 0.5, using: &maximum))
    }
}

private struct EndpointRandomNumberGenerator: RandomNumberGenerator {
    let value: UInt64

    mutating func next() -> UInt64 {
        value
    }
}
