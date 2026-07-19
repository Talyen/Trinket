import CoreGraphics
import Testing
import TrinketDesignSystem

struct TrinketMotionTests {
    @Test func rewardRevealTimingStaysBriefAndSequential() {
        #expect(TrinketMotion.Reward.resourceStagger > 0)
        #expect(TrinketMotion.Reward.resourceStagger < 0.2)
        #expect(TrinketMotion.Reward.itemRevealDelay > TrinketMotion.Reward.resourceStagger)
        #expect(TrinketMotion.Reward.completionDelay > TrinketMotion.Reward.itemRevealDelay)

        #expect(ArtworkBlendRecipe.perimeterInset == 0.22)
        #expect(TrinketMotion.Battle.ultimateSkipLockout > 0)
        #expect(TrinketMotion.Battle.ultimateFallbackHold > 0)
        #expect(TrinketMotion.Battle.ultimateVideoWatchdog > TrinketMotion.Battle.ultimateFallbackHold)
        #expect(TrinketMotion.Battle.feedbackQueueStagger == 0.1)
        #expect(TrinketMotion.Labyrinth.modifierStagger > 0)
        #expect(TrinketMotion.Labyrinth.modifierStagger < 0.2)
        #expect(TrinketMotion.Battle.maxConcurrentCardCasts == 1)
        #expect(TrinketMotion.Battle.maxKeywordBurstsPerPane == 1)
        #expect(
            TrinketMotion.Battle.skillCalloutTotal
                == TrinketMotion.Battle.skillCalloutIn
                + TrinketMotion.Battle.skillCalloutHold
                + TrinketMotion.Battle.skillCalloutOut
        )
    }

    @Test func chipStylesStayWithinSemanticContracts() {
        let critical = TrinketMotion.Battle.chip(for: .critical)
        let normal = TrinketMotion.Battle.chip(for: .directDamage)
        let deathsDoor = TrinketMotion.Battle.chip(for: .deathsDoor)

        #expect(critical.textStyle == .largeTitle)
        #expect(critical.fontWeight == .heavy)
        #expect(normal.textStyle == .title)
        #expect(normal.fontWeight == .bold)
        #expect(!critical.showsSecondaryCaption)

        #expect(deathsDoor.textStyle == critical.textStyle)
        #expect(TrinketMotion.Battle.chip(for: .heal).textStyle == normal.textStyle)
        #expect(TrinketMotion.Battle.maxChipLifetime > TrinketMotion.Battle.chipDisplayDuration)
    }

    @Test func chipStylesCoverEveryFeedbackClass() {
        for feedbackClass in CombatFeedbackClass.allCases {
            let style = TrinketMotion.Battle.chip(for: feedbackClass)
            #expect(style.feedbackClass == feedbackClass)
            switch feedbackClass {
            case .critical, .deathsDoor:
                #expect(style.textStyle == .largeTitle)
                #expect(style.fontWeight == .heavy)
                #expect(style.chrome == .emphasis)
            case .directDamage, .heal, .dot, .block, .dodge, .control, .buff, .resource:
                #expect(style.textStyle == .title)
                #expect(style.fontWeight == .bold)
                #expect(style.chrome == .standard)
            }
        }
    }

    @Test func combatFeedbackUsesOneSecondDeceleratingRiseAndFinalFade() {
        #expect(TrinketMotion.Battle.chipDisplayDuration == 1)
        #expect(TrinketMotion.Battle.chipFadeOutDuration == 0.2)
        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: 0) == 0)
        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: 0.5) == 0.75)
        #expect(TrinketMotion.Battle.chipMotionProgress(elapsed: 1) == 1)

        let firstQuarter = TrinketMotion.Battle.chipMotionProgress(elapsed: 0.25)
        let secondQuarter = TrinketMotion.Battle.chipMotionProgress(elapsed: 0.5) - firstQuarter
        let lastQuarter = TrinketMotion.Battle.chipMotionProgress(elapsed: 1)
            - TrinketMotion.Battle.chipMotionProgress(elapsed: 0.75)
        #expect(firstQuarter > secondQuarter)
        #expect(secondQuarter > lastQuarter)

        #expect(TrinketMotion.Battle.chipOpacity(elapsed: 0) == 1)
        #expect(TrinketMotion.Battle.chipOpacity(elapsed: 0.8) == 1)
        #expect(abs(TrinketMotion.Battle.chipOpacity(elapsed: 0.9) - 0.5) < 0.0001)
        #expect(TrinketMotion.Battle.chipOpacity(elapsed: 1) == 0)

        let travel = TrinketMotion.Battle.chipTravelDistance(cardHeight: 200, chipHeight: 40)
        #expect(travel == 72)
        #expect(100 - travel >= 20 + TrinketMotion.Battle.chipTopClearance)
    }

    @Test func cardReactionsCoverAllKinds() {
        for kind in CombatantHitReactionKind.allCases {
            let recipe = TrinketMotion.Battle.cardReaction(for: kind)
            #expect(recipe.kind == kind)
            #expect(recipe.duration > 0)
        }

        let damage = TrinketMotion.Battle.cardReaction(for: .damage)
        let critical = TrinketMotion.Battle.cardReaction(for: .critical)
        #expect(damage.scaleX.first?.value == 0.96)
        #expect(damage.scaleY.first?.value == 1.025)
        #expect(abs(damage.offsetX.first?.value ?? 0) == 4)
        #expect(critical.scaleX.first?.value == 0.93)
        #expect(critical.scaleY.first?.value == 1.04)
        #expect(abs(critical.offsetX.first?.value ?? 0) == 7)

        let celebrate = TrinketMotion.Battle.cardReaction(for: .celebrate)
        #expect((celebrate.scaleX.first?.value ?? 0) > 1)
        #expect((celebrate.scaleY.first?.value ?? 1) < 1)
        #expect((celebrate.offsetY.first?.value ?? 0) < 0)
        #expect(celebrate.rotation.count >= 8)
        #expect(celebrate.duration == 1.0)
        #expect((celebrate.rotation.first?.value ?? 0) < 0)
        #expect(celebrate.rotation[1].value > 0)
    }

    @Test func cardAttacksCoverAllKindsAndLungeImpactTiming() {
        for kind in CombatantAttackReactionKind.allCases {
            let recipe = TrinketMotion.Battle.cardAttack(for: kind)
            #expect(recipe.kind == kind)
            #expect(recipe.duration > 0)
            #expect(recipe.impactDelay >= 0)
            #expect(recipe.impactDelay <= recipe.duration)
        }

        let lunge = TrinketMotion.Battle.cardAttack(for: .attack)
        #expect(lunge.scaleX.count == 3)
        #expect(lunge.scaleY.count == 3)
        #expect(lunge.offsetY.count == 3)
        #expect(lunge.rotation.count == 3)
        #expect(lunge.impactDelay == 0.55)
        #expect(lunge.duration == 1.0)
        #expect((lunge.offsetY[0].value) < 0)
        #expect((lunge.offsetY[1].value) > 0)
        #expect(lunge.offsetY[2].value == 0)
        let windUpPlusSwing = (lunge.offsetY[0].duration) + (lunge.offsetY[1].duration)
        #expect(abs(lunge.impactDelay - windUpPlusSwing) < 0.001)

        let enemyAim = TrinketMotion.Battle.attackAim(isPartyMember: false)
        let partyAim = TrinketMotion.Battle.attackAim(isPartyMember: true)
        #expect(enemyAim == .towardParty)
        #expect(partyAim == .towardEnemy)
        #expect(lunge.windUpPose(aim: enemyAim).offsetY < 0)
        #expect(lunge.swingPose(aim: enemyAim).offsetY > 0)
        #expect(lunge.windUpPose(aim: partyAim).offsetY > 0)
        #expect(lunge.swingPose(aim: partyAim).offsetY < 0)
        #expect(lunge.restPose == .rest)
        #expect(lunge.windUpDuration == 0.40)
        #expect(lunge.swingDuration == 0.15)
        #expect(lunge.recoverDuration == 0.45)
    }

    @Test func hitRecoilDirectionFlipsOffsetAndScaleAxes() {
        let magnitude: CGFloat = 4
        let upOffset = CombatantHitRecoilDirection.up.impactOffset(magnitude: magnitude)
        let downOffset = CombatantHitRecoilDirection.down.impactOffset(magnitude: magnitude)
        #expect(upOffset.width == 0)
        #expect(upOffset.height == -magnitude)
        #expect(downOffset.width == 0)
        #expect(downOffset.height == magnitude)

        let damage = TrinketMotion.Battle.cardReaction(for: .damage)
        let scaleX = damage.scaleX.first?.value ?? 1
        let scaleY = damage.scaleY.first?.value ?? 1
        let upScales = CombatantHitRecoilDirection.up.impactScales(scaleX: scaleX, scaleY: scaleY)
        let downScales = CombatantHitRecoilDirection.down.impactScales(scaleX: scaleX, scaleY: scaleY)
        #expect(upScales.x == scaleY)
        #expect(upScales.y == scaleX)
        #expect(downScales.x == scaleX)
        #expect(downScales.y == scaleY)

        #expect(TrinketMotion.Battle.partyRecoilDirection(isPartyMember: true) == .down)
        #expect(TrinketMotion.Battle.partyRecoilDirection(isPartyMember: false) == .up)
    }
}
