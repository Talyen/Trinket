import Foundation
import Testing
import TrinketCore

struct PrimaryStatsModelTests {
    @Test func defaultStatsEqualZero() throws {
        let stats = PrimaryStats()
        try #expect(stats.strength == 0)
        try #expect(stats.agility == 0)
        try #expect(stats.toughness == 0)
        try #expect(stats.intellect == 0)
        try #expect(stats.wisdom == 0)
    }

    @Test func primaryStatsCodable() throws {
        let stats = PrimaryStats(strength: 1, agility: 2, toughness: 3, intellect: 4, wisdom: 5)
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(PrimaryStats.self, from: data)
        try #expect(decoded == stats)
    }
}
