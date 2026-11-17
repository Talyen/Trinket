import XCTest

final class PhysicalTour: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.ryanmcintire.Trinket")
    private var shots: [[String: Any]] = []

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func matchingButton(_ format: String, _ value: String) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: format, value))
    }

    private func ready(_ control: XCUIElement, scroll: Bool = false) {
        if scroll {
            for _ in 0 ..< 8 {
                if control.exists, control.isHittable {
                    return
                }
                app.swipeUp()
            }
        }
        XCTAssertTrue(control.waitForExistence(timeout: 12), "Missing \(control)")
        XCTAssertTrue(control.isHittable, "Offscreen \(control)")
    }

    private func tap(_ id: String, scroll: Bool = false) {
        let control = element(id)
        ready(control, scroll: scroll)
        control.tap()
    }

    private func back() {
        let control = app.buttons.matching(identifier: "BackButton").allElementsBoundByIndex.last { $0.isHittable }
        XCTAssertNotNil(control, "Missing foreground Back button")
        control?.tap()
    }

    private func dismiss(_ id: String) {
        for _ in 0 ..< 2 where element(id).exists {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
            start.press(forDuration: 0.12, thenDragTo: end)
            if element(id).waitForNonExistence(timeout: 1) {
                return
            }
        }
        XCTAssertFalse(element(id).exists, "Sheet still open: \(id)")
    }

    private func tab(_ name: String) {
        let native = app.tabBars.buttons[name]
        let button = native.exists ? native : app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", name, "BackButton"),
        ).firstMatch
        ready(button)
        button.tap()
    }

    /// Capture handles around the real gesture. The editor chooses the exact
    /// in/out frames after inspecting the take, including XCTest input latency.
    private func keep(_ name: String, settle: Double = 0.8, card: String? = nil, action: () -> Void) {
        let start = ProcessInfo.processInfo.systemUptime
        print("TRINKET_SHOT \(name) \(start)")
        action()
        Thread.sleep(forTimeInterval: settle)
        var shot: [String: Any] = ["id": name, "start": start, "end": ProcessInfo.processInfo.systemUptime]
        shot["card"] = card
        shots.append(shot)
    }

    private func drag(fromX: CGFloat, fromY: CGFloat, toX: CGFloat, toY: CGFloat) {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: fromY))
        let target = app.coordinate(withNormalizedOffset: CGVector(dx: toX, dy: toY))
        origin.press(
            forDuration: 0.06,
            thenDragTo: target,
            withVelocity: XCUIGestureVelocity(rawValue: 440),
            thenHoldForDuration: 0.05,
        )
    }

    private func mode(_ name: String) {
        let card = element("\(name) Mode Card")
        ready(card, scroll: true)
        let screen = app.frame
        let safeTop = screen.height * 0.14
        let safeBottom = screen.height * 0.83
        for _ in 0 ..< 5 {
            let frame = card.frame
            if frame.minY >= safeTop, frame.maxY <= safeBottom {
                break
            }
            let offset = min(0.34, max(-0.34, (screen.midY - frame.midY) / screen.height))
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.52))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.52 + offset))
            from.press(forDuration: 0.08, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        XCTAssertTrue(
            card.frame.minY >= screen.height * 0.08 && card.frame.maxY <= screen.height * 0.91,
            "Show the entire illustrated \(name) card before entering the mode",
        )
        keep("\(name.lowercased())-art") { card.tap() }
    }

    private func starters() {
        for (role, name) in [("Hero", "Ranger"), ("Companion", "Wolf")] {
            let selected = app.staticTexts["Selected Starter Name"]
            XCTAssertTrue(selected.waitForExistence(timeout: 30))
            drag(fromX: 0.79, fromY: 0.44, toX: 0.16, toY: 0.44)
            keep(role.lowercased()) {
                drag(fromX: 0.16, fromY: 0.44, toX: 0.85, toY: 0.44)
                if selected.label != name {
                    tap("Starter \(role) Option \(name.lowercased())")
                }
            }
            XCTAssertEqual(selected.label, name)
            let confirm = app.buttons["Confirm Starter \(role)"]
            confirm.tap()
            if !confirm.waitForNonExistence(timeout: 3) {
                confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "Starter confirmation did not advance")
            }
        }
    }

    private func buildShots() {
        tab("Collection")
        tap("Ranger collection card", scroll: true)
        tap("Basic ability slot", scroll: true)
        let arrow = element("Loadout Ability Candidate fire-arrow")
        ready(arrow, scroll: true)
        keep("fire-arrow") { arrow.tap() }
        let detail = "Loadout Ability Detail fire-arrow"
        XCTAssertTrue(element(detail).waitForExistence(timeout: 12))
        // A seeded journey before party confirmation prevents build 13 from finishing onboarding.
        // Keep the same named career and let the recorder run through its checkpoint reload.
        app.launchArguments += ["-starting-gold", "200", "-completed-stages",
                                (1 ... 8).map { "chapter-1-stage-\($0)" }.joined(separator: ",")]
        app.launch()
        tab("Play")
        tap("Campaign Mode Card")
        tap("Stage 1-9 Action", scroll: true)
        let offer = matchingButton("identifier ENDSWITH %@", " shop offer").firstMatch
        ready(offer, scroll: true)
        keep("item") { offer.tap() }
        XCTAssertTrue(element("Shop Detail Buy Button").waitForExistence(timeout: 12))
        dismiss("Shop Detail Buy Button")
        tap("Shop Leave Button", scroll: true)
        tab("Homestead")
        XCTAssertTrue(element("Homestead Resource Wallet").waitForExistence(timeout: 12))
        let farming = element("Homestead Farming Category")
        ready(farming, scroll: true)
        keep("homestead") { farming.tap() }
        tab("Play")
    }

    private func modeShots() {
        if element("Chapter 1 Header").exists {
            back()
        }
        mode("Campaign")
        XCTAssertTrue(element("Chapter 1 Header").waitForExistence(timeout: 12))
        keep("forest") { drag(fromX: 0.52, fromY: 0.72, toX: 0.52, toY: 0.40) }
        back()
        tap("Explore Mode Card")
        mode("Spires")
        let spire = element("Spire cinderSpire Row")
        ready(spire, scroll: true)
        keep("spire-climb") { spire.tap() }
        XCTAssertTrue(element("Spire cinderSpire Climb").waitForExistence(timeout: 12))
        back()
        back()
        mode("Labyrinth")
        keep("labyrinth-map") {
            if element("Labyrinth Enter").exists {
                tap("Labyrinth Enter")
            } else {
                drag(fromX: 0.60, fromY: 0.57, toX: 0.35, toY: 0.42)
            }
        }
        XCTAssertTrue(element("Labyrinth Map").waitForExistence(timeout: 12))
        back()
        mode("Contracts")
        XCTAssertTrue(element("Contracts Board").waitForExistence(timeout: 12))
        keep("contracts-board") { drag(fromX: 0.50, fromY: 0.73, toX: 0.50, toY: 0.36) }
        back()
        mode("Voyage")
        let art = matchingButton("identifier BEGINSWITH %@", "Voyage Artwork ").firstMatch
        ready(art, scroll: true)
        keep("voyage-route") { art.tap() }
        XCTAssertTrue(element("Voyage Destination Sheet").waitForExistence(timeout: 12))
        dismiss("Voyage Destination Sheet")
        back()
        back()
    }

    private func boss() {
        tap("Campaign Mode Card")
        let encounter = element("Stage 1-10 Action")
        ready(encounter, scroll: true)
        keep("boss-reveal", settle: 1.4) { encounter.tap() }
        let boss = element("The Blight Treant card")
        XCTAssertTrue(boss.waitForExistence(timeout: 15))
        let cards = matchingButton("identifier BEGINSWITH %@", "Battle Hand Card ")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 12))
        for n in 1 ... 3 {
            guard let playable = cards.allElementsBoundByIndex.last(where: { $0.isEnabled && $0.isHittable }) else {
                XCTAssertGreaterThan(n, 2, "Need two distinct combat actions")
                break
            }
            let card = String(playable.identifier.dropFirst("Battle Hand Card ".count))
            keep("boss-play-\(n)", settle: 2.0, card: card) {
                let origin = playable.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                origin.press(
                    forDuration: 0.05,
                    thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -240)),
                    withVelocity: XCUIGestureVelocity(rawValue: 500),
                    thenHoldForDuration: 0.05,
                )
            }
        }
        XCTAssertTrue(boss.exists || element("Victory").exists)
    }

    func testRecordTrinket() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchEnvironment["XCTestConfigurationFilePath"] = "trailer-fixture"
        app.launchArguments = ["-store-name", "launch-trailer-\(UUID().uuidString)",
                               "-disable-audio", "-AppleLanguages", "(en)"]
        app.launch()
        addTeardownBlock { self.app.terminate() }
        XCTAssertTrue(element("Confirm Starter Hero").waitForExistence(timeout: 30))
        let recorder = XCUIApplication(bundleIdentifier: "com.ryanmcintire.Trinket.TrailerRecorder")
        if let take = ProcessInfo.processInfo.environment["TRINKET_TAKE"] {
            recorder.launchArguments = ["-take", take]
            recorder.launch()
            addTeardownBlock { recorder.terminate() }
            recorder.buttons["Choose screen"].tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for host in [springboard, recorder] {
                let share = host.descendants(matching: .any).matching(NSPredicate(
                    format: "label ==[c] %@ OR identifier ==[c] %@", "Share Entire Screen", "Share Entire Screen",
                )).firstMatch
                if share.waitForExistence(timeout: 3), share.isHittable {
                    share.tap()
                    break
                }
            }
            XCTAssertTrue(
                recorder.buttons["Finish take"].waitForExistence(timeout: 90),
                "Approve the screen on the iPhone. Recorder: \(recorder.staticTexts.allElementsBoundByIndex.map(\.label))",
            )
            addTeardownBlock {
                recorder.activate()
                if recorder.buttons["Finish take"].exists {
                    recorder.buttons["Finish take"].tap()
                }
                XCTAssertTrue(recorder.staticTexts["Saved"].waitForExistence(timeout: 20))
                recorder.terminate()
            }
            app.activate()
        }
        print("TRINKET_CAPTURE_READY \(ProcessInfo.processInfo.systemUptime)")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 4)
        starters()
        buildShots()
        modeShots()
        boss()
        print("TRINKET_CAPTURE_DONE \(ProcessInfo.processInfo.systemUptime)")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 1)
        let data = try JSONSerialization.data(withJSONObject: shots)
        let markers = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        markers.name = "Trinket Shot Times"
        markers.lifetime = .keepAlways
        add(markers)
    }
}
