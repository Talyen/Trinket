import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: [
        ("warlock_leech_t4_1", Keyword.burn),
        ("panther_leech_t4_1", Keyword.bleed),
    ])
    func `elemental leech works on ticks without doubling existing leech`(talent: String, keyword: Keyword) {
        var battle = capstoneBattle(companion: [talent])
        battle.roster.companion.currentHealth = 1
        var alreadyLeeches = battle
        var options = DamageOptions.doTTick
        options.abilityHasLeech = true
        let normal = battle.resolveDamage(.doTTick(
            amount: 8, target: battle.enemy, keyword: keyword, sourceActorID: battle.companion.id,
        ))
        _ = alreadyLeeches.resolveDamage(DamageRequest(
            amount: 8, target: alreadyLeeches.enemy, keyword: keyword,
            sourceActorID: alreadyLeeches.companion.id, options: options,
        ))
        #expect(normal.healthLost == 8)
        #expect(battle.roster.companion.currentHealth > 1)
        #expect(battle.roster.companion.currentHealth == alreadyLeeches.roster.companion.currentHealth)
        let health = battle.roster.companion.currentHealth
        _ = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: .holy,
            sourceActorID: battle.companion.id, options: .flatReaction,
        ))
        #expect(battle.roster.companion.currentHealth == health)
    }

    @Test func `borrowed life only leeches physical damage during deaths door`() {
        var battle = capstoneBattle(companion: ["risen_skeleton_deathsdoor_t4_1"])
        battle.roster.companion.currentHealth = 1
        let hit = DamageRequest(
            amount: 8, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.companion.id, options: .flatReaction,
        )
        _ = battle.resolveDamage(hit)
        #expect(battle.roster.companion.currentHealth == 1)
        seedHeroTalentEffect(.deathsDoor, on: .companion, in: &battle)
        _ = battle.resolveDamage(hit)
        #expect(battle.roster.companion.currentHealth > 1)
        let health = battle.roster.companion.currentHealth
        _ = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: .holy,
            sourceActorID: battle.companion.id, options: .flatReaction,
        ))
        #expect(battle.roster.companion.currentHealth == health)
    }

    @Test func `undying ember heals through block without adding burn or blocking its decay`() {
        var battle = capstoneBattle(companion: ["phoenix_deathsdoor_t4_1"])
        seedHeroTalentEffect(.burn(4), on: .companion, in: &battle, source: .enemy)
        seedHeroTalentEffect(.shield(.block, 5), on: .companion, in: &battle)
        seedHeroTalentEffect(.deathsDoor, on: .companion, in: &battle)
        battle.roster.companion.currentHealth = 1
        let events = DoTApplicator.applyDecayingDoT(
            keyword: .burn, potency: 4, to: battle.companion, sourceActorID: battle.enemy.id,
            dealImmediateDamage: true, in: &battle,
        )
        #expect(battle.roster.companion.currentHealth == 5)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 5)
        #expect(talentPoints(.burn, on: .companion, in: battle) == 4)
        #expect(events.contains { $0.abilityName == "Undying Ember" && $0.amount == 4 })
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.companion.currentHealth == 7)
        #expect(talentPoints(.burn, on: .companion, in: battle) < 4)
        ActiveEffectMutation.removeMatching(from: battle.companion, in: &battle) { $0.kind == .deathsDoor }
        DefensePoolEngine.set(0, on: battle.companion, in: &battle)
        let hit = battle.resolveDamage(.doTTick(
            amount: 2, target: battle.companion, keyword: .burn, sourceActorID: battle.enemy.id,
        ))
        #expect(hit.healthLost == 2)
    }

    @Test func `winters wake reflects dodged damage as A freeze hit before block`() {
        var battle = capstoneBattle(companion: ["frost_whelp_dodge_t4_1"])
        seedHeroTalentEffect(.evadeNextHit, on: .companion, in: &battle)
        seedHeroTalentEffect(.shield(.block, 20), on: .companion, in: &battle)
        var options = DamageOptions.directAbilityHit
        options.applyItemBonus = false
        options.applyStatBonus = false
        let result = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id, options: options,
        ))
        #expect(result.flags.contains(.dodged))
        #expect(result.events.contains { $0.kind == .abilityDamage && $0.keyword == .freeze && $0.amount == 4 })
        #expect(battle.roster.enemy.currentHealth == 196)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 20)
        #expect(battle.roster.enemy.activeEffects.contains {
            if case let .controlMeter(.freeze, amount, _) = $0.effect {
                return amount == 4
            }
            return false
        })
        seedHeroTalentEffect(.evadeNextHit, on: .companion, in: &battle)
        options.causedByDodge = true
        _ = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id, options: options,
        ))
        #expect(battle.roster.enemy.currentHealth == 196)
    }

    @Test func `killing grace uses current dodge chance and respects critical cap`() {
        var battle = capstoneBattle(companion: ["panther_dodge_t4_1", "panther_dodge_t2_1"])
        let healthy = CriticalChanceEngine.chance(actorID: battle.companion.id, defender: battle.enemy, in: battle)
        #expect(abs(healthy - 0.20) < 0.0001)
        battle.roster.companion.currentHealth = 1
        let injured = CriticalChanceEngine.chance(actorID: battle.companion.id, defender: battle.enemy, in: battle)
        #expect(abs(injured - 0.45) < 0.0001)
        seedHeroTalentEffect(.criticalChanceBonus(1, 2), on: .companion, in: &battle)
        #expect(CriticalChanceEngine.chance(actorID: battle.companion.id, defender: battle.enemy, in: battle) == 0.75)
    }

    @Test func `carrion claim rewards poison and bleed damage including ticks but not blocked damage`() {
        var battle = capstoneBattle(companion: ["lizard_scout_gold_t4_1"])
        for keyword in [Keyword.poison, .bleed, .physical] {
            _ = battle.resolveDamage(.doTTick(
                amount: 2, target: battle.enemy, keyword: keyword, sourceActorID: battle.companion.id,
            ))
        }
        #expect(battle.gold == 2)
        seedHeroTalentEffect(.shield(.block, 10), on: .enemy, in: &battle)
        _ = battle.resolveDamage(.doTTick(
            amount: 2, target: battle.enemy, keyword: .poison, sourceActorID: battle.companion.id,
        ))
        #expect(battle.gold == 2)
    }

    @Test func `ghostfrost deals health damage and builds freeze without consuming block`() {
        var battle = capstoneBattle(companion: ["mana_moth_freeze_t4_1"])
        seedHeroTalentEffect(.shield(.block, 10), on: .enemy, in: &battle)
        let result = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .freeze,
            sourceActorID: battle.companion.id, options: .flatControlReaction,
        ))
        #expect(result.healthLost == 4)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 10)
        #expect(battle.roster.enemy.activeEffects.contains {
            if case let .controlMeter(.freeze, amount, _) = $0.effect {
                return amount == 4
            }
            return false
        })
    }

    @Test(arguments: [(Effect.thorns(4), Keyword.stun), (.onHitDamage(.freeze, 4), .freeze)])
    func `retaliation wards consume their effect and deal typed control damage`(ward: Effect, keyword: Keyword) {
        var battle = capstoneBattle(companion: keyword == .stun ? ["shield_scarab_stun_t4_1"] : [])
        seedHeroTalentEffect(ward, on: .companion, in: &battle)
        seedHeroTalentEffect(.controlMeter(keyword, 38, 40), on: .enemy, in: &battle)
        var options = DamageOptions.directAbilityHit
        options.applyDodge = false
        let result = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id, options: options,
        ))
        #expect(battle.roster.enemy.currentHealth == 196)
        #expect(result.events.contains { $0.effectKind == .thornsTriggered && $0.keyword == keyword && $0.amount == 4 })
        #expect(result.events.contains { $0.effectKind == .controlTriggered && $0.keyword == keyword })
        #expect(talentPoints(ward.kind, on: .companion, in: battle) == 0)
        #expect(battle.roster.enemy.activeEffects.contains {
            if case let .controlMeter(appliedKeyword, amount, _) = $0.effect {
                return appliedKeyword == keyword && amount == 40
            }
            return false
        })
    }

    @Test func `stolen thunder spends block once per attack and leaves other damage unchanged`() {
        var battle = capstoneBattle(companion: ["fox_stun_t4_1"])
        seedHeroTalentEffect(.shield(.block, 4), on: .companion, in: &battle)
        var options = DamageOptions.flatControlReaction
        options.isAttackHit = true
        options.abilityCriticalChanceBonus = -1
        let hit = DamageRequest(
            amount: 2, target: battle.enemy, keyword: .stun,
            sourceActorID: battle.companion.id, options: options,
        )
        #expect(battle.resolveDamage(hit).healthLost == 6)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 0)
        seedHeroTalentEffect(.shield(.block, 3), on: .companion, in: &battle)
        #expect(battle.resolveDamage(hit).healthLost == 2)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 3)
        battle.actionCount += 1
        #expect(battle.resolveDamage(hit).healthLost == 5)
    }

    @Test(arguments: [3, 10])
    func `bounty blade steals available block without replacing the played card`(block: Int) {
        var battle = capstoneBattle(hero: ["rogue_gold_t4_1"])
        battle.heroDeck.putOnBottom(.slash)
        seedHeroTalentEffect(.shield(.block, block), on: .enemy, in: &battle)
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: DamageOptions(applyDodge: false, guaranteedCritical: true, isAttackHit: true),
        ))
        #expect(outcome.isCritical)
        #expect(battle.gold == 3)
        #expect(talentPoints(.shield, on: .hero, in: battle) == min(3, block - 2))
        #expect(talentPoints(.shield, on: .enemy, in: battle) == max(0, block - 5))
        #expect(battle.hand.totalCount == 0)
        #expect(!outcome.events.contains { $0.effectKind == .cardsDrawn })
    }

    @Test(arguments: [Ability.frostbolt, .rayOfFrost])
    func `steam explosion consumes burn for freeze cards but not frostfire reactions`(card: Ability) throws {
        var battle = capstoneBattle(companion: ["mana_moth_burn_t4_1", "mana_moth_burn_t4_2"])
        battle.roster.companion.currentMana = 0
        seedHeroTalentEffect(.burn(8), on: .enemy, in: &battle, source: .companion)
        _ = battle.resolveDamage(.doTTick(
            amount: 4, target: battle.enemy, keyword: .burn, sourceActorID: battle.companion.id,
        ))
        #expect(talentPoints(.burn, on: .enemy, in: battle) == 8)
        let events = try playHeroTalentCard(card, owner: .companion, in: &battle)
        let hit = try #require(events.first { $0.kind == .abilityDamage && $0.keyword == .freeze })
        let damage = card == .frostbolt ? 11 : 8
        #expect(hit.amount == damage * (hit.isCritical ? 2 : 1))
        #expect(talentPoints(.burn, on: .enemy, in: battle) == 0)
    }

    @Test(arguments: [Keyword.physical, .burn, .poison, .bleed, .holy, .freeze, .stun])
    func `backdraft converts burn into the critical attacks element without retriggering`(keyword: Keyword) {
        var battle = capstoneBattle(hero: ["wizard_burn_t4_1"])
        seedHeroTalentEffect(.burn(5), on: .enemy, in: &battle)
        _ = battle.resolveDamage(.doTTick(
            amount: 2, target: battle.enemy, keyword: .burn, sourceActorID: battle.hero.id,
        ))
        #expect(talentPoints(.burn, on: .enemy, in: battle) == 5)
        let request = DamageRequest(
            amount: 2, target: battle.enemy, keyword: keyword, sourceActorID: battle.hero.id,
            options: DamageOptions(applyDodge: false, guaranteedCritical: true, isAttackHit: true),
        )
        let hit = battle.resolveDamage(request)
        #expect(hit.isCritical)
        #expect(hit.healthLost == 9)
        #expect(talentPoints(.burn, on: .enemy, in: battle) == 0)
        let next = battle.resolveDamage(request)
        #expect(next.healthLost == 4)
    }
}
