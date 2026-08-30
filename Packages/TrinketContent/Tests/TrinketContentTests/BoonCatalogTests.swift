import Testing
import TrinketCore
@testable import TrinketContent

struct BoonCatalogTests {
    @Test func `catalog has forty unique boons across sixteen categories`() throws {
        let boons = BoonCatalog.all
        try #expect(boons.count == 40)
        try #expect(Set(boons.map(\.id)).count == 40)
        try #expect(Set(boons.map(\.category.id)).count == 16)
    }

    @Test func `every boon combines two keywords and uses brief copy`() throws {
        for boon in BoonCatalog.all {
            try #expect(boon.category.keywords.count == 2)
            try #expect(Set(boon.category.keywords).count == 2)
            try #expect(boon.description.split(whereSeparator: \.isWhitespace).count < 10)
            try #expect(!boon.description.localizedCaseInsensitiveContains("apply"))
            try #expect(!boon.description.localizedCaseInsensitiveContains("stack"))
            try #expect(!boon.description.localizedCaseInsensitiveContains("tick"))
        }
    }
}
