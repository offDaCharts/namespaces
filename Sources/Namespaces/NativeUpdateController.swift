import AppKit
import Foundation

/// A deliberately small updater that keeps DeskOrbit's runtime bundle to one
/// executable. Replacing the app never touches data in Application Support or
/// UserDefaults, so names and settings survive an update.
@MainActor
final class NativeUpdateController {
    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private static let endpoint = URL(string: "https://api.github.com/repos/offDaCharts/namespaces/releases/latest")!
    private var isChecking = false

    func checkForUpdates(userInitiated: Bool) {
        guard !isChecking else { return }
        isChecking = true

        Task {
            defer { isChecking = false }
            do {
                var request = URLRequest(url: Self.endpoint)
                request.timeoutInterval = 12
                request.setValue("DeskOrbit", forHTTPHeaderField: "User-Agent")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw UpdateError.unavailable
                }
                let release = try JSONDecoder().decode(Release.self, from: data)
                let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
                if latest.compare(current, options: .numeric) == .orderedDescending {
                    showAvailable(version: latest, url: release.htmlURL)
                } else if userInitiated {
                    showMessage(title: "DeskOrbit is up to date", text: "You’re running version \(current).")
                }
            } catch {
                if userInitiated {
                    showMessage(title: "Couldn’t check for updates", text: "Open the DeskOrbit releases page to check manually.", openReleases: true)
                }
            }
        }
    }

    private func showAvailable(version: String, url: URL) {
        let alert = NSAlert()
        alert.messageText = "DeskOrbit \(version) is available"
        alert.informativeText = "Download the new app and replace the copy in Applications. Your Space names, notes, tracking, license, and settings will remain intact."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
    }

    private func showMessage(title: String, text: String, openReleases: Bool = false) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: openReleases ? "Open Releases" : "OK")
        if openReleases { alert.addButton(withTitle: "Cancel") }
        NSApp.activate(ignoringOtherApps: true)
        if openReleases, alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/offDaCharts/namespaces/releases/latest")!)
        } else if !openReleases {
            alert.runModal()
        }
    }

    private enum UpdateError: Error { case unavailable }
}
