import XCTest
@testable import NamespacesCore

final class CoreTests: XCTestCase {
    func testCommercialPolicyUsesApprovedOffer() {
        XCTAssertEqual(CommercialPolicy.trialLengthDays, 14)
        XCTAssertEqual(CommercialPolicy.priceDisplay, "$9.99")
    }

    func testTrialPolicyCountsPartialDaysAndRejectsClockRollback() {
        let firstLaunch = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(CommercialPolicy.trialDaysRemaining(firstLaunch: firstLaunch, now: firstLaunch), 14)
        XCTAssertEqual(
            CommercialPolicy.trialDaysRemaining(
                firstLaunch: firstLaunch,
                now: firstLaunch.addingTimeInterval(13 * 86_400 + 1)
            ),
            1
        )
        XCTAssertEqual(
            CommercialPolicy.trialDaysRemaining(
                firstLaunch: firstLaunch,
                now: firstLaunch.addingTimeInterval(14 * 86_400)
            ),
            0
        )
        XCTAssertEqual(
            CommercialPolicy.trialDaysRemaining(firstLaunch: firstLaunch, now: firstLaunch.addingTimeInterval(-1)),
            0
        )
    }

    func testSearchRanking() {
        let code = SpaceProfile(nativeID: 1, displayID: "d", name: "Code")
        let docs = SpaceProfile(nativeID: 2, displayID: "d", name: "Documentation")
        XCTAssertEqual(SpaceSearch.rank(query: "cod", profiles: [docs, code], recents: []).first?.id, code.id)
    }

    func testSearchUsesAliasesAndDiacritics() {
        let space = SpaceProfile(nativeID: 1, displayID: "d", name: "Résumé", aliases: ["Client Alpha"])
        XCTAssertEqual(SpaceSearch.rank(query: "resume", profiles: [space], recents: []).first?.id, space.id)
        XCTAssertEqual(SpaceSearch.rank(query: "alpha", profiles: [space], recents: []).first?.id, space.id)
    }

    func testRecencyOrdersEmptySearch() {
        let first = SpaceProfile(nativeID: 1, displayID: "d", name: "Alpha")
        let second = SpaceProfile(nativeID: 2, displayID: "d", name: "Beta")
        XCTAssertEqual(SpaceSearch.rank(query: "", profiles: [first, second], recents: [second.id]).first?.id, second.id)
    }

    func testRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = DataStore(fileURL: url)
        var data = AppData(); data.spaces = [SpaceProfile(nativeID: 1, displayID: "d", name: "Work")]
        try await store.save(data)
        let loaded = try await store.load()
        XCTAssertEqual(loaded.spaces.first?.name, "Work")
        try? FileManager.default.removeItem(at: url)
    }

    func testSwiftDataMirrorLoadsWithoutJSONMirror() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = DataStore(fileURL: url)
        var data = AppData(); data.spaces = [SpaceProfile(nativeID: 7, displayID: "d", name: "Mirror")]
        try await store.save(data)
        try FileManager.default.removeItem(at: url)
        let loaded = try await store.load()
        XCTAssertEqual(loaded.spaces.first?.name, "Mirror")
    }

    func testBackupPackageRoundTripIncludesMarkdown() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DataStore(fileURL: root.appendingPathComponent("store.json"))
        var data = AppData(); let space = SpaceProfile(nativeID: 1, displayID: "d", name: "Work"); data.spaces = [space]; data.notes = [SpaceNote(spaceID: space.id, title: "Plan", body: "Private body")]
        let package = root.appendingPathComponent("Backup.namespacesbackup", isDirectory: true)
        try await store.exportPackage(data, to: package)
        let loaded = try await store.decodeBackup(at: package)
        XCTAssertEqual(loaded.notes.first?.body, "Private body")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: package.appendingPathComponent("Notes"), includingPropertiesForKeys: nil).count, 1)
        try? FileManager.default.removeItem(at: root)
    }

    func testProfileDecodesLegacyMissingOptionalObservationFields() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","nativeID":1,"displayID":"d","name":"Legacy","symbol":"square.grid.2x2","colorHex":"#7C5CFC","aliases":[],"trackingEnabled":true,"billable":false,"shortcut":null,"createdAt":0,"updatedAt":0}
        """.data(using: .utf8)!
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        let profile = try decoder.decode(SpaceProfile.self, from: json)
        XCTAssertNil(profile.lastKnownIndex); XCTAssertEqual(profile.name, "Legacy")
    }

    func testCSVQuotesValues() {
        let space = SpaceProfile(nativeID: 1, displayID: "d", name: "Client, A")
        let segment = TrackingSegment(spaceID: space.id, appName: "Editor", start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60))
        let csv = CSVExporter.trackingCSV(segments: [segment], spaces: [space])
        XCTAssertTrue(csv.contains("\"Client, A\"")); XCTAssertTrue(csv.contains("\"60\""))
    }


    func testCSVQuotesNewlinesAndDoubleQuotes() {
        let space = SpaceProfile(nativeID: 1, displayID: "d", name: "A \"quoted\" Space")
        let segment = TrackingSegment(spaceID: space.id, appName: "Editor", start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 1), note: "line 1\nline 2")
        let csv = CSVExporter.trackingCSV(segments: [segment], spaces: [space])
        XCTAssertTrue(csv.contains("\"A \"\"quoted\"\" Space\"")); XCTAssertTrue(csv.contains("\"line 1\nline 2\""))
    }

    func testLegacyPreferencesDecodeWithNewDefaults() throws {
        let data = "{\"schemaVersion\":1,\"preferences\":{\"trackingEnabled\":false}}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppData.self, from: data)
        XCTAssertFalse(decoded.preferences.trackingEnabled)
        XCTAssertFalse(decoded.preferences.trackingPaused)
        XCTAssertEqual(decoded.preferences.rollingBackupRetention, 0)
    }

    func testTopologyRejectsDuplicateNativeIDs() {
        let one = NativeSpace(id: 4, displayID: "a", displayName: "A", index: 1, isActive: true)
        let two = NativeSpace(id: 4, displayID: "b", displayName: "B", index: 1, isActive: true)
        XCTAssertThrowsError(try TopologySnapshot(displays: [.init(id: "a", name: "A", spaces: [one]), .init(id: "b", name: "B", spaces: [two])]))
    }

    func testTopologyDiffAndConservativeReconciliation() throws {
        let one = NativeSpace(id: 1, displayID: "a", displayName: "A", index: 1, isActive: true)
        let moved = NativeSpace(id: 1, displayID: "a", displayName: "A", index: 2, isActive: false)
        let added = NativeSpace(id: 2, displayID: "a", displayName: "A", index: 1, isActive: true)
        let before = try TopologySnapshot(displays: [.init(id: "a", name: "A", spaces: [one])])
        let after = try TopologySnapshot(displays: [.init(id: "a", name: "A", spaces: [added, moved])])
        let change = TopologyChange(from: before, to: after)
        XCTAssertEqual(change.added.map(\.id), [2]); XCTAssertEqual(change.changed.count, 1)
        let exact = SpaceProfile(nativeID: 1, displayID: "a", lastKnownIndex: 1, lastKnownKind: .desktop, name: "Work")
        XCTAssertEqual(SpaceReconciler.reconcile(observations: [one], profiles: [exact]).first?.confidence, .confirmed)
        XCTAssertNotEqual(SpaceReconciler.reconcile(observations: [added], profiles: [exact]).first?.confidence, .confirmed)
    }

    func testShortcutValidationAndConflicts() {
        XCTAssertEqual(ShortcutValidator.validate(.init(keyCode: 1, modifiers: 512, display: "⇧S")), .invalid("Global shortcuts require Command, Option, or Control; Shift alone is not enough."))
        let value = ShortcutSpec(keyCode: 49, modifiers: 2048, display: "⌥Space")
        XCTAssertEqual(ShortcutValidator.conflicts([value, value]), [ShortcutValidator.signature(value)])
    }

    func testIdleBoundaryNeverInventsPrelaunchTime() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(TrackingPolicy.idleBoundary(now: now, idleSeconds: 600, hasOpenSegment: false, wasIdle: false), now)
        XCTAssertEqual(TrackingPolicy.idleBoundary(now: now, idleSeconds: 300, hasOpenSegment: true, wasIdle: false), Date(timeIntervalSince1970: 700))
        XCTAssertEqual(TrackingPolicy.idleBoundary(now: now, idleSeconds: 300, hasOpenSegment: true, wasIdle: true), now)
    }

    func testAutomationValidationRejectsUnsafeConfiguration() {
        let url = AutomationAction(kind: .openURL, title: "Bad", target: "file:///private/data")
        XCTAssertFalse(AutomationValidator.errors(for: url).isEmpty)
        let script = AutomationAction(kind: .runScript, title: "Script", target: "relative.sh", arguments: ["zsh"], timeout: 0)
        XCTAssertGreaterThanOrEqual(AutomationValidator.errors(for: script).count, 3)
        XCTAssertTrue(AutomationValidator.errors(for: .init(kind: .openURL, title: "Docs", target: "https://example.invalid")).isEmpty)
    }

    func testMissionControlDesktopLabelParsing() {
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["Desktop 3"]), 3)
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["ignored", "Space 12, selected"]), 12)
        XCTAssertNil(MissionControlLayout.desktopIndex(in: ["Finder window 3"]))
        XCTAssertNil(MissionControlLayout.desktopIndex(in: ["Desktop 0"]))
    }

    func testMissionControlCloseIsImmediateAfterPositiveDetection() {
        XCTAssertTrue(MissionControlLayout.shouldCloseAfterMissingWindow(hasSeenWindow: true, secondsSinceOpen: 0.1))
        XCTAssertFalse(MissionControlLayout.shouldCloseAfterMissingWindow(hasSeenWindow: false, secondsSinceOpen: 0.69))
        XCTAssertTrue(MissionControlLayout.shouldCloseAfterMissingWindow(hasSeenWindow: false, secondsSinceOpen: 0.7))
    }
}

final class QAPassTests: XCTestCase {
    func testDesktopIndexReadsLocalizedMissionControlLabels() {
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["Schreibtisch 4"]), 4)
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["Bureau 2"]), 2)
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["Bureaublad 7"]), 7)
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["Escritorio 3"]), 3)
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["デスクトップ5"]), 5)
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["桌面 6"]), 6)
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["Рабочий стол 8"]), 8)
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["Desktop 10"]), 10)
        // Unchanged English behaviour.
        XCTAssertEqual(MissionControlLayout.desktopIndex(in: ["ignored", "Space 12, selected"]), 12)
        XCTAssertNil(MissionControlLayout.desktopIndex(in: ["Finder window 3"]))
        XCTAssertNil(MissionControlLayout.desktopIndex(in: ["Desktop 0"]))
        XCTAssertNil(MissionControlLayout.desktopIndex(in: ["Desktops"]))
        XCTAssertNil(MissionControlLayout.desktopIndex(in: ["Workspace 3"]))
    }

    func testBadgesNeverReachNeighbouringThumbnailLabels() {
        // 13" laptop, 12 Spaces: compact native labels ~95 pt apart.
        let anchors = (0..<12).map { CGRect(x: 40 + CGFloat($0) * 95, y: 900, width: 60, height: 16) }
        let longName = String(repeating: "x", count: 40)
        for anchor in anchors {
            let width = MissionControlLayout.badgeWidth(nameLength: longName.count, anchor: anchor, neighbors: anchors)
            XCTAssertLessThanOrEqual(width, 89)
        }
        // Few Spaces on a 4K external: the full desired width is kept.
        let wide = [CGRect(x: 400, y: 1900, width: 60, height: 16), CGRect(x: 1400, y: 1900, width: 60, height: 16)]
        XCTAssertEqual(MissionControlLayout.badgeWidth(nameLength: 40, anchor: wide[0], neighbors: wide), 190)
        // A short name is not stretched.
        XCTAssertEqual(MissionControlLayout.badgeWidth(nameLength: 3, anchor: wide[0], neighbors: wide), 54)
        // Anchors on another row (another display stacked above) are ignored.
        let other = [wide[0], CGRect(x: 430, y: 200, width: 60, height: 16)]
        XCTAssertEqual(MissionControlLayout.badgeWidth(nameLength: 40, anchor: other[0], neighbors: other), 190)
    }

    func testSpacesMatchScreensByDisplayUUIDNotMarketingName() {
        let left = "11111111-AAAA-0000-0000-000000000001", right = "22222222-BBBB-0000-0000-000000000002"
        // Two identical monitors share one localized name.
        XCTAssertTrue(DisplayMatching.belongs(spaceDisplayID: right, spaceDisplayName: "DELL U2723QE", screenUUID: right.lowercased(), screenName: "DELL U2723QE", isPrimaryScreen: false, screenCount: 2))
        XCTAssertFalse(DisplayMatching.belongs(spaceDisplayID: right, spaceDisplayName: "DELL U2723QE", screenUUID: left, screenName: "DELL U2723QE", isPrimaryScreen: true, screenCount: 2))
        // "Displays have separate Spaces" off: one shared set on the primary screen.
        XCTAssertTrue(DisplayMatching.belongs(spaceDisplayID: "Main", spaceDisplayName: "Display 1", screenUUID: left, screenName: "Built-in Retina Display", isPrimaryScreen: true, screenCount: 2))
        XCTAssertFalse(DisplayMatching.belongs(spaceDisplayID: "Main", spaceDisplayName: "Display 1", screenUUID: right, screenName: "DELL", isPrimaryScreen: false, screenCount: 2))
        XCTAssertTrue(DisplayMatching.belongs(spaceDisplayID: "x", spaceDisplayName: "y", screenUUID: nil, screenName: "z", isPrimaryScreen: true, screenCount: 1))
    }
}

final class LicenseOutcomeTests: XCTestCase {
    func testServerRejectionIsNotTreatedAsOffline() {
        XCTAssertEqual(LicenseCheckOutcome.from(httpStatus: 200, valid: true, message: nil), .valid)
        XCTAssertEqual(LicenseCheckOutcome.from(httpStatus: 200, valid: false, message: "refunded"), .rejected("refunded"))
        // Lemon Squeezy answers an unknown/disabled key with 404 + valid:false.
        XCTAssertEqual(LicenseCheckOutcome.from(httpStatus: 404, valid: false, message: "license_key not found."), .rejected("license_key not found."))
        XCTAssertEqual(LicenseCheckOutcome.from(httpStatus: 400, valid: nil, message: "bad key"), .rejected("bad key"))
    }

    func testOutagesKeepAnActivatedCopyWorking() {
        XCTAssertEqual(LicenseCheckOutcome.from(httpStatus: nil, valid: nil, message: nil), .unreachable)
        XCTAssertEqual(LicenseCheckOutcome.from(httpStatus: 503, valid: nil, message: nil), .unreachable)
        XCTAssertEqual(LicenseCheckOutcome.from(httpStatus: 429, valid: false, message: "slow down"), .unreachable)
        XCTAssertEqual(LicenseCheckOutcome.from(httpStatus: 200, valid: nil, message: nil), .unreachable)
        // A captive portal / proxy HTML page: no decodable answer.
        XCTAssertEqual(LicenseCheckOutcome.from(httpStatus: 403, valid: nil, message: nil), .unreachable)
    }
}
