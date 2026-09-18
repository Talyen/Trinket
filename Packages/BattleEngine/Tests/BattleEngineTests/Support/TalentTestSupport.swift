import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

/// Shared talent-test factories, homed in Support per Tests/README.md.
/// Previously defined inside individual TalentCatalogRoundTripTests feature
/// files while being consumed across all of them.
extension TalentCatalogRoundTripTests {
    func heroTalentBattle(
        _ talents: String...,
        companionMana: Int = 10,
        seed: UInt64 = CombatantFixtures.deterministicBattleSeed,
    ) -> BattleState {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 10, companionMaxMana: companionMana,
            heroModifiers: CombatantTalentCatalog.profile(for: Set(talents)), rngSeed: seed, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        return battle
    }

    func capstoneBattle(hero: [String] = [], companion: [String] = []) -> BattleState {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 40, companionMaxHealth: 40, enemyMaxHealth: 200,
            heroMaxMana: 10, companionMaxMana: 10,
            heroModifiers: CombatantTalentCatalog.profile(for: Set(hero)),
            companionModifiers: CombatantTalentCatalog.profile(for: Set(companion)),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        return battle
    }

    var heroTalentPhysicalCard: Ability {
        Ability(id: "test-physical", name: "Physical", tier: .basic, damageComponents: [DamageComponent(1, keyword: .physical)])
    }

    var heroTalentHealingCard: Ability {
        Ability(
            id: "test-healing",
            name: "Healing",
            tier: .basic,
            targetedEffects: [TargetedEffect(.instantHeal(.health, 1), target: .actor)],
        )
    }

    var heroTalentGoldCard: Ability {
        Ability(
            id: "test-gold",
            name: "Gold",
            tier: .skill,
            targetedEffects: [TargetedEffect(.resourceGain(.gold, 1), target: .actor)],
        )
    }

    @discardableResult
    func playHeroTalentCard(_ ability: Ability, owner: BattleParticipant = .hero, in battle: inout BattleState) throws -> [ActionEvent] {
        let card = BattleCard(id: battle.nextCardID, ability: ability, owner: owner)
        battle.nextCardID += 1
        battle.hand.append(card)
        return try BattleCardCombatEngine.playDrawnCard(card, context: &battle)
    }

    func seedHeroTalentEffect(
        _ effect: Effect,
        on owner: BattleParticipant,
        in battle: inout BattleState,
        source: BattleParticipant = .hero,
    ) {
        battle.appendEffect(
            effect,
            to: battle.roster[owner].combatant,
            sourceID: battle.roster[source].id,
            remainingTurns: effect.durationTurns,
        )
    }

    func talentPoints(_ kind: EffectKind, on owner: BattleParticipant, in battle: BattleState) -> Int {
        battle.roster.activeEffects(for: battle.roster[owner].combatant).reduce(0) { sum, active in
            guard active.effect.kind == kind else { return sum }
            if case let .shield(_, amount) = active.effect {
                return sum + amount
            }
            return sum + (active.effect.potency ?? 0)
        }
    }
}
