import Testing
import TrinketCore
@testable import TrinketContent

struct AbilityCatalogTests {
    @Test func `luck potion covers every die face and combat outcome`() throws {
        let branches = try #require(Ability.luckPotion.outcomeBranches)
        #expect(branches.count == 36)
        var thornsAmounts: [Int] = []
        var blockAmounts: [Int] = []
        var healthAmounts: [Int] = []
        for targeted in branches.flatMap(\.targetedEffects) {
            switch targeted.effect {
            case let .thorns(amount):
                thornsAmounts.append(amount)
            case let .shield(.block, amount):
                blockAmounts.append(amount)
            case let .instantHeal(.health, amount):
                #expect(targeted.target == .lowestHealthAlly)
                healthAmounts.append(amount)
            case .drawCards(1):
                #expect(targeted.target == .actor)
            default:
                Issue.record("Luck Potion branch did not grant a combat gain or draw")
            }
        }
        #expect(thornsAmounts.sorted() == Array(1 ... 12))
        #expect(blockAmounts.sorted() == Array(1 ... 12))
        #expect(healthAmounts.sorted() == Array(1 ... 12))
    }

    @Test func `catalog I ds are unique and unknown lookup returns nil`() throws {
        let ids = AbilityCatalog.all.map(\.id)
        try #expect(
            Set(ids).count == ids.count,
            "Duplicate ability IDs: \(Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys)",
        )
        try #expect(AbilityCatalog.ability(id: "missing-ability") == nil)
    }

    @Test func `generated ability descriptions show shared riders`() {
        for ability in AbilityCatalog.all where ability.descriptionOverride == nil {
            if ability.hasLeech {
                #expect(ability.summary.contains("Leech"), "\(ability.id) hides Leech")
            }
            if ability.repeatsManaEmpowerment {
                #expect(ability.summary.contains("Mana"), "\(ability.id) hides empowerment")
            }
            if ability.criticalChanceBonus > 0 || ability.guaranteedCriticalIfEnemyBuffed {
                #expect(ability.summary.contains("Critical"), "\(ability.id) hides critical rider")
            }
        }
    }
}
