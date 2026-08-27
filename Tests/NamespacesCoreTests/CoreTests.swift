import XCTest
@testable import NamespacesCore

final class CoreTests: XCTestCase {
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

    func testMissionControlBadgeInheritsExactThumbnailCenterAndWidth() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let thumbnail = CGRect(x: 217.5, y: 742, width: 181, height: 108)
        let badge = try! XCTUnwrap(MissionControlLayout.badgeFrame(in: thumbnail, screen: screen))
        XCTAssertEqual(badge.midX, thumbnail.midX, accuracy: 0.5)
        XCTAssertEqual(badge.width, thumbnail.width - 12, accuracy: 1)
        XCTAssertEqual(badge.minY, thumbnail.minY + 5, accuracy: 1)
        XCTAssertEqual(badge.height, 22)
        XCTAssertTrue(thumbnail.contains(badge))
    }

    func testMissionControlRejectsCompactLabelsAndFullWidthContainers() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        XCTAssertFalse(MissionControlLayout.isExpandedThumbnail(CGRect(x: 200, y: 820, width: 80, height: 22), on: screen))
        XCTAssertFalse(MissionControlLayout.isExpandedThumbnail(CGRect(x: 0, y: 700, width: 1_440, height: 180), on: screen))
        XCTAssertNil(MissionControlLayout.badgeFrame(in: CGRect(x: 200, y: 820, width: 80, height: 22), screen: screen))
    }

    func testMissionControlGeometryAcrossDisplaysCountsAndOrientations() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1_440, height: 900),
            CGRect(x: -1_920, y: -180, width: 1_920, height: 1_080),
            CGRect(x: 1_440, y: 0, width: 1_080, height: 1_920),
            CGRect(x: 2_520, y: 120, width: 3_440, height: 1_440),
        ]
        for screen in screens {
            for count in [1, 2, 4, 8, 13, 16] {
                let gap: CGFloat = 8
                let available = screen.width - 60 - CGFloat(count - 1) * gap
                let width = min(CGFloat(230), available / CGFloat(count))
                guard width >= 70 else { continue }
                let total = width * CGFloat(count) + CGFloat(count - 1) * gap
                let start = screen.midX - total / 2
                let thumbnails = (0..<count).map { index in
                    CGRect(x: start + CGFloat(index) * (width + gap), y: screen.maxY - 150, width: width, height: 105)
                }
                let badges = thumbnails.compactMap { MissionControlLayout.badgeFrame(in: $0, screen: screen) }
                XCTAssertEqual(badges.count, count, "screen=\(screen), count=\(count)")
                for (thumbnail, badge) in zip(thumbnails, badges) {
                    XCTAssertTrue(thumbnail.contains(badge))
                    XCTAssertEqual(thumbnail.midX, badge.midX, accuracy: 0.5)
                }
                for pair in zip(badges, badges.dropFirst()) { XCTAssertLessThanOrEqual(pair.0.maxX, pair.1.minX) }
            }
        }
    }

    func testMissionControlCloseIsImmediateAfterPositiveDetection() {
        XCTAssertTrue(MissionControlLayout.shouldCloseAfterMissingWindow(hasSeenWindow: true, secondsSinceOpen: 0.1))
        XCTAssertFalse(MissionControlLayout.shouldCloseAfterMissingWindow(hasSeenWindow: false, secondsSinceOpen: 0.69))
        XCTAssertTrue(MissionControlLayout.shouldCloseAfterMissingWindow(hasSeenWindow: false, secondsSinceOpen: 0.7))
    }
}
