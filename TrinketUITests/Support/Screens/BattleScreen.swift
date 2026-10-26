import TrinketFeatureSupport
import XCTest

struct BattleScreen {
    let app: XCUIApplication

    var hand: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.Battle.hand)
            .firstMatch
    }

    var handCards: XCUIElementQuery {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Battle.handCardPrefix),
        )
    }

    var frontmostHandCard: XCUIElement {
        // The fan stacks later cards above earlier ones; their centers remain exposed.
        handCards.element(boundBy: max(0, handCards.count - 1))
    }

    var actionsMenu: XCUIElement {
        app.buttons[AccessibilityID.Battle.actionsMenu]
    }

    var autoBattleToggle: XCUIElement {
        app.buttons[AccessibilityID.Battle.autoBattleToggle]
    }

    func assertActive(
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        XCTAssertTrue(
            hand.trinketWaitForExistence(timeout: timeout),
            "Battle hand chrome not found",
            file: file,
            line: line,
        )
    }

    func openCombatantCard(named name: String) {
        app.buttons[AccessibilityID.CombatantDetail.battleCard(name: name)].trinketTapWhenReady()
    }

    func openActions() {
        let menu = actionsMenu
        if #available(iOS 26.0, *) {
            menu.trinketTapWhenReady()
        } else if menu.trinketWaitForExistence(timeout: TrinketUITestCase.defaultTimeout), menu.isEnabled {
            if menu.isHittable {
                menu.trinketTapWhenReady()
                return
            }
            // iOS 18 exposes this visible native Menu as unhittable. Tap its validated
            // bounds and require the real menu destination before continuing the journey.
            let frame = menu.frame
            guard frame.origin.x.isFinite, frame.origin.y.isFinite,
                  frame.width.isFinite, frame.height.isFinite,
                  frame.width > 0, frame.height > 0, app.frame.contains(frame)
            else {
                XCTFail("Battle actions must have visible, finite bounds: \(frame)")
                return
            }
            menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons[AccessibilityID.Battle.combatLog].trinketWaitForExistence(
                timeout: TrinketUITestCase.defaultTimeout,
            ), "The visible Battle menu must open")
        } else {
            XCTFail("Battle actions must exist and be enabled")
        }
    }
}
