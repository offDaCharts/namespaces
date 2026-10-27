import CoreGraphics
import Darwin
import XCTest
@testable import NamespacesCore

final class AgentAndIdentityTests: XCTestCase {
    private let a = "11111111-1111-4111-8111-111111111111"
    private let b = "22222222-2222-4222-8222-222222222222"
    private func native(_ id: UInt64 = 1, display: String = "laptop", index: Int = 1, uuid: String? = nil) -> NativeSpace {
        NativeSpace(id: id, displayID: display, displayName: display, index: index, isActive: true, persistentID: uuid)
    }
    private func profile(_ id: UInt64 = 1, display: String = "external", uuid: String? = nil) -> SpaceProfile {
        SpaceProfile(nativeID: id, displayID: display, lastKnownIndex: 1, lastKnownKind: .desktop, persistentID: uuid, name: "Research", symbol: "book", colorHex: "#123456", aliases: ["papers"])
    }
    func testMonitorMoveKeepsLegacyProfileAndMetadata() {
        let original = profile()
        var saved = [original]
        SpaceIdentity.reconcile([native(index: 5)], profiles: &saved)
        XCTAssertEqual(saved.count, 1); XCTAssertEqual(saved[0].id, original.id)
        XCTAssertEqual(saved[0].name, "Research"); XCTAssertEqual(saved[0].colorHex, "#123456")
        XCTAssertEqual(saved[0].symbol, "book"); XCTAssertEqual(saved[0].aliases, ["papers"])
        XCTAssertEqual(saved[0].displayID, "laptop"); XCTAssertEqual(saved[0].lastKnownIndex, 5)
    }
    func testUUIDSurvivesNumericIDChangeAndReconnect() {
        let original = profile(uuid: a)
        var saved = [original]
        SpaceIdentity.reconcile([native(91, index: 6, uuid: a.lowercased())], profiles: &saved)
        SpaceIdentity.reconcile([], profiles: &saved)
        SpaceIdentity.reconcile([native(100, display: "external", uuid: a)], profiles: &saved)
        XCTAssertEqual(saved.count, 1); XCTAssertEqual(saved[0].id, original.id)
        XCTAssertEqual(saved[0].nativeID, 100); XCTAssertEqual(saved[0].displayID, "external")
    }
    func testUUIDTakesPrecedenceOverReusedNumericID() {
        let original = profile(uuid: a)
        var saved = [original]
        SpaceIdentity.reconcile([native(1, uuid: b), native(2, uuid: a)], profiles: &saved)
        XCTAssertEqual(saved.count, 2)
        let map = SpaceIdentity.matches([native(1, uuid: b), native(2, uuid: a)], profiles: saved)
        XCTAssertEqual(map[2], original.id); XCTAssertNotEqual(map[1], original.id)
    }
    func testReusedIDDoesNotRetireDifferentUUID() {
        let original = profile(uuid: a)
        var saved = [original]
        SpaceIdentity.reconcile([native(1, uuid: b)], profiles: &saved)
        XCTAssertNotEqual(saved[0].needsRelinking, true)
        SpaceIdentity.reconcile([native(9, uuid: a), native(1, uuid: b)], profiles: &saved)
        XCTAssertEqual(saved.count, 2); XCTAssertEqual(saved[0].nativeID, 9)
    }
    func testUncertainOrdinalNeverStealsName() {
        let original = profile()
        var saved = [original]
        SpaceIdentity.reconcile([native(88, display: "external")], profiles: &saved)
        XCTAssertEqual(saved.count, 2); XCTAssertEqual(saved[0], original)
        XCTAssertEqual(saved[1].name, "Desktop 1")
    }
    func testLegacyDuplicateBindingsDoNotMultiplyOnRefresh() {
        let originals = [profile(), profile(display: "laptop")]
        var saved = originals
        for _ in 0..<20 { SpaceIdentity.reconcile([native(uuid: a)], profiles: &saved) }
        XCTAssertEqual(saved.count, 3)
        XCTAssertTrue(saved.prefix(2).allSatisfy { $0.needsRelinking == true && $0.name == "Research" })
        XCTAssertEqual(SpaceIdentity.matches([native(uuid: a)], profiles: saved)[1], saved[2].id)
    }
    func testDuplicateUUIDBindingsPreserveContentWithoutRepeatCreation() {
        var saved = [profile(uuid: a), profile(2, uuid: a)]
        for _ in 0..<20 { SpaceIdentity.reconcile([native(3, uuid: a)], profiles: &saved) }
        XCTAssertEqual(saved.count, 3)
        XCTAssertEqual(saved.filter { $0.needsRelinking == true }.count, 2)
    }
    func testDuplicateObservationIDsCannotMutateProfiles() {
        var saved = [profile()]; let before = saved
        SpaceIdentity.reconcile([native(), native(display: "external")], profiles: &saved)
        XCTAssertEqual(saved, before)
    }
    func testStableIdentityUpgradeAndRoundTrip() throws {
        var saved = [profile()]
        SpaceIdentity.reconcile([native(uuid: a)], profiles: &saved)
        XCTAssertEqual(saved[0].persistentID, a)
        saved[0].needsRelinking = true
        XCTAssertEqual(try JSONDecoder().decode([SpaceProfile].self, from: JSONEncoder().encode(saved)), saved)
        XCTAssertNil(SpaceIdentity.normalized("00000000-0000-0000-0000-000000000000"))
        XCTAssertNil(SpaceIdentity.normalized("not-a-uuid"))
    }
    func testFiveSpacesMergeOntoLaptopAndReturnInDifferentOrder() {
        let originals = (1...5).map { profile(UInt64($0), uuid: UUID().uuidString) }
        var saved = originals
        let merged = originals.enumerated().map { native(UInt64($0.offset + 30), index: $0.offset + 3, uuid: $0.element.persistentID) }
        SpaceIdentity.reconcile(merged, profiles: &saved)
        let returned = originals.reversed().enumerated().map { native(UInt64($0.offset + 80), display: "external", index: $0.offset + 1, uuid: $0.element.persistentID) }
        SpaceIdentity.reconcile(returned, profiles: &saved)
        XCTAssertEqual(saved.map(\.id), originals.map(\.id))
        XCTAssertEqual(saved.map(\.name), originals.map(\.name))
        XCTAssertEqual(saved[0].lastKnownIndex, 5)
    }

    private func edit(_ p: SpaceProfile, name: String = "Build", extras: [String: JSONValue] = [:]) -> JSONValue {
        .object(["space_id": .string(p.id.uuidString), "name": .string(name)].merging(extras) { _, new in new })
    }
    func testBatchAssignsPaletteAndPreservesExistingIcons() throws {
        let profiles = [profile(1), profile(2)]
        let edits = try SpaceEdit.parse(.array(profiles.map { edit($0, name: "  Build  ") }), profiles: profiles, available: Set(profiles.map(\.id)))
        XCTAssertEqual(edits.map(\.name), ["Build", "Build"])
        XCTAssertEqual(edits.map(\.color), [SpacePalette.color(at: 0), SpacePalette.color(at: 1)])
        XCTAssertEqual(edits.map(\.symbol), ["book", "book"])
    }
    func testBatchRejectsInvalidEntriesBeforeAnyMutation() {
        let p = profile(); let available: Set<UUID> = [p.id]
        let invalid: [JSONValue] = [
            .array([]), .array([edit(p), edit(p)]), .array([edit(profile(9))]),
            .array([edit(p, name: " ")]), .array([edit(p, name: "a\u{0000}b")]),
            .array([edit(p, name: String(repeating: "x", count: 81))]),
            .array([edit(p, extras: ["color": .string("red")])]),
            .array([edit(p, extras: ["color": .null])]),
            .array([edit(p, extras: ["symbol": .string("bad-icon")])]),
            .array([edit(p, extras: ["script": .string("danger")])]),
            .array(Array(repeating: edit(p), count: 33))
        ]
        for value in invalid { XCTAssertThrowsError(try SpaceEdit.parse(value, profiles: [p], available: available)) }
        XCTAssertThrowsError(try SpaceEdit.parse(.array([edit(p)]), profiles: [p], available: []))
    }
    func testExplicitColorAndUnicodeNames() throws {
        let p = profile()
        let result = try SpaceEdit.parse(.array([edit(p, name: "研究 🔭", extras: ["color": .string("#aabbcc"), "symbol": .string("terminal")])]), profiles: [p], available: [p.id])
        XCTAssertEqual(result[0].name, "研究 🔭"); XCTAssertEqual(result[0].color, "#AABBCC")
        XCTAssertEqual(result[0].symbol, "terminal")
    }
    func testToolSurfaceIsNarrowAndValidated() {
        XCTAssertEqual(AgentTools.definitions.array?.count, 6)
        XCTAssertThrowsError(try AgentTools.validate(name: "deskorbit_configure_spaces", arguments: .object(["spaces": .array([]), "apply": .string("true")])))
        XCTAssertThrowsError(try AgentTools.validate(name: "deskorbit_status", arguments: .object(["script": .string("x")])))
        XCTAssertThrowsError(try AgentTools.validate(name: "run_script", arguments: .object([:])))
        XCTAssertThrowsError(try AgentTools.validate(name: "deskorbit_switch_space", arguments: .object([:])))
    }
    func testMCPLifecycleToolsAndNotifications() throws {
        var mcp = MCPProtocol(); var executions = 0
        func run(_ input: String) -> JSONValue? { mcp.response(to: Data(input.utf8)) { _, _ in executions += 1; return .object(["ok": .bool(true)]) } }
        XCTAssertEqual(run(#"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#)?["error"]["code"], .number(-32002))
        XCTAssertEqual(run(#"{"jsonrpc":"2.0","id":"hello","method":"initialize","params":{"protocolVersion":"2025-11-25"}}"#)?["result"]["protocolVersion"], .string("2025-11-25"))
        XCTAssertNil(run(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#))
        XCTAssertEqual(run(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)?["result"]["tools"].array?.count, 6)
        XCTAssertEqual(run(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"deskorbit_status"}}"#)?["result"]["isError"], .bool(false))
        XCTAssertEqual(executions, 1)
        XCTAssertNil(run(#"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"deskorbit_status"}}"#))
        XCTAssertEqual(executions, 1)
        XCTAssertEqual(run(#"{"jsonrpc":"2.0","id":4,"method":"unknown"}"#)?["error"]["code"], .number(-32601))
    }
    func testMCPMalformedInputsAndToolFailure() {
        var mcp = MCPProtocol()
        let execute: (String, JSONValue) throws -> JSONValue = { _, _ in throw AgentError("Disabled") }
        XCTAssertEqual(mcp.response(to: Data("{".utf8), execute: execute)?["error"]["code"], .number(-32700))
        for invalid in ["[]", "null", #"{"jsonrpc":"2.0","id":true,"method":"ping"}"#] {
            XCTAssertEqual(mcp.response(to: Data(invalid.utf8), execute: execute)?["error"]["code"], .number(-32600))
        }
        _ = mcp.response(to: Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"future"}}"#.utf8), execute: execute)
        let reply = mcp.response(to: Data(#"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"deskorbit_status"}}"#.utf8), execute: execute)
        XCTAssertEqual(reply?["result"]["isError"], .bool(true))
        XCTAssertEqual(reply?["result"]["content"].array?.first?["text"], .string("Disabled"))
    }
    func testSocketFramingAndLimits() throws {
        var pair: [Int32] = [0, 0]
        XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair), 0)
        defer { close(pair[0]); close(pair[1]) }
        _ = fcntl(pair[1], F_SETFL, O_NONBLOCK)
        pair.forEach { LocalAgentSocket.configure($0) }
        XCTAssertEqual(fcntl(pair[1], F_GETFL) & O_NONBLOCK, 0)
        let data = Data(#"{"message":"two\nlines"}"#.utf8)
        try LocalAgentSocket.writeMessage(data, to: pair[0])
        XCTAssertEqual(try LocalAgentSocket.readMessage(pair[1]), data)
        XCTAssertThrowsError(try LocalAgentSocket.writeMessage(Data(repeating: 65, count: LocalAgentSocket.maximumMessageBytes + 1), to: pair[0]))
        shutdown(pair[0], SHUT_WR)
        XCTAssertThrowsError(try LocalAgentSocket.readMessage(pair[1]))
    }
    func testWindowFramesStayReachableAcrossScreenSizesAndOrigins() {
        let screens = [CGRect(x: 0, y: 0, width: 800, height: 550), CGRect(x: 0, y: 30, width: 1280, height: 700), CGRect(x: -2560, y: 0, width: 2560, height: 1400), CGRect(x: 0, y: -1080, width: 1920, height: 1050), CGRect(x: 0, y: 0, width: 3840, height: 2100)]
        let windows = [CGRect(x: 2000, y: 1000, width: 900, height: 650), CGRect(x: -1000, y: -900, width: 500, height: 2000), CGRect(x: 0, y: 0, width: 380, height: 410)]
        for screen in screens { for window in windows {
            let fit = WindowPlacement.fit(window, in: screen)
            XCTAssertTrue(screen.insetBy(dx: 8, dy: 8).contains(fit))
            XCTAssertGreaterThan(fit.width, 0); XCTAssertGreaterThan(fit.height, 0)
        } }
    }
}
