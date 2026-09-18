import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

/// Pins the shared fixture defaults so silent drift (renamed seed, changed
/// HP, altered ID scheme) fails here instead of downstream suites.
struct FixtureContractTests {
    @Test func `canonical seed and variants stay stable`() {
        #expect(CombatantFixtures.deterministicBattleSeed == 1772)
        #expect(CombatantFixtures.deterministicBattleSeedVariant(0) == 1772)
        #expect(CombatantFixtures.deterministicBattleSeedVariant(1) == 1772 &+ 1)
        #expect(CombatantFixtures.deterministicBattleSeedVariant(2) == 1772 &+ 2)
    }

    @Test func `turn intervals distinguish parked from quick win`() {
        #expect(CombatantFixtures.passiveTurnInterval == 100)
        #expect(CombatantFixtures.quickWinTurnInterval == 1)
    }

    @Test func `passive presets park with role health`() {
        let hero = CombatantFixtures.passiveHero()
        #expect(hero.id == "hero")
        #expect(hero.maxHealth == 20)
        #expect(hero.actionIntervalTurns == CombatantFixtures.passiveTurnInterval)

        let companion = CombatantFixtures.passiveCompanion()
        #expect(companion.id == "companion")
        #expect(companion.maxHealth == 20)
        #expect(companion.actionIntervalTurns == CombatantFixtures.passiveTurnInterval)

        let enemy = CombatantFixtures.passiveEnemy()
        #expect(enemy.id == "enemy")
        #expect(enemy.maxHealth == 100)
        #expect(enemy.actionIntervalTurns == CombatantFixtures.passiveTurnInterval)
    }

    @Test func `bare factory leaves cadence to the catalog`() {
        let combatant = CombatantFixtures.combatant(id: "hero", role: .hero)
        #expect(combatant.actionIntervalTurns == nil)
        #expect(combatant.name == "Hero")
    }

    @Test func `names derive from hyphen and underscore ids`() {
        #expect(CombatantFixtures.combatant(id: "enemy-boss_2", role: .enemy).name == "Enemy Boss 2")
    }

    @Test func `quick-win party wins fast with parked support`() {
        let party = BattlePartyFixtures.quickWinParty()
        #expect(party.hero.id == "hero")
        #expect(party.hero.abilities == [.slash])
        #expect(party.hero.actionIntervalTurns == CombatantFixtures.quickWinTurnInterval)
        #expect(party.companion.id == "companion")
        #expect(party.companion.actionIntervalTurns == CombatantFixtures.passiveTurnInterval)
        #expect(party.enemy.id == "enemy")
        #expect(party.enemy.maxHealth == 1)
        #expect(party.enemy.actionIntervalTurns == CombatantFixtures.passiveTurnInterval)
    }

    @Test func `bare items default to catalog names and test ids`() throws {
        let item = try ItemFixtures.makeBareItem("longsword")
        let base = try ItemFixtures.baseType("longsword")
        #expect(item.id == "longsword-test")
        #expect(item.displayName == base.name)
        #expect(item.rarity == .basic)
        #expect(item.affixes.isEmpty)
        #expect(item.affixPowers == nil)
        #expect(!item.isCorrupted)
    }

    @Test func `bare items honor corruption`() throws {
        let item = try ItemFixtures.makeBareItem("longsword", isCorrupted: true)
        #expect(item.isCorrupted)
    }

    @Test func `unknown bases throw typed fixture errors`() {
        #expect(throws: ItemFixtures.FixtureError.self) {
            try ItemFixtures.makeBareItem("missing-base")
        }
    }
}
