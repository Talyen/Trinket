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
        #expect(TrinketMotion.Battle.ultimateChipStagger > 0)
        #expect(TrinketMotion.Battle.ultimateChipStagger < 0.2)
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

    @Test func chipMotionRecipesStayWithinSemanticContracts() {
        let critical = TrinketMotion.Battle.chip(for: .critical)
        let normal = TrinketMotion.Battle.chip(for: .directDamage)
        let deathsDoor = TrinketMotion.Battle.chip(for: .deathsDoor)

        #expect(critical.lifetime > normal.lifetime)
        #expect(critical.textStyle == .largeTitle)
        #expect(critical.fontWeight == .heavy)
        #expect(normal.textStyle == .title)
        #expect(normal.fontWeight == .bold)
        #expect(!critical.showsSecondaryCaption)

        // Same choreography family: emphasis is a louder version of normal.
        #expect(critical.initialScale > normal.initialScale)
        #expect(abs(critical.offsetY.last?.value ?? 0) > abs(normal.offsetY.last?.value ?? 0))
        #expect(critical.floatAngleRange.upperBound <= 8)
        #expect(normal.floatAngleRange.upperBound <= 10)
        #expect(critical.horizontalJitter.upperBound <= 4)
        #expect(normal.horizontalJitter.upperBound <= 5)

        // Emphasis classes share one motion profile; normal classes share another.
        #expect(deathsDoor.lifetime == critical.lifetime)
        #expect(deathsDoor.scale == critical.scale)
        #expect(TrinketMotion.Battle.chip(for: .heal).scale == normal.scale)
        #expect(TrinketMotion.Battle.chip(for: .dodge).offsetX.isEmpty)
        #expect(TrinketMotion.Battle.maxChipLifetime > TrinketMotion.Battle.chipDisplayDuration)
        #expect(critical.stackSpacing == CombatFeedbackLayout.presentationLaneSpacing)
        #expect(normal.stackSpacing == CombatFeedbackLayout.presentationLaneSpacing)
    }

    @Test func chipMotionRecipesCoverEveryFeedbackClassAndLaneLayout() {
        for feedbackClass in CombatFeedbackClass.allCases {
            let recipe = TrinketMotion.Battle.chip(for: feedbackClass)
            #expect(recipe.lifetime > 0)
            #expect(recipe.lifetime <= 1.2)
            #expect(recipe.lifetime >= 0.85)
            #expect(recipe.scale.count == 3)
            #expect(recipe.opacity.count == 3)
            #expect(recipe.offsetY.count == 3)
            #expect(recipe.feedbackClass == feedbackClass)
            #expect(recipe.initialOpacity == 0)
            #expect(recipe.initialScale > 1)
            #expect(recipe.scale.last?.value == 1.0)
            #expect(recipe.initialOffsetY > 0)
            #expect((recipe.offsetY.last?.value ?? 0) <= -40)
            #expect(recipe.rotation.isEmpty)
            var previousScale = recipe.initialScale
            for keyframe in recipe.scale {
                #expect(keyframe.value <= previousScale)
                previousScale = keyframe.value
            }
            switch feedbackClass {
            case .critical, .deathsDoor:
                #expect(recipe.textStyle == .largeTitle)
                #expect(recipe.fontWeight == .heavy)
                #expect(recipe.chrome == .emphasis)
            case .directDamage, .heal, .dot, .block, .dodge, .control, .buff, .resource:
                #expect(recipe.textStyle == .title)
                #expect(recipe.fontWeight == .bold)
                #expect(recipe.chrome == .standard)
            }
        }
    }

    @Test func combatFeedbackLaneLayoutPacksDenseGroupsTowardCenter() {
        #expect(CombatFeedbackLayout.presentationOffset(index: 0) == 0)
        #expect(CombatFeedbackLayout.presentationOffset(index: 0, count: 3) == 0)
        #expect(
            CombatFeedbackLayout.presentationOffset(index: 1, count: 3)
                == -CombatFeedbackLayout.presentationLaneSpacing
        )
        #expect(
            CombatFeedbackLayout.presentationOffset(index: 2, count: 3)
                == CombatFeedbackLayout.presentationLaneSpacing
        )
        #expect(CombatFeedbackLayout.presentationLaneSpacing >= 52)
        #expect(CombatFeedbackLayout.presentationLaneSpacingFloor == 34)
        #expect(CombatFeedbackLayout.presentationSpacing(forCount: 1)
            == CombatFeedbackLayout.presentationLaneSpacing)
        #expect(CombatFeedbackLayout.presentationSpacing(forCount: 3)
            == CombatFeedbackLayout.presentationLaneSpacing)
        #expect(
            CombatFeedbackLayout.presentationSpacing(forCount: 6)
                == CombatFeedbackLayout.presentationLaneSpacingFloor
        )
        #expect(CombatFeedbackLayout.floatTravelScale(forCount: 1) == 1)
        #expect(CombatFeedbackLayout.floatTravelScale(forCount: 3) == 1)
        #expect(CombatFeedbackLayout.floatTravelScale(forCount: 4) < 1)
        #expect(
            CombatFeedbackLayout.floatTravelScale(forCount: 6)
                == CombatFeedbackLayout.floatTravelScale(forCount: 9)
        )
        let denseSpacing = CombatFeedbackLayout.presentationSpacing(forCount: 6)
        #expect(
            CombatFeedbackLayout.presentationOffset(index: 1, count: 6, spacing: denseSpacing)
                == -denseSpacing
        )
        #expect(
            CombatFeedbackLayout.presentationOffset(index: 2, count: 6, spacing: denseSpacing)
                == denseSpacing
        )
        #expect(CombatFeedbackLayout.presentationHorizontalFan(index: 0) == 0)
        #expect(CombatFeedbackLayout.presentationHorizontalFan(index: 1) == -20)
        #expect(CombatFeedbackLayout.presentationHorizontalFan(index: 2) == 20)
        #expect(CombatFeedbackLayout.presentationHorizontalFan(index: 3) == -28)
        #expect(CombatFeedbackLayout.presentationHorizontalFan(index: 4) == 28)
        #expect(
            abs(CombatFeedbackLayout.presentationHorizontalFan(index: 1, count: 6))
                < abs(CombatFeedbackLayout.presentationHorizontalFan(index: 1, count: 1))
        )
        #expect(
            abs(CombatFeedbackLayout.presentationHorizontalFan(index: 1))
                >= CombatFeedbackLayout.presentationFanAmplitude
        )
    }

    @Test func combatFeedbackFloatAnglesAreStableAndProduceBothDirections() {
        let range: ClosedRange<CGFloat> = -10 ... 10
        let first = CombatFeedbackLayout.floatAngle(seed: 17, range: range)
        let repeated = CombatFeedbackLayout.floatAngle(seed: 17, range: range)
        let other = CombatFeedbackLayout.floatAngle(seed: 18, range: range)
        let sampledAngles = (0 ..< 32).map {
            CombatFeedbackLayout.floatAngle(seed: $0, range: range)
        }

        #expect(first == repeated)
        #expect(first >= range.lowerBound)
        #expect(first <= range.upperBound)
        #expect(sampledAngles.contains { $0 < 0 })
        #expect(sampledAngles.contains { $0 > 0 })
        #expect(CombatFeedbackLayout.horizontalDrift(angleDegrees: 20, verticalTravel: 60) > 0)
        #expect(CombatFeedbackLayout.horizontalDrift(angleDegrees: -20, verticalTravel: 60) < 0)
        #expect(first != other)

        let offsetA = CombatFeedbackLayout.horizontalOffset(seed: 42, jitter: -5 ... 5)
        let offsetB = CombatFeedbackLayout.horizontalOffset(seed: 42, jitter: -5 ... 5)
        let offsetC = CombatFeedbackLayout.horizontalOffset(seed: 43, jitter: -5 ... 5)
        #expect(offsetA == offsetB)
        #expect(offsetA != offsetC)
        #expect((-5 ... 5).contains(offsetA))
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
