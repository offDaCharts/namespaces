import AppKit
import CoreGraphics
import Darwin
import Foundation
import NamespacesCore

struct ProviderCapabilities: OptionSet, Sendable {
    let rawValue: Int
    static let enumerate = Self(rawValue: 1 << 0)
    static let switchSpace = Self(rawValue: 1 << 1)
    static let moveWindow = Self(rawValue: 1 << 2)
    static let missionControlLabels = Self(rawValue: 1 << 3)
}

protocol SpaceProviding: AnyObject {
    var capabilities: ProviderCapabilities { get }
    var name: String { get }
    func spaces() throws -> [NativeSpace]
    func switchTo(_ space: NativeSpace) throws
    func moveWindow(_ windowID: CGWindowID, to space: NativeSpace) throws
}

enum SpaceProviderError: LocalizedError {
    case unavailable(String), malformedData, operationFailed(String)
    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): reason
        case .malformedData: "macOS returned an unexpected Spaces layout. Enhanced integration was disabled safely."
        case .operationFailed(let operation): "The Space operation failed: \(operation)"
        }
    }
}

final class EnhancedSpaceProvider: SpaceProviding {
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias CopySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias SetSpaceFn = @convention(c) (Int32, CFString, UInt64) -> Int32
    private typealias MoveWindowsFn = @convention(c) (Int32, CFArray, UInt64) -> Int32

    private let mainConnection: MainConnectionFn?
    private let copySpaces: CopySpacesFn?
    private let setSpace: SetSpaceFn?
    private let moveWindows: MoveWindowsFn?

    let name = "Enhanced WindowServer"
    var capabilities: ProviderCapabilities {
        var result: ProviderCapabilities = []
        if mainConnection != nil, copySpaces != nil { result.insert(.enumerate) }
        if setSpace != nil { result.insert(.switchSpace) }
        if moveWindows != nil { result.insert(.moveWindow) }
        if result.contains(.enumerate) { result.insert(.missionControlLabels) }
        return result
    }

    init() {
        let handle = dlopen(nil, RTLD_NOW)
        func symbol<T>(_ name: String, _: T.Type) -> T? {
            guard let pointer = dlsym(handle, name) else { return nil }
            return unsafeBitCast(pointer, to: T.self)
        }
        mainConnection = symbol("CGSMainConnectionID", MainConnectionFn.self)
        copySpaces = symbol("CGSCopyManagedDisplaySpaces", CopySpacesFn.self)
        setSpace = symbol("CGSManagedDisplaySetCurrentSpace", SetSpaceFn.self)
        moveWindows = symbol("CGSMoveWindowsToManagedSpace", MoveWindowsFn.self)
    }

    func spaces() throws -> [NativeSpace] {
        guard let mainConnection, let copySpaces else { throw SpaceProviderError.unavailable("Enhanced Space enumeration is unavailable on this macOS build.") }
        guard let raw = copySpaces(mainConnection())?.takeRetainedValue() as? [[String: Any]] else { throw SpaceProviderError.malformedData }
        let screenNames = Self.screenNames()
        var output: [NativeSpace] = []
        for (displayOrdinal, display) in raw.enumerated() {
            let displayID = (display["Display Identifier"] as? String) ?? "display-\(displayOrdinal + 1)"
            let current = ((display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? NSNumber)?.uint64Value
            guard let records = display["Spaces"] as? [[String: Any]] else { continue }
            for (index, record) in records.enumerated() {
                guard let id = (record["ManagedSpaceID"] as? NSNumber)?.uint64Value else { continue }
                let type = (record["type"] as? NSNumber)?.intValue ?? 0
                output.append(NativeSpace(id: id, displayID: displayID, displayName: screenNames[displayID] ?? "Display \(displayOrdinal + 1)", index: index + 1, isActive: id == current, kind: type == 4 ? .fullscreen : .desktop))
            }
        }
        guard !output.isEmpty else { throw SpaceProviderError.malformedData }
        return output
    }

    func switchTo(_ space: NativeSpace) throws {
        guard let mainConnection, let setSpace else { throw SpaceProviderError.unavailable("Direct Space switching is unavailable.") }
        let status = setSpace(mainConnection(), space.displayID as CFString, space.id)
        guard status == 0 else { throw SpaceProviderError.operationFailed("switch (status \(status))") }
    }

    func moveWindow(_ windowID: CGWindowID, to space: NativeSpace) throws {
        guard let mainConnection, let moveWindows else { throw SpaceProviderError.unavailable("Moving windows between Spaces is unavailable.") }
        let windows = [NSNumber(value: windowID)] as CFArray
        let status = moveWindows(mainConnection(), windows, space.id)
        guard status == 0 else { throw SpaceProviderError.operationFailed("move window (status \(status))") }
    }

    private static func screenNames() -> [String: String] {
        var output: [String: String] = [:]
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(number.uint32Value))?.takeRetainedValue()
            else { continue }
            let localized = screen.localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = "Display \(output.count + 1)"
            output[CFUUIDCreateString(nil, uuid) as String] = localized.isEmpty ? fallback : localized
        }
        return output
    }
}

final class FallbackSpaceProvider: SpaceProviding {
    let name = "Public fallback"
    var capabilities: ProviderCapabilities { AXIsProcessTrusted() ? [.switchSpace] : [] }
    func spaces() throws -> [NativeSpace] { throw SpaceProviderError.unavailable("Native Space discovery requires enhanced integration on this macOS version.") }
    func switchTo(_ space: NativeSpace) throws {
        guard AXIsProcessTrusted(), (1...9).contains(space.index) else { throw SpaceProviderError.unavailable("Fallback switching requires Accessibility and a Desktop number from 1 through 9. Enable ‘Switch to Desktop’ shortcuts in System Settings → Keyboard → Keyboard Shortcuts → Mission Control.") }
        let keyCodes: [CGKeyCode] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCodes[space.index - 1], keyDown: true), let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCodes[space.index - 1], keyDown: false) else { throw SpaceProviderError.operationFailed("create fallback keyboard event") }
        down.flags = .maskControl; up.flags = .maskControl; down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
    }
    func moveWindow(_ windowID: CGWindowID, to space: NativeSpace) throws { throw SpaceProviderError.unavailable("Window movement is unavailable in fallback mode.") }
}
