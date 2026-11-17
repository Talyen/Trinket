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
                if control.exists, control.isHittable { return }
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
            if element(id).waitForNonExistence(timeout: 1) { return }
        }
        XCTAssertFalse(element(id).exists, "Sheet still open: \(id)")
    }

    private func tab(_ name: String) {
        let native = app.tabBars.buttons[name]
        let button = native.exists ? native : app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", name, "BackButton")
        ).firstMatch
        ready(button)
        button.tap()
    }

    private func keep(_ name: String, seconds: Double, action: () -> Void = {}) {
        Thread.sleep(forTimeInterval: 1.25)
        let start = ProcessInfo.processInfo.systemUptime
        print("TRINKET_SHOT \(name) \(start)")
        action()
        let end = start + seconds
        Thread.sleep(forTimeInterval: max(0, end - ProcessInfo.processInfo.systemUptime) + 1.5)
        shots.append(["id": name, "start": start, "end": end])
    }

    private func mode(_ name: String) {
        let card = element("\(name) Mode Card")
        ready(card, scroll: true)
        let screen = app.frame
        let safeTop = screen.height * 0.14
        let safeBottom = screen.height * 0.83
        for _ in 0 ..< 5 {
            let frame = card.frame
            if frame.minY >= safeTop, frame.maxY <= safeBottom { break }
            let offset = min(0.34, max(-0.34, (screen.midY - frame.midY) / screen.height))
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.52))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.52 + offset))
            from.press(forDuration: 0.08, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        XCTAssertTrue(card.frame.minY >= screen.height * 0.08 && card.frame.maxY <= screen.height * 0.91,
                      "Show the entire illustrated \(name) card before entering the mode")
        keep("\(name.lowercased())-art", seconds: 0.8)
        card.tap()
    }

    private func starters() {
        for (role, name) in [("Hero", "Ranger"), ("Companion", "Wolf")] {
            let selected = app.staticTexts["Selected Starter Name"]
            XCTAssertTrue(selected.waitForExistence(timeout: 30))
            if selected.label != name { tap("Starter \(role) Option \(name.lowercased())") }
            XCTAssertEqual(selected.label, name)
            keep(role.lowercased(), seconds: 1.5)
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
        tap("Loadout Ability Candidate fire-arrow", scroll: true)
        let detail = "Loadout Ability Detail fire-arrow"
        XCTAssertTrue(element(detail).waitForExistence(timeout: 12))
        keep("fire-arrow", seconds: 1.5)
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
        offer.tap()
        XCTAssertTrue(element("Shop Detail Buy Button").waitForExistence(timeout: 12))
        keep("item", seconds: 1.5)
        dismiss("Shop Detail Buy Button")
        tap("Shop Leave Button", scroll: true)
        tab("Homestead")
        XCTAssertTrue(element("Homestead Resource Wallet").waitForExistence(timeout: 12))
        keep("homestead", seconds: 1.5)
        tab("Play")
    }

    private func modeShots() {
        if element("Chapter 1 Header").exists { back() }
        mode("Campaign")
        XCTAssertTrue(element("Chapter 1 Header").waitForExistence(timeout: 12))
        keep("forest", seconds: 1.2)
        back()
        tap("Explore Mode Card")
        mode("Spires")
        tap("Spire cinderSpire Row", scroll: true)
        XCTAssertTrue(element("Spire cinderSpire Climb").waitForExistence(timeout: 12))
        keep("spire-climb", seconds: 1.2)
        back()
        back()
        mode("Labyrinth")
        if element("Labyrinth Enter").exists { tap("Labyrinth Enter") }
        XCTAssertTrue(element("Labyrinth Map").waitForExistence(timeout: 12))
        keep("labyrinth-map", seconds: 1.2)
        back()
        mode("Contracts")
        XCTAssertTrue(element("Contracts Board").waitForExistence(timeout: 12))
        keep("contracts-board", seconds: 1.2)
        back()
        mode("Voyage")
        let art = matchingButton("identifier BEGINSWITH %@", "Voyage Artwork ").firstMatch
        ready(art, scroll: true)
        art.tap()
        XCTAssertTrue(element("Voyage Destination Sheet").waitForExistence(timeout: 12))
        keep("voyage-route", seconds: 1.2)
        dismiss("Voyage Destination Sheet")
        back()
        back()
    }

    private func boss() {
        tap("Campaign Mode Card")
        tap("Stage 1-10 Action", scroll: true)
        let boss = element("The Blight Treant card")
        XCTAssertTrue(boss.waitForExistence(timeout: 15))
        let cards = matchingButton("identifier BEGINSWITH %@", "Battle Hand Card ")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 12))
        keep("boss-reveal", seconds: 1.5)
        for n in 1 ... 2 {
            let playable = cards.allElementsBoundByIndex.last { $0.isEnabled && $0.isHittable }
            XCTAssertNotNil(playable)
            keep("boss-play-\(n)", seconds: 3.75) { playable?.tap() }
        }
        XCTAssertTrue(boss.exists || element("Victory").exists)
        keep("closing", seconds: 2)
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
                    format: "label ==[c] %@ OR identifier ==[c] %@", "Share Entire Screen", "Share Entire Screen"
                )).firstMatch
                if share.waitForExistence(timeout: 3), share.isHittable {
                    share.tap()
                    break
                }
            }
            XCTAssertTrue(recorder.buttons["Finish take"].waitForExistence(timeout: 90), "Approve the screen on the iPhone. Recorder: \(recorder.staticTexts.allElementsBoundByIndex.map(\.label))")
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
