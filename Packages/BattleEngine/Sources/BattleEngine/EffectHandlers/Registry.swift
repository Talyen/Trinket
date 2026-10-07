import TrinketCore

package enum EffectHandlers {
    /// Total dispatch for the closed effect set. New kinds must choose a handler
    /// here before the engine can compile.
    package static func handler(for kind: EffectKind) -> any BattleEffectHandler {
        switch kind {
        case .burn: DecayingDoTHandler(type: .burn)
        case .poison: DecayingDoTHandler(type: .poison)
        case .bleed: BleedHandler()
        case .controlMeter: ControlMeterHandler()
        case .shield: BlockBuffHandler()
        case .instantHeal: InstantHealHandler()
        case .resourceGain: ResourceGainHandler()
        case .drawCards: DrawCardsHandler()
        case .drawAndPlayCards: DrawAndPlayCardsHandler()
        case .cleanse, .cleanseHealPerDebuff, .cleanseRandom, .purge, .purgeRandom: CleansePurgeHandler()
        case .panacea: PanaceaHandler()
        case .halveShield: HalveShieldHandler()
        case .deathsDoor: DeathsDoorHandler()
        case .thorns, .nextBurnBonus: StackingAmountBuffHandler()
        case .thornsFromBlockFraction: ThornsFromBlockFractionHandler()
        case .marked: MarkedHandler()
        case .criticalChanceBonus: CriticalChanceBonusHandler()
        case .restoreManaOnHit: RestoreManaOnHitHandler()
        case .damageKeywordOverride: DamageKeywordOverrideHandler()
        case .nextHolyStrike, .nextStrikeDouble, .playNextCardTwice, .evadeNextHit, .nextStrikeCritical,
             .nextStrikeLeech, .nextStrikeDamageKeywordOverride, .freezeNextAttacker: FlagEffectHandler()
        case .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold: ShieldFromResourceHandler()
        case .maximumManaBonus: MaximumManaBonusHandler()
        case .partyDamageBonus: PartyDamageBonusHandler()
        case .onHitDamage: OnHitDamageHandler()
        case .multiplyControlMeter: MultiplyControlMeterHandler()
        case .multiplyDoT: MultiplyDoTHandler()
        case .detonateDoT: DetonateDoTHandler()
        case .recurringDamage: RecurringDamageHandler()
        case .avatar: AvatarHandler()
        case .blessedAegis: BlessedAegisHandler()
        case .revive: ReviveHandler()
        case .damageReductionPercent, .damageReductionFlat, .healingReductionPercent: TimedDebuffHandler()
        case .hemorrhage: HemorrhageHandler()
        }
    }
}
