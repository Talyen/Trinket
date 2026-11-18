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
            confirmStarter(role)
        }
    }

    private func confirmStarter(_ role: String) {
        let confirm = app.buttons["Confirm Starter \(role)"]
        confirm.tap()
        if !confirm.waitForNonExistence(timeout: 3) {
            confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "Starter confirmation did not advance")
        }
    }

    private func pressFeatureShots(knight: Bool) {
        // Each neighboring card is partially visible to the right. Tapping that
        // sliver lets the game's own carousel center the next choice.
        let heroes = knight ? ["knight"] : ["knight", "rogue", "wizard"]
        let companions = knight ? ["bear", "frost_whelp", "library_owl"] : ["bear", "frost_whelp"]
        for (role, choices) in [("Hero", heroes), ("Companion", companions)] {
            for choice in choices {
                let option = element("Starter \(role) Option \(choice)")
                XCTAssertTrue(option.waitForExistence(timeout: 10))
                let visible = option.frame.intersection(app.frame)
                XCTAssertFalse(visible.isEmpty)
                keep("select-\(choice)", settle: 1.25) {
                    app.coordinate(withNormalizedOffset: .zero).withOffset(
                        CGVector(dx: visible.midX, dy: visible.midY),
                    ).tap()
                }
                let expected = choice.replacingOccurrences(of: "_", with: " ").capitalized
                let name = element("Selected Starter Name").label.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                XCTAssertEqual(name, expected)
            }
            confirmStarter(role)
        }
        tab("Collection")
        let hero = knight ? "Knight" : "Wizard"
        let ability = knight ? "shield-bash" : "ray-of-frost"
        tap("\(hero) collection card", scroll: true)
        tap("Basic ability slot", scroll: true)
        let candidate = element("Loadout Ability Candidate \(ability)")
        ready(candidate, scroll: true)
        keep(ability, settle: 3.8) { candidate.tap() }
        XCTAssertTrue(element("Loadout Ability Detail \(ability)").exists)

        if knight {
            app.launchArguments += ["-selectedTab", "play"]
            app.launch()
            tab("Play")
            tap("Explore Mode Card")
            tap("Spires Mode Card", scroll: true)
            let choir = element("Spire aureateChoir Row")
            ready(choir, scroll: true)
            keep("aureate-choir", settle: 2.4) { choir.tap() }
            XCTAssertTrue(element("Spire aureateChoir Title").waitForExistence(timeout: 10))
        } else {
            recordExploredFloor()
        }
    }

    private func recordExploredFloor() {
        app.launchArguments = ["-store-name", "press-labyrinth-\(UUID().uuidString)", "-reset-state",
                               "-disable-cloud-sync", "-seed-test-progress", "-disable-audio", "-selectedTab", "play",
                               "-performance-strong-party", "-battle-tick-interval", "0.02", "-AppleLanguages", "(en)"]
        app.launch()
        tap("Explore Mode Card")
        tap("Labyrinth Mode Card", scroll: true)
        if element("Labyrinth Enter").exists {
            tap("Labyrinth Enter")
        }
        XCTAssertTrue(element("Labyrinth Map").waitForExistence(timeout: 10))
        tap("Labyrinth Floor 1 Entry Node")
        let enter = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Labyrinth Inspector Action ")).firstMatch
        ready(enter)
        enter.tap()
        tap("Auto Battle Toggle")
        XCTAssertTrue(element("Victory").waitForExistence(timeout: 90))
        tap("Continue Button", scroll: true)
        XCTAssertTrue(element("Labyrinth Map").waitForExistence(timeout: 12))
        let nextRoom = app.descendants(matching: .any).matching(NSPredicate(
            format: "(identifier BEGINSWITH %@ OR identifier == %@) AND NOT label CONTAINS[c] %@ AND NOT label CONTAINS[c] %@",
            "Labyrinth Node labyrinth-", "Labyrinth Floor 1 Locked Node", "cleared", "locked",
        )).allElementsBoundByIndex.first { $0.isHittable }
        guard let nextRoom else {
            XCTFail("No visible reachable room after the first victory")
            return
        }
        keep("labyrinth-node", settle: 3) {
            Thread.sleep(forTimeInterval: 2)
            nextRoom.tap()
            XCTAssertTrue(element("Labyrinth Node Inspector").waitForExistence(timeout: 10))
        }
    }

    private func recordContract() {
        tap("Explore Mode Card")
        keep("board", settle: 1.2) { tap("Contracts Mode Card", scroll: true) }
        let fight = element("Contract Fight easy")
        ready(fight, scroll: true)
        keep("contract", settle: 3) {
            Thread.sleep(forTimeInterval: 2)
            fight.tap()
            tap("Auto Battle Toggle")
            XCTAssertTrue(element("Victory").waitForExistence(timeout: 90))
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
    }

    private func boss() {
        tap("Campaign Mode Card")
        // Resolve the required merchant encounter before the boss stage unlocks.
        tap("Stage 1-9 Action", scroll: true)
        tap("Shop Leave Button", scroll: true)
        let encounter = element("Stage 1-10 Action")
        ready(encounter, scroll: true)
        keep("boss-reveal", settle: 1.4) { encounter.tap() }
        let boss = element("The Blight Treant card")
        XCTAssertTrue(boss.waitForExistence(timeout: 15))
        playCards(prefix: "boss-play")
        let victory = element("Victory")
        let defeat = element("Defeat")
        let auto = element("Auto Battle Toggle")
        if !victory.exists, !defeat.exists, auto.exists {
            keep("boss-resolution", settle: 2.0) {
                auto.tap()
                for _ in 0 ..< 40 {
                    if victory.exists || defeat.exists {
                        break
                    }
                    Thread.sleep(forTimeInterval: 1)
                }
            }
        }
    }

    private func playCards(prefix: String) {
        let cards = matchingButton("identifier BEGINSWITH %@", "Battle Hand Card ")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 12))
        for n in 1 ... 3 {
            guard let playable = cards.allElementsBoundByIndex.last(where: { $0.isEnabled && $0.isHittable }) else {
                XCTAssertGreaterThan(n, 2, "Need two distinct combat actions")
                break
            }
            let card = String(playable.identifier.dropFirst("Battle Hand Card ".count))
            keep("\(prefix)-\(n)", settle: 0.75, card: card) { playable.tap() }
        }
    }

    private func recordBossShowcase(lyrics: Bool) {
        let battles = [
            ("serpentHollow", "The Blight Treant", "Ranger", "Wolf"),
            ("ironVein", "The Iron Bear", "Rogue", "Panther"),
            ("cinderSpire", "The Forge Golem", "Wizard", "Frost Whelp"),
            ("rimeVault", "The Frostwarden", "Alchemist", "Phoenix"),
            ("sanguineCourt", "The Blood Countess", "Warlock", "Risen Skeleton"),
            ("aureateChoir", "The Seraph", "Knight", "Library Owl"),
            ("resonanceHall", "The Stone Titan", "Druid", "Shield Scarab"),
        ]
        let filter = ProcessInfo.processInfo.environment["TRINKET_SPIRES"]?.split(separator: ",").map(String.init)
        let selected = battles.filter { filter?.contains($0.0) ?? true }
        XCTAssertFalse(selected.isEmpty, "Select at least one available Spire.")
        if let filter {
            XCTAssertEqual(Set(selected.map(\.0)), Set(filter), "Unknown Spire in capture filter.")
        }
        for (spire, boss, hero, companion) in selected {
            let heroID = hero.lowercased().replacingOccurrences(of: " ", with: "_")
            let companionID = companion.lowercased().replacingOccurrences(of: " ", with: "_")
            app.launchArguments = ["-development-unlocked", "-AppleLanguages", "(en)",
                                   "-boss-capture", spire, heroID, companionID,
                                   lyrics ? "-boss-lyric-capture" : "-disable-audio"]
            if lyrics {
                keep("boss-play-\(spire)", settle: 18) {
                    openBoss(spire: spire, combatants: [boss, hero, companion])
                }
            } else {
                openBoss(spire: spire, combatants: [boss, hero, companion])
                keep("\(spire)-ready", settle: 1.0) {}
                playCards(prefix: "boss-play-\(spire)")
                let auto = element("Auto Battle Toggle")
                if auto.exists, auto.isHittable {
                    keep("\(spire)-exchange", settle: 6.0) { auto.tap() }
                }
            }
        }
    }

    private func openBoss(spire: String, combatants: [String]) {
        app.launch()
        for name in combatants {
            XCTAssertTrue(element("\(name) card").waitForExistence(timeout: 18), "Expected \(name) on \(spire) floor 10")
        }
        print("TRINKET_BOSS_VISIBLE \(spire) \(ProcessInfo.processInfo.systemUptime)")
    }

    private func startRecorder(take: String, audio: Bool) {
        let recorder = XCUIApplication(bundleIdentifier: "com.ryanmcintire.Trinket.TrailerRecorder")
        recorder.launchArguments = ["-take", take]
        if audio {
            recorder.launchArguments += ["-captureAudio", "YES"]
        }
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
    }

    func testRecordTrinket() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchEnvironment["XCTestConfigurationFilePath"] = "trailer-fixture"
        let showcase = ProcessInfo.processInfo.environment["TRINKET_SHOWCASE"] == "1"
        let lyrics = ProcessInfo.processInfo.environment["TRINKET_LYRIC_CAPTURE"] == "1"
        addTeardownBlock { self.app.terminate() }
        let contract = ProcessInfo.processInfo.environment["TRINKET_CONTRACT_CAPTURE"] == "1"
        if contract {
            app.launchArguments = ["-store-name", "press-contract-\(UUID().uuidString)", "-reset-state",
                                   "-disable-cloud-sync", "-seed-test-progress", "-disable-audio", "-selectedTab", "play",
                                   "-performance-strong-party", "-battle-tick-interval", "0.02", "-AppleLanguages", "(en)"]
            app.launch()
        } else if !showcase {
            app.launchArguments = ["-store-name", "launch-trailer-\(UUID().uuidString)",
                                   "-disable-audio", "-AppleLanguages", "(en)"]
            app.launch()
            XCTAssertTrue(element("Confirm Starter Hero").waitForExistence(timeout: 30))
        }
        if let take = ProcessInfo.processInfo.environment["TRINKET_TAKE"] {
            startRecorder(take: take, audio: lyrics)
            if !showcase {
                app.activate()
            }
        }
        print("TRINKET_CAPTURE_READY \(ProcessInfo.processInfo.systemUptime)")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 4)
        if contract {
            recordContract()
        } else if showcase {
            recordBossShowcase(lyrics: lyrics)
        } else if let party = ProcessInfo.processInfo.environment["TRINKET_PRESS_PICKUPS"] {
            pressFeatureShots(knight: party == "knight")
        } else {
            starters()
            buildShots()
            boss()
        }
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
