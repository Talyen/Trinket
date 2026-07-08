import Foundation
import TrinketCore
import Testing

@Suite
struct PrimaryStatsModelTests {
    @Test func defaultStatsEqualZero() {
        let stats = PrimaryStats()
        #expect(stats.strength == 0)
        #expect(stats.agility == 0)
        #expect(stats.toughness == 0)
        #expect(stats.intellect == 0)
        #expect(stats.wisdom == 0)
    }

    @Test func primaryStatsCodable() throws {
        let stats = PrimaryStats(strength: 1, agility: 2, toughness: 3, intellect: 4, wisdom: 5)
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(PrimaryStats.self, from: data)
        #expect(decoded == stats)
    }
}
