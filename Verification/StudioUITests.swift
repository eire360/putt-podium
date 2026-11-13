import XCTest

@MainActor
final class StudioUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    private func launch(_ flags: String...) { app.launchArguments = ["--studio-reset"] + flags; app.launch() }
    private func reach(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let scroll = app.scrollViews.firstMatch
        let fixedIDs: Set<String> = ["nextHole", "previousHole", "finishRound", "shareCard", "showStandings", "startRound", "newRound", "roundOptions", "saveScore"]
        func visible() -> Bool {
            guard element.exists, element.isHittable else { return false }
            let scoring = ["score-", "increase-", "decrease-"].contains { element.identifier.hasPrefix($0) }
            if fixedIDs.contains(element.identifier) || !scoring { return true }
            let footers = ["nextHole", "finishRound", "shareCard"].map { app.buttons[$0].firstMatch }.filter { $0.exists && $0.isHittable }
            let bottom = footers.map { $0.frame.minY }.min() ?? app.frame.maxY
            return element.frame.height >= 40 && element.frame.maxY <= bottom && element.frame.minY >= 90
        }
        func step(up: Bool) {
            let surface = scroll.exists ? scroll : app!
            surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.58 : 0.34)).press(forDuration: 0.05, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.30 : 0.62)))
        }
        for _ in 0..<14 { if visible() { return }; step(up: true) }
        for _ in 0..<20 { if visible() { return }; step(up: false) }
        XCTAssertTrue(visible(), "Expected fully visible control: \(element)", file: file, line: line)
    }
    private func tap(_ id:String) {
        if (id == "reviewScores" || id == "editScores" || id == "newRound") && !app.buttons[id].firstMatch.exists {
            let options=app.buttons["roundOptions"].firstMatch
            if options.exists { options.tap() }
        }
        let e=app.buttons[id].firstMatch;reach(e);e.tap()
    }
    private func attach(_ name:String) { let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a) }
    private func closeSheet() {
        let e=app.buttons.matching(NSPredicate(format:"label == 'Done' OR label == 'Close' OR label == 'Cancel'")).firstMatch
        XCTAssertTrue(e.waitForExistence(timeout:8)); e.tap()
    }
    func testCreateRoundAndMissingScoresDoNotFinish() {
        launch();tap("startRound")
        XCTAssertTrue(app.buttons["increase-0"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["score-0"].label.contains("not recorded"))
        tap("reviewScores")
        // Optional scorecard inspection must never permit incomplete completion.
        let finish=app.buttons["confirmFinish"]
        reach(finish)
        XCTAssertFalse(finish.isEnabled)
        attach("B1-missing-score-review")
    }
    func testDirectEntryAndAdjustment() {
        launch();tap("startRound");tap("score-0")
        let input=app.textFields["scoreInput"];XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("7");tap("saveScore")
        tap("increase-0");tap("decrease-0")
        XCTAssertTrue(app.buttons["score-0"].label.contains("7"))
        tap("score-0");tap("clearScore")
        XCTAssertTrue(app.buttons["score-0"].label.contains("not recorded"))
        tap("score-0");closeSheet()
        XCTAssertTrue(app.buttons["score-0"].label.contains("not recorded"))
        attach("B1-score-entry")
    }
    func testCompletedRoundCanBeCorrectedAndRestored() {
        launch("--studio-fixture-complete");tap("editScores");tap("increase-0")
        // Alex18→19 and Blair27. Finished editing must recompute on the direct Finish path.
        tap("finishRound")
        XCTAssertTrue(app.buttons["shareCard"].waitForExistence(timeout:5))
        let text=app.staticTexts.matching(NSPredicate(format:"label CONTAINS '19' AND (label CONTAINS 'stroke' OR label CONTAINS 'STROKE')")).firstMatch
        XCTAssertTrue(text.exists)
        attach("B1-corrected-results")
        app.terminate();app.launchArguments=[];app.launch()
        XCTAssertTrue(app.buttons["shareCard"].waitForExistence(timeout:8));attach("B1-restored-results")
    }
    func testAllStylesAndNativeShareCanCancel() {
        launch("--studio-fixture-complete")
        for style in ["champion","roast","receipts"] { tap("flexStyle-\(style)") }
        tap("shareCard")
        let close=app.buttons.matching(NSPredicate(format:"label == 'Close' OR label == 'Cancel'")).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout:10));attach("B1-native-share");close.tap()
        XCTAssertTrue(app.buttons["shareCard"].waitForExistence(timeout:5));attach("B1-share-cancelled")
    }
    func testEightPlayerTieFixtureRenders() {
        launch("--studio-fixture-eight");attach("B1-eight-results-top")
        tap("showStandings")
        let a=app.descendants(matching:.any).matching(NSPredicate(format:"label CONTAINS %@ AND label CONTAINS %@","T1","Alex")).firstMatch
        let b=app.descendants(matching:.any).matching(NSPredicate(format:"label CONTAINS %@ AND label CONTAINS %@","T1","Blair")).firstMatch
        XCTAssertTrue(a.exists && b.exists);attach("B1-eight-tied-standings")
    }
    func testNormalNineHoleRoundAndNavigation() {
        launch();tap("startRound")
        for hole in 0..<9 {
            tap("increase-0");tap("increase-1")
            if hole == 0 { tap("nextHole");tap("previousHole");XCTAssertTrue(app.buttons["score-0"].label.contains("1")) }
            if hole < 8 { tap("nextHole") }
        }
        tap("finishRound")
        XCTAssertTrue(app.buttons["shareCard"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["confirmFinish"].exists,"Normal complete round must not require verification sheet")
        attach("B1-normal-round-complete")
    }
    func testEquivalentFixtureScreens() {
        launch();attach("B1-setup-top")
        launch("--studio-fixture-play2");attach("B1-play-two-top")
        tap("showStandings");attach("B1-live-standings");closeSheet()
        launch("--studio-fixture-play8");attach("B1-play-eight-top")
    }
    func testAccessibilityTextAndThreeDigitScore() {
        app.launchArguments = ["--studio-reset", "--studio-fixture-stress", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        attach("B1-AX-before-decrease")
        tap("decrease-0")
        attach("B1-AX-after-decrease")
        let actual = app.buttons["score-0"].label
        let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.name = "AX hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        XCTAssertTrue(actual.contains("998"), "Actual score label: \(actual)")
        attach("B1-accessibility-three-digit-score")
        tap("showStandings")
        XCTAssertTrue(app.navigationBars["Standings"].exists)
        closeSheet()
        XCTAssertTrue(app.buttons["nextHole"].exists)
    }
    func testOpeningArtworkKeepsTwoPlayerSetupOnscreen() {
        launch()
        let start = app.buttons["startRound"]
        XCTAssertTrue(start.waitForExistence(timeout: 8) && start.isHittable)
        for index in 0..<2 {
            let field = app.textFields["playerName-\(index)"]
            XCTAssertTrue(field.exists && field.isHittable)
            XCTAssertLessThanOrEqual(field.frame.maxY, start.frame.minY)
        }
        let holes = app.segmentedControls.firstMatch
        XCTAssertTrue(holes.exists && holes.isHittable)
        XCTAssertLessThanOrEqual(holes.frame.maxY, start.frame.minY)
        attach("B2-opening-small-iPhone")
        // No scroll helper is called before these assertions or this capture.
    }
    func testOpeningArtworkWithAccessibilityText() {
        app.launchArguments = ["--studio-reset", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["startRound"].waitForExistence(timeout: 8) && app.buttons["startRound"].isHittable)
        attach("B2-opening-accessibility-text")
    }
}
