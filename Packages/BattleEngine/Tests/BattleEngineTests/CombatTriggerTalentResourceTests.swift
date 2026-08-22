import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

/// Economy injected-trigger talents: gold gain, mana triggers, spell echo, and companion spend reactions.
struct CombatTriggerTalentResourceTests {
    @Test func prismaticSparkCanDoubleManaGain() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 6,
            companionMana: 0,
            companionModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(manaGainDoubleChancePercent: 1)
            )),
            dealOpeningHand: false
        )
        let restored = battle.restoreMana(1, to: battle.roster.companion.combatant)
        #expect(restored == 2)
    }

    @Test func goldReservesCapsBonusDamageAtFive() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            initialGold: 100,
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(goldReservesDamageEvery: 10, goldReservesDamageCap: 5)
            )),
            dealOpeningHand: false
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 4,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 9)
    }

    @Test func spellEchoPlaysTheFirstSkillOncePerBattle() throws {
        let poke = Ability(id: "poke", name: "Poke", tier: .skill, directDamage: 1)
        let jab = Ability(id: "jab", name: "Jab", tier: .skill, directDamage: 1)
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(firstSkillCardPlaysTwicePerBattle: true)
            )),
            dealOpeningHand: false
        )
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: poke, owner: .hero))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: jab, owner: .hero))
        let health = { battle.roster.health(for: battle.roster.enemy.combatant) }
        let beforeFirst = health()
        _ = try BattleTestFixtures.playCardNamed("Poke", owner: .hero, on: &battle)
        let afterFirst = health()
        _ = try BattleTestFixtures.playCardNamed("Jab", owner: .hero, on: &battle)
        let afterSecond = health()
        #expect(beforeFirst - afterFirst == 2)
        #expect(afterFirst - afterSecond == 1)
        #expect(battle.skillEchoOwnersThisBattle.contains(battle.roster.hero.id))
    }

    @Test func feintStrikeEmpowersLivingPartyNextCard() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(onDodgePartyNextCardDamageBonus: 2)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant,
            attackerID: battle.roster.enemy.id,
            in: &battle
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.pendingCardDamageBonus == 2)
        #expect(battle.roster.runtime(for: battle.roster.hero.combatant)?.pendingCardDamageBonus == 2)

        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) {
            $0.currentHealth = 0
            $0.pendingCardDamageBonus = 0
        }
        battle.roster.mutateRuntime(for: battle.roster.companion.combatant) { $0.pendingCardDamageBonus = 0 }
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant,
            attackerID: battle.roster.enemy.id,
            in: &battle
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.pendingCardDamageBonus == 2)
        #expect(battle.roster.runtime(for: battle.roster.hero.combatant)?.pendingCardDamageBonus == 0)
    }

    @Test func manaAbsorptionGrantsCompanionBlockWhenHeroSpendsMana() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(onHeroSpendManaGainBlock: 2)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterSpendMana(
            by: battle.roster.hero.combatant,
            amountSpent: 3,
            in: &battle
        )
        #expect(DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.companion.combatant)
        ) == 2)
        #expect(DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.hero.combatant)
        ) == 0)
    }

    @Test func aetherialFlowBuffsCompanionNextAttackWhenHeroSpendsMana() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                attack: AttackTriggers(onHeroSpendManaCompanionNextAttackBonus: 2)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterSpendMana(
            by: battle.roster.hero.combatant,
            amountSpent: 1,
            in: &battle
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.pendingCardDamageBonus == 2)
        #expect(battle.roster.runtime(for: battle.roster.hero.combatant)?.pendingCardDamageBonus == 0)
    }

    @Test func hagglerBoostsAllPartyGoldGain() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(partyGoldGainedPercent: 0.15)
            )),
            dealOpeningHand: false
        )
        battle.addGold(20, sourceActorID: battle.roster.hero.id)
        #expect(battle.gold == 23)
    }

    @Test func flawlessBountyDoublesGoldWhileCompanionAtFullHealth() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldDoubledWhileFullHealth: true)
            )),
            dealOpeningHand: false
        )
        battle.addGold(10, sourceActorID: battle.roster.hero.id)
        #expect(battle.gold == 20)

        var woundedBattle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldDoubledWhileFullHealth: true)
            )),
            dealOpeningHand: false
        )
        woundedBattle.roster.mutateRuntime(for: woundedBattle.roster.companion.combatant) { $0.currentHealth = 10 }
        woundedBattle.addGold(10, sourceActorID: woundedBattle.roster.hero.id)
        #expect(woundedBattle.gold == 10)
    }

    @Test func treasureHoardGrantsPartyCritChanceWhileCarryingEnoughGold() {
        func makeBattle(gold: Int) -> BattleState {
            // Deterministic seed plus a large bonus: with 50+ Gold the capped roll
            // succeeds; without it the base contested chance stays below the threshold.
            var battle = BattleStateTestFactory.makeBattle(
                hero: BattleTestFixtures.passiveHero(),
                companion: BattleTestFixtures.passiveCompanion(),
                enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
                companionModifiers: .init(triggers: CombatTraitTriggers(
                    damage: DamageTriggers(
                        partyCritChanceWhileGoldAbove: 50,
                        partyCritChanceWhileGoldAboveBonus: 1.0
                    )
                )),
                dealOpeningHand: false
            )
            battle.gold = gold
            return battle
        }
        var richBattle = makeBattle(gold: 50)
        var poorBattle = makeBattle(gold: 49)
        let richOutcome = richBattle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: richBattle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: richBattle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        let poorOutcome = poorBattle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: poorBattle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: poorBattle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(richOutcome.isCritical)
        #expect(!poorOutcome.isCritical)
    }

    @Test func thiefStealsEnemyBlockOnCriticalHit() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                attack: AttackTriggers(critStealEnemyBlock: true)
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            5,
            to: battle.roster.enemy.combatant,
            source: battle.roster.enemy.combatant,
            abilityName: "Test"
        )
        let companion = battle.roster.companion.combatant
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 2,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: companion.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    guaranteedCritical: true
                )
            )
        )
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.enemy.combatant)) == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: companion)) == 5)
    }

    @Test func campfireComfortRestoresEachAllyAtEndOfRound() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 20),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(partyRegenPerRound: 1)
            )),
            dealOpeningHand: false
        )
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 10 }
        battle.roster.mutateRuntime(for: battle.roster.companion.combatant) { $0.currentHealth = 10 }
        _ = CombatTriggerEngine.atPlayerEndTurn(in: &battle)
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == 11)
        #expect(battle.roster.health(for: battle.roster.companion.combatant) == 11)
    }

    @Test func fontOfMagicDoesNotRestoreManaWhenHealingSelf() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            maxMana: 5,
            abilities: []
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(onHealRestoreCasterMana: 1)
            )),
            dealOpeningHand: false
        )
        battle.roster.mutateRuntime(for: hero) {
            $0.currentHealth = 10
            $0.currentMana = 0
        }
        _ = battle.resolveHeal(HealRequest(amount: 3, target: hero, sourceActorID: hero.id))
        #expect(battle.roster.runtime(for: hero)?.currentMana == 0)
    }
}
