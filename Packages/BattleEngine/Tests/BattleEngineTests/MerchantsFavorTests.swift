import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct MerchantsFavorTests {
    /// Protect bounded currency issuance across repeats, partner plays, and the lethal card.
    @Test(arguments: [BattleParticipant.hero, .companion], [0, 2, 9])
    func `victory pays once for different wearer cards including the winning card`(
        owner: BattleParticipant, differentCards: Int,
    ) throws {
        var battle = try makeBattle(owner: owner)
        let partner: BattleParticipant = owner == .hero ? .companion : .hero
        _ = try play(supportCard("partner"), owner: partner, in: &battle)
        for index in 0 ..< differentCards {
            let ability = supportCard("card-\(index)")
            _ = try play(ability, owner: owner, in: &battle)
            _ = try play(ability, owner: owner, in: &battle)
        }
        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(battle.gold == 0)

        let events = try play(
            Ability(id: "winner", name: "Winner", tier: .basic, directDamage: 100), owner: owner, in: &battle,
        )
        let expected = min(7, differentCards + 1)
        #expect(battle.gold == expected)
        #expect(events.count { $0.keyword == .gold && $0.amount == expected } == 1)
        battle.appendDefeatMilestonesIfNeeded()
        #expect(battle.gold == expected)
        #expect(battle.roster[owner].talents.battle.differentPlayedCardAbilityIDs.count == expected)
    }

    @Test func `no wearer plays or a defeated wearer earns no victory payout`() throws {
        for defeated in [false, true] {
            var battle = try makeBattle(owner: .hero)
            if defeated {
                _ = try play(supportCard("played-before-defeat"), owner: .hero, in: &battle)
                battle.roster.hero.currentHealth = 0
            }
            _ = try play(
                Ability(id: "partner-winner", name: "Winner", tier: .basic, directDamage: 100),
                owner: .companion, in: &battle,
            )
            #expect(battle.gold == 0)
        }
    }

    @Test func `rejected plays and discarded forecasts do not increase the live reward`() throws {
        var battle = try makeBattle(owner: .hero)
        let card = BattleCardCombatEngine.deal(supportCard("forecast"), owner: .hero, context: &battle)
        var forecast = battle
        _ = try forecast.playCard(cardID: card.id)
        #expect(forecast.roster.hero.talents.battle.differentPlayedCardAbilityIDs.count == 1)
        #expect(battle.roster.hero.talents.battle.differentPlayedCardAbilityIDs.isEmpty)
        #expect(throws: BattlePlayError.self) { _ = try battle.playCard(cardID: -1) }
        #expect(battle.roster.hero.talents.battle.differentPlayedCardAbilityIDs.isEmpty)
        let fresh = try makeBattle(owner: .hero)
        #expect(fresh.roster.hero.talents.battle.differentPlayedCardAbilityIDs.isEmpty)
    }

    @Test func `saved Merchants Favor stops turn Gold and adopts the fixed victory cap`() throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "merchants_favor"))
        let base = try #require(GameContent.itemBaseType(matching: "merchants_favor"))
        let old = ItemAffixPower(description: "Gain 1 Gold each turn", modifiers: [], triggers: .init { $0.goldPerTurn = 1 })
        let item = InventoryItem(
            id: "saved-merchant", baseType: base, rarity: .astral, displayName: base.name,
            affixes: [affix.resolved(for: .astral)], affixPowers: [old],
        )
        let power = try #require(item.resolvedPower(at: 0))
        #expect(power.triggers.goldPerTurn == 0)
        #expect(power.triggers.victoryGoldPerDifferentCardCap == 7)
        #expect(power.description == affix.astral.description)
    }

    private func makeBattle(owner: BattleParticipant) throws -> BattleState {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "merchants_favor"))
        var profile = CombatModifierProfile.zero
        affix.astral.triggers.apply(to: &profile, abilityName: affix.title)
        return BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: owner == .hero ? profile : .zero,
            companionModifiers: owner == .companion ? profile : .zero,
            dealOpeningHand: false, appliesFightPacing: false,
        )
    }

    private func supportCard(_ id: String) -> Ability {
        Ability(id: id, name: id, tier: .basic, effects: [.shield(.block, 1)])
    }

    private func play(_ ability: Ability, owner: BattleParticipant, in battle: inout BattleState) throws -> [ActionEvent] {
        let card = BattleCardCombatEngine.deal(ability, owner: owner, context: &battle)
        return try battle.playCard(cardID: card.id).events
    }
}
