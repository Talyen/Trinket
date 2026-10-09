import TrinketFeatureSupport
import XCTest

final class RepeatedPlayUITests: TrinketUITestCase {
    func testTwentyAudioEnabledContractsKeepOneUsableCareer() throws {
        launchApp(arguments: TestLaunchArg.productionTiming(audio: true)
            + ["-performance-strong-party", "-coverage-diagnostics"])
        play.openExplore()
        tapButton(AccessibilityID.Play.contractsModeCard)
        var lastAudioPlays = 0
        var outcomes: [String] = []
        for cycle in 1 ... 20 {
            assertExists(AccessibilityID.Play.contractsBoard)
            let before = try coverageReport()
            let contracts = try XCTUnwrap(before["contracts"] as? [String: Any])
            let offers = try XCTUnwrap(contracts["offers"] as? [[String: Any]])
            let offerID = try XCTUnwrap(offers.first { $0["difficulty"] as? String == "easy" }?["id"] as? String)
            let previousClaims = Set(contracts["completedOfferIDs"] as? [String] ?? [])
            tapButton(AccessibilityID.Play.contractFight("easy"))
            battle.assertActive()
            tapWhenReady(battle.autoBattleToggle)
            waitUntil("Contract must reach a usable result", timeout: 45) {
                self.any(AccessibilityID.Battle.victory).exists || self.any(AccessibilityID.Battle.defeat).exists
            }
            let won = any(AccessibilityID.Battle.victory).exists
            outcomes.append(won ? "victory" : "defeat")
            let leave = won ? AccessibilityID.Battle.continueButton : AccessibilityID.Battle.defeatLeaveButton
            assertExistsAfterScroll(leave, requireHittable: true)
            tapButton(leave)
            dismissEarnedTalentChoicesIfPresented()
            assertExists(AccessibilityID.Play.contractsBoard)
            waitForAudioProgress(after: lastAudioPlays)
            let report = try coverageReport()
            let currentContracts = try XCTUnwrap(report["contracts"] as? [String: Any])
            let claims = try Set(XCTUnwrap(currentContracts["completedOfferIDs"] as? [String]))
            XCTAssertEqual(
                claims,
                won ? previousClaims.union([offerID]) : previousClaims,
                "Cycle \(cycle) must commit exactly its displayed offer",
            )
            let plays = try XCTUnwrap(report["sfxPlays"] as? Int)
            XCTAssertGreaterThan(plays, lastAudioPlays, "Cycle \(cycle) did not schedule real audio")
            XCTAssertEqual(report["audioFailures"] as? Int, 0)
            XCTAssertEqual(report["duplicateMusicOwners"] as? Int, 0)
            lastAudioPlays = plays
            if cycle.isMultiple(of: 5) {
                try visitTabsAndCaptureDiagnostics(cycle: cycle)
            }
        }
        let final = try XCTAttachment(string: "Outcomes: \(outcomes)\nFinal state: \(coverageReport())")
        final.name = "complete-soak-outcomes-and-state"
        final.lifetime = .keepAlways
        add(final)
        retainScreenshot(named: "completed-twenty-contracts")
    }

    private func visitTabsAndCaptureDiagnostics(cycle: Int) throws {
        tabBar.selectCollection()
        collection.assertLoaded()
        tabBar.selectHomestead()
        homestead.assertLoaded()
        backgroundAndActivate()
        tabBar.selectPlay()
        assertExists(AccessibilityID.Play.contractsBoard)
        let data = try JSONSerialization.data(withJSONObject: coverageReport())
        let encoded = try XCTUnwrap(String(data: data, encoding: .utf8))
        let attachment = XCTAttachment(string: encoded)
        attachment.name = "cycle-\(cycle)-diagnostics"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
