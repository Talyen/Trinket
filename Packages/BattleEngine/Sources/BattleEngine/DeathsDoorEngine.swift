import Foundation
import TrinketContent
import TrinketCore

package enum DeathsDoorEngine {
    package static func applies(to combatant: Combatant) -> Bool {
        combatant.role != .enemy
    }

    package static func isActive(for combatant: Combatant, in context: BattleState) -> Bool {
        context.roster.isDeathsDoorActive(for: combatant)
    }

    package static func hasLethalProtection(
        for combatant: Combatant,
        in context: BattleState,
    ) -> Bool {
        if context.roster.isDeathsDoorActive(for: combatant) {
            return true
        }
        guard let runtime = context.roster.runtime(for: combatant),
              runtime.hasConsumedDeathsDoor,
              runtime.deathsDoorExpiredAtTurn == context.turnCount
        else { return false }
        return true
    }

    package static func resolveAfterDamage(
        to combatant: Combatant,
        in context: inout BattleState,
    ) async {
        guard applies(to: combatant) else { return }

        let health = context.roster.health(for: combatant)
        if health == 0 {
            if combatant.role == .hero {
                await applyPhoenixGift(on: combatant, in: &context)
                if context.roster.health(for: combatant) > 0 {
                    return
                }
            }
            if await tryTraitDeathRevive(on: combatant, in: &context) {
                return
            }
            if !context.roster.hasConsumedDeathsDoor(for: combatant) {
                await trigger(on: combatant, in: &context)
                return
            }
            if hasLethalProtection(for: combatant, in: context) {
                clampToMinimumHP(on: combatant, in: &context)
            }
        }
        if context.roster.health(for: combatant) == 0,
           context.roster.enemy.isAlive {
            let explosion = context.modifiers(for: combatant.id).triggers.onDeathDealPhysicalDamageAllEnemies
            if explosion > 0 {
                _ = await context.dealReactionDamage(
                    explosion, to: context.roster.enemy.combatant, keyword: .physical, sourceActorID: combatant.id,
                )
            }
        }
    }

    private static func applyPhoenixGift(
        on combatant: Combatant,
        in context: inout BattleState,
    ) async {
        let companionTriggers = context.companionModifiers.triggers
        guard combatant.role == .hero,
              context.roster.companion.isAlive,
              companionTriggers.onHeroFatalReviveHealth > 0,
              let compRuntime = context.roster.runtime(for: context.roster.companion.combatant),
              !compRuntime.hasTriggeredPhoenixGift
        else { return }
        context.roster.mutateRuntime(for: context.roster.companion.combatant) { runtime in
            runtime.hasTriggeredPhoenixGift = true
        }
        _ = await HealingEngine.resolveHeal(
            HealRequest(
                amount: companionTriggers.onHeroFatalReviveHealth,
                target: combatant,
                sourceActorID: context.roster.companion.id,
                origin: .restoration(.health), logAs: .instantHeal(
                    source: .init(context.roster.companion),
                    abilityName: "Phoenix Gift",
                    keyword: .health,
                ),
                revivesIfDead: true,
                skipFightPacing: true,
            ),
            in: &context,
        )
    }

    private static func tryTraitDeathRevive(
        on combatant: Combatant,
        in context: inout BattleState,
    ) async -> Bool {
        guard let runtime = context.roster.runtime(for: combatant),
              !runtime.hasTriggeredDeathRevive
        else { return false }

        let triggers = context.modifiers(for: combatant.id).triggers
        let reviveHealth = triggers.onceDeathReviveHealth
        let reviveBlock = triggers.onceDeathReviveBlock
        guard reviveHealth > 0 else { return false }

        let healthToRestore = CombatGain.amount(reviveHealth, current: 0, cap: runtime.maxHealth)
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.hasTriggeredDeathRevive = true
            runtime.currentHealth = healthToRestore
        }

        let abilityName = reviveHealth >= 10 ? "Rebirth" : "Deathrattle"
        context.nextEvent(
            kind: .effect(.instantHeal),
            source: .init(combatant),
            abilityName: abilityName,
            target: combatant,
            amount: healthToRestore,
            keyword: .health,
        )
        if reviveBlock > 0 {
            context.applyBlockGain(reviveBlock, to: combatant, source: combatant, abilityName: abilityName)
        }
        if triggers.reviveDealBurnDamage > 0, context.roster.enemy.isAlive {
            await context.applyDecayingDoT(
                keyword: .burn,
                potency: triggers.reviveDealBurnDamage,
                to: context.roster.enemy.combatant,
                sourceActorID: combatant.id,
                application: .reaction,
            )
        }
        return true
    }

    private static func trigger(
        on combatant: Combatant,
        in context: inout BattleState,
    ) async {
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.hasConsumedDeathsDoor = true
            runtime.currentHealth = 1
        }

        let triggers = context.modifiers(for: combatant.id).triggers
        let duration = SaturatedArithmetic.saturatingAdd(
            BattleTiming.deathsDoorDurationTurns, triggers.deathsDoorDurationBonusTurns,
        )
        context.insertEffect(
            .deathsDoor,
            to: combatant,
            remainingTurns: duration, at: 0,
        )

        context.nextEvent(
            kind: .effect(.deathsDoorTriggered),
            source: .init(combatant),
            abilityName: Keyword.deathsDoor.rawValue,
            target: combatant,
            amount: 0,
            keyword: .deathsDoor,
        )
        if triggers.firstBelowHalfHealthHeal > 0,
           context.resolution.claim(.heroTalent(.vitalInfusion), actorID: combatant.id, cadence: .battle) {
            await context.healEmitting(
                amount: triggers.firstBelowHalfHealthHeal,
                target: combatant, source: combatant, abilityName: "Vital Infusion",
            )
        }
        if triggers.enterDeathsDoorDrawCard,
           let owner = context.roster.participant(for: combatant) {
            CombatTriggerEngine.drawCards(1, for: owner, actor: combatant, abilityName: "Deathrattle", in: &context)
        }
        let blockAmount = triggers.blockOnDeathsDoor
        if blockAmount > 0 {
            context.applyBlockGain(blockAmount, to: combatant, source: combatant, abilityName: "Deathgrip")
        }
        await phoenixEnteringDeathsDoor(on: combatant, triggers: triggers, in: &context)
        await guardianArchive(on: combatant, in: &context)
    }

    private static func phoenixEnteringDeathsDoor(
        on combatant: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        if triggers.enterDeathsDoorHeal > 0 {
            await context.healEmitting(
                amount: triggers.enterDeathsDoorHeal,
                target: combatant,
                source: combatant,
                abilityName: "From the Ashes",
            )
        }
        if triggers.enterDeathsDoorBurnDamage > 0, context.roster.enemy.isAlive {
            await context.applyDecayingDoT(
                keyword: .burn,
                potency: triggers.enterDeathsDoorBurnDamage,
                to: context.roster.enemy.combatant,
                sourceActorID: combatant.id,
                application: .reaction,
            )
        }
    }

    private static func guardianArchive(
        on combatant: Combatant,
        in context: inout BattleState,
    ) async {
        let companionTriggers = context.companionModifiers.triggers
        guard combatant.role != .enemy,
              context.roster.companion.isAlive,
              companionTriggers.onAllyDeathsDoorRestoreHealth > 0
        else { return }
        await context.healEmitting(
            amount: companionTriggers.onAllyDeathsDoorRestoreHealth,
            target: combatant,
            source: context.roster.companion.combatant,
            abilityName: "Guardian Archive",
        )
    }

    private static func afterglow(
        on combatant: Combatant,
        in context: inout BattleState,
    ) async {
        let companionTriggers = context.companionModifiers.triggers
        guard combatant.role == .companion, companionTriggers.surviveDeathsDoorPartyHealFlat > 0 else {
            return
        }

        for owner in BattleParticipant.party {
            let member = context.roster[owner]
            guard member.isAlive else { continue }
            let maxHealth = context.roster.maxHealth(for: member.combatant)
            guard context.roster.health(for: member.combatant) < maxHealth else { continue }
            _ = await HealingEngine.resolveHeal(
                HealRequest(
                    amount: companionTriggers.surviveDeathsDoorPartyHealFlat,
                    target: member.combatant,
                    sourceActorID: context.roster.companion.id,
                    origin: .restoration(.health), logAs: .instantHeal(
                        source: .init(combatant),
                        abilityName: "Afterglow",
                        keyword: .health,
                    ),
                    skipFightPacing: true,
                ),
                in: &context,
            )
        }
    }

    static func afterDeathsDoorExpired(
        on combatant: Combatant,
        in context: inout BattleState,
    ) async {
        guard context.roster.health(for: combatant) > 0 else { return }
        let triggers = context.modifiers(for: combatant.id).triggers
        if triggers.surviveDeathsDoorNextAttackDouble {
            context.roster.mutateRuntime(for: combatant) {
                $0.talents.pending.doubleNextAttackAfterDeathsDoor = true
            }
        }
        await afterglow(on: combatant, in: &context)
        if triggers.affixDeathsDoorSurviveHealFlat > 0 {
            await context.healEmitting(
                amount: triggers.affixDeathsDoorSurviveHealFlat,
                target: combatant, source: combatant,
                abilityName: context.modifiers(for: combatant.id).triggerAbilityName(
                    .affixDeathsDoorSurviveHealFlat, fallback: "Rekindled",
                ),
            )
        }
        if triggers.surviveDeathsDoorPartyBlockFlat > 0, context.roster.enemy.isAlive {
            for owner in BattleParticipant.party {
                let member = context.roster[owner]
                guard member.isAlive else { continue }
                context.applyBlockGain(
                    triggers.surviveDeathsDoorPartyBlockFlat,
                    to: member.combatant,
                    source: combatant,
                    abilityName: "Endless Legion",
                )
            }
        }
        let amount = triggers.deathsDoorExpiredHealFlat
        guard amount > 0,
              context.claimBattleGuard(.endlessLegion, actorID: combatant.id)
        else { return }
        let maxHealth = context.roster.maxHealth(for: combatant)
        let currentHealth = context.roster.health(for: combatant)
        // `deathsDoorExpiredHealFlat` is a health floor, not a flat heal: it only
        // tops up a survivor below that value (see DeathsDoorEngineTests).
        let delta = min(max(currentHealth, amount), maxHealth) - currentHealth
        guard delta > 0 else { return }
        _ = await HealingEngine.resolveHeal(
            HealRequest(
                amount: delta,
                target: combatant,
                sourceActorID: combatant.id,
                origin: .restoration(.health), logAs: .instantHeal(
                    source: .init(combatant),
                    abilityName: "Endless Legion",
                    keyword: .health,
                ),
                skipFightPacing: true,
            ),
            in: &context,
        )
    }

    private static func clampToMinimumHP(
        on combatant: Combatant,
        in context: inout BattleState,
    ) {
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.currentHealth = max(1, runtime.currentHealth)
        }
    }
}
