import TrinketCore
import XCTest

final class PrimaryStatsModelTests: XCTestCase {
    func testDefaultStatsEqualZero() {
        let stats = PrimaryStats()
        XCTAssertEqual(stats.strength, 0)
        XCTAssertEqual(stats.agility, 0)
        XCTAssertEqual(stats.toughness, 0)
        XCTAssertEqual(stats.intellect, 0)
        XCTAssertEqual(stats.wisdom, 0)
    }

    func testPrimaryStatsCodable() throws {
        let stats = PrimaryStats(strength: 1, agility: 2, toughness: 3, intellect: 4, wisdom: 5)
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(PrimaryStats.self, from: data)
        XCTAssertEqual(decoded, stats)
    }
}
