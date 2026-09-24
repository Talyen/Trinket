import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatBuildResolverTests {
    @Test(arguments: [0.0, 0.25, 1.0])
    func `shredding ignores only its share of mitigation`(ignored: Double) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(ignoreEnemyMitigationPercent: ignored),
            )),
            enemyModifiers: .init(incomingDamageReductionPercent: 0.8),
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 100, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.hero.id, options: .reaction(),
        ))
        #expect(outcome.healthLost == CombatRounding.scaled(100, multiplier: 1 - 0.8 * (1 - ignored)))
    }

    @Test(arguments: [(4, 0.0, 0), (4, 0.5, 0), (14, 0.5, 9), (4, 1.0, 4)])
    func `shredding scales flat defenses before clamping damage`(damage: Int, ignored: Double, expected: Int) {
        var attacker = CombatModifierProfile.zero
        attacker.triggers.ignoreEnemyMitigationPercent = ignored
        var passive = CombatModifierProfile.zero
        passive.triggers.passiveMitigationFlat = 10
        for defender in [CombatModifierProfile(damageTakenFlat: [.physical: 10]), passive] {
            var battle = BattleStateTestFactory.makeMinimalBattle(
                hero: CombatantFixtures.passiveHero(),
                companion: CombatantFixtures.passiveCompanion(),
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
                heroModifiers: attacker, enemyModifiers: defender,
            )
            battle.appliesFightPacing = false
            let outcome = battle.resolveDamage(DamageRequest(
                amount: damage, target: battle.enemy, keyword: .physical,
                sourceActorID: battle.hero.id, options: .reaction(),
            ))
            #expect(outcome.healthLost == expected)
        }
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `beastbond strengthens companion from either wearer`(owner: BattleParticipant) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "beastbond"))
        let item = try ItemFixtures.makeBareItem("ruby_ring", affixes: [affix.resolved(for: .basic)])
        let hero = CombatantFixtures.passiveHero()
        let companion = CombatantFixtures.passiveCompanion()
        let build = CombatBuildResolver.build(
            combatant: owner == .hero ? hero : companion,
            equipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.accessory: item.id]),
            inventory: [item],
        )
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: hero, companion: companion,
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: owner == .hero ? build.modifiers : .zero,
            companionModifiers: owner == .companion ? build.modifiers : .zero,
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical,
            sourceActorID: companion.id,
            options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(outcome.healthLost == 11)
    }

    @Test func `leech armor pierce bypasses mitigation only for leech abilities`() {
        func makeBattle(leechPierce: Bool) -> BattleState {
            var battle = BattleStateTestFactory.makeMinimalBattle(
                hero: CombatantFixtures.passiveHero(),
                companion: CombatantFixtures.passiveCompanion(),
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
                heroModifiers: .init(triggers: CombatTraitTriggers(
                    damage: DamageTriggers(leechIgnoresMitigation: leechPierce),
                )),
                enemyModifiers: .init(incomingDamageReductionPercent: 0.8),
            )
            battle.appliesFightPacing = false
            return battle
        }
        func dealDamage(leechAbility: Bool, in battle: inout BattleState) -> Int {
            var options: DamageOperation = .reaction()
            options.abilityHasLeech = leechAbility
            return battle.resolveDamage(DamageRequest(
                amount: 100, target: battle.enemy, keyword: .physical,
                sourceActorID: battle.hero.id, options: options,
            )).healthLost
        }
        var bypass = makeBattle(leechPierce: true)
        #expect(dealDamage(leechAbility: true, in: &bypass) == 100)
        var noLeechFlag = makeBattle(leechPierce: true)
        #expect(dealDamage(leechAbility: false, in: &noLeechFlag) == CombatRounding.scaled(100, multiplier: 0.2))
        var noTrigger = makeBattle(leechPierce: false)
        #expect(dealDamage(leechAbility: true, in: &noTrigger) == CombatRounding.scaled(100, multiplier: 0.2))
    }

    @Test func `outermost damage drains every out-of-turn queue`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
        )
        battle.appliesFightPacing = false
        battle.uniques.pendingCounterAttackActorIDs = [battle.hero.id]
        battle.uniques.pendingBlockAnswerOwners = [.hero]
        _ = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.hero.id, options: .reaction(),
        ))
        #expect(battle.uniques.pendingCounterAttackActorIDs.isEmpty)
        #expect(battle.uniques.pendingBlockAnswerOwners.isEmpty)
        #expect(battle.uniques.isDrainingOutOfTurnAttacks == false)
    }

    @Test(arguments: [41, 60, 100, 250, 1000], [false, true])
    func `enemy build keeps growing past forty`(level: Int, isBoss: Bool) throws {
        let enemy = try #require(GameContent.enemies.first { $0.isBoss == isBoss })
        let previous = CombatBuildResolver.build(enemy: enemy, level: level - 1)
        let current = CombatBuildResolver.build(enemy: enemy, level: level)
        let atForty = CombatBuildResolver.build(enemy: enemy, level: 40)
        #expect(current.combatant.maxHealth >= previous.combatant.maxHealth)
        #expect(current.combatant.maxHealth > atForty.combatant.maxHealth)
        #expect(current.modifiers.outgoingDamagePercent > previous.modifiers.outgoingDamagePercent)
        #expect(current.combatant.abilityChoices == enemy.combatant.abilityChoices)
    }

    @Test func `ranged damage dealt bonus requires equipped ranged weapon`() throws {
        let rangedWeapon = try ItemFixtures.makeBareItem("shortbow")
        let meleeWeapon = try ItemFixtures.makeBareItem("longsword")
        let hero = CombatantFixtures.passiveHero()

        let rangedBonus = [AffixModifier.rangedDamageDealt(3)]

        let rangedBuild = CombatBuildResolver.build(
            combatant: hero,
            equipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.weapon: rangedWeapon.id]),
            inventory: [rangedWeapon],
            additionalModifiers: rangedBonus,
        )
        #expect(rangedBuild.modifiers.damageDealtBonus[.physical] == 3)

        let meleeBuild = CombatBuildResolver.build(
            combatant: hero,
            equipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.weapon: meleeWeapon.id]),
            inventory: [meleeWeapon],
            additionalModifiers: rangedBonus,
        )
        #expect(meleeBuild.modifiers.damageDealtBonus[.physical] == nil)
    }

    @Test func `maximum mana percent scales combatants with mana and leaves zero mana unchanged`() {
        let heroWithMana = CombatantFixtures.passiveHero(maxMana: 20)
        #expect(heroWithMana.hasMana)

        let modifiers = CombatModifierProfile(maximumManaPercentBonus: 0.20)
        let scaledMana = CombatantMaxValues.maxMana(for: heroWithMana, modifiers: modifiers)
        #expect(scaledMana == 24)

        let heroNoMana = CombatantFixtures.passiveHero(maxMana: 0)
        #expect(!heroNoMana.hasMana)
        let zeroMana = CombatantMaxValues.maxMana(for: heroNoMana, modifiers: modifiers)
        #expect(zeroMana == 0)
    }
}
