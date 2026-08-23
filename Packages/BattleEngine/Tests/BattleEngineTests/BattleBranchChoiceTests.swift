import BattleEngine
import Testing
import TrinketContent
import TrinketCore

/// Player-facing outcome-branch selection: chosen-index resolution, RNG
/// fallback parity, and collapse-to-normal-play when conditional riders make
/// every branch equivalent.
struct BattleBranchChoiceTests {
    private func makeBattle(
        heroAbilities: [Ability],
        companionAbilities: [Ability] = [],
        enemyMaxHealth: Int = 100,
        rngSeed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            enemyMaxHealth: enemyMaxHealth,
            rngSeed: rngSeed
        )
    }

    // MARK: - Player-chosen outcome branches

    /// Deals an opening hand whose plan slots are all guaranteed, then plays
    /// `abilityID` from it with `branchIndex`.
    private func playBranchableCard(
        heroAbilities: [Ability],
        companionAbilities: [Ability],
        abilityNamed name: String,
        branchIndex: Int?,
        rngSeed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed
    ) throws -> (battle: BattleState, events: [ActionEvent]) {
        var battle = makeBattle(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            enemyMaxHealth: 500,
            rngSeed: rngSeed
        )
        let card = try #require(battle.hand.cards.first { $0.ability.name == name })
        let events = try battle.playCard(cardID: card.id, branchIndex: branchIndex)
        return (battle, events)
    }

    @Test func playHonorsChosenDamageBranch() throws {
        let bleed = try playBranchableCard(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Maul",
            branchIndex: 1
        )
        let enemyEffects = bleed.battle.activeEffects(of: bleed.battle.enemy)
        try #expect(enemyEffects.contains { effect in
            guard case .bleed = effect.effect else { return false }
            return true
        })

        let stun = try playBranchableCard(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Maul",
            branchIndex: 0
        )
        let stunnedEnemyEffects = stun.battle.activeEffects(of: stun.battle.enemy)
        try #expect(stunnedEnemyEffects.allSatisfy { effect in
            guard case .bleed = effect.effect else { return true }
            return false
        })
    }

    @Test func playHonorsChosenResourceBranch() throws {
        let gold = try playBranchableCard(
            heroAbilities: [.tithe, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Tithe",
            branchIndex: 1
        )
        #expect(gold.battle.gold > 0)
        #expect(gold.events.contains { $0.effectKind == .resourceGain && $0.keyword == .gold })
    }

    @Test func playRejectsOutOfRangeBranchIndex() throws {
        var battle = makeBattle(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn]
        )
        battle.openingHandDealPlan = []
        battle.hand = BattleHand()
        battle.handBuffer = BattleHandBuffer()
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: .maul, owner: .hero))

        do {
            _ = try battle.playCard(cardID: battle.nextCardID, branchIndex: 2)
            Issue.record("Expected invalidBranchSelection")
        } catch BattlePlayError.invalidBranchSelection {
            // expected
        }
        try #expect(battle.hand.card(id: battle.nextCardID) != nil)
    }

    @Test func nilBranchIndexKeepsSeededDeterminism() throws {
        func signature(_ events: [ActionEvent]) -> [String] {
            events.map { "\($0.kind)|\(String(describing: $0.effectKind))|\($0.amount)|\($0.abilityID)" }
        }
        let first = try playBranchableCard(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Maul",
            branchIndex: nil,
            rngSeed: 7
        )
        let second = try playBranchableCard(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Maul",
            branchIndex: nil,
            rngSeed: 7
        )
        #expect(signature(first.events) == signature(second.events))
    }

    private func makeBranchQueryBattle(
        heroAbilities: [Ability],
        markedEnemy: Bool
    ) -> BattleState {
        var battle = makeBattle(
            heroAbilities: heroAbilities,
            companionAbilities: [.bash, .fangs, .bloodthorn]
        )
        if markedEnemy {
            battle.withEngineContext { context in
                context.roster.setActiveEffects(
                    [ActiveEffect(
                        id: 9001,
                        effect: .marked(5, Effect.standardMarkedDuration),
                        remainingTurns: Effect.standardMarkedDuration,
                        sourceActorID: context.roster.hero.combatant.id
                    )],
                    for: context.enemy
                )
            }
        }
        return battle
    }

    @Test func bountyShotChoiceCollapsesOnlyWhileEnemyIsMarked() {
        let unmarked = makeBranchQueryBattle(heroAbilities: [.bountyShot], markedEnemy: false)
        #expect(
            BattleCardCombatEngine.requiresBranchChoice(
                ability: .bountyShot,
                actor: unmarked.roster.hero.combatant,
                in: unmarked
            )
        )

        let marked = makeBranchQueryBattle(heroAbilities: [.bountyShot], markedEnemy: true)
        #expect(
            !BattleCardCombatEngine.requiresBranchChoice(
                ability: .bountyShot,
                actor: marked.roster.hero.combatant,
                in: marked
            )
        )
    }

    @Test func unconditionalBranchesAlwaysOfferAChoice() {
        let branchables: [Ability] = [.maul, .blackjack, .pixieDust, .cinderbloom, .astralArrow, .luckPotion]
        for ability in branchables {
            let battle = makeBranchQueryBattle(heroAbilities: [ability], markedEnemy: false)
            #expect(
                BattleCardCombatEngine.requiresBranchChoice(ability: ability, actor: battle.roster.hero.combatant, in: battle),
                "Expected a choice offer for \(ability.id)"
            )
        }
    }

    @Test func enemiesNeverGetBranchChoices() {
        let battle = makeBranchQueryBattle(heroAbilities: [.maul], markedEnemy: false)
        #expect(!BattleCardCombatEngine.requiresBranchChoice(ability: .maul, actor: battle.enemy, in: battle))
    }
}
