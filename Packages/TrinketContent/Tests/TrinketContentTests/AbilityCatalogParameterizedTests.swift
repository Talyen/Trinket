import Testing
import TrinketContent

@Suite("Ability catalog lookup")
struct AbilityCatalogParameterizedTests {
    @Test(arguments: AbilityCatalog.all)
    func abilityLookupByID(ability: Ability) {
        #expect(AbilityCatalog.ability(id: ability.id) == ability)
    }
}
