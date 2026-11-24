import XCTest
@testable import NamespacesCore

final class BetaFeedbackTests: XCTestCase {
    func testBetaRunsThroughFebruary2027EasternTime() {
        let iso = ISO8601DateFormatter()
        let lastEvening = iso.date(from: "2027-03-01T04:30:00Z")! // Feb 28, 11:30 pm ET
        let nextMorning = iso.date(from: "2027-03-01T06:00:00Z")! // Mar 1, 1 am ET
        XCTAssertEqual(CommercialPolicy.betaDaysRemaining(now: lastEvening), 1)
        XCTAssertEqual(CommercialPolicy.betaDaysRemaining(now: nextMorning), 0)
        XCTAssertGreaterThan(CommercialPolicy.betaDaysRemaining(now: iso.date(from: "2026-11-24T12:00:00Z")!), 90)
    }

    func testSubjectIsTaggedForTheFeedbackJob() {
        let draft = FeedbackDraft(kind: .bug, message: "Labels missing on my second monitor\nmore detail")
        XCTAssertEqual(draft.subject(version: "0.3.1"), "[DeskOrbit 0.3.1 bug] Labels missing on my second monitor")
        XCTAssertEqual(FeedbackDraft(kind: .idea, message: "  ").subject(version: "0.3.1"), "[DeskOrbit 0.3.1 idea] Feedback")
    }

    func testBodyIncludesOnlyWhatWasChosen() {
        let plain = FeedbackDraft(kind: .bug, message: "Crashed", contact: "", diagnostics: nil, crashExcerpt: nil).body()
        XCTAssertFalse(plain.contains("diagnostics"))
        XCTAssertFalse(plain.contains("Reply to"))
        let full = FeedbackDraft(kind: .bug, message: "Crashed", contact: "a@b.c", diagnostics: "macOS: 26.2", crashExcerpt: "EXC_BAD_ACCESS").body()
        XCTAssertTrue(full.contains("Reply to: a@b.c"))
        XCTAssertTrue(full.contains("macOS: 26.2"))
        XCTAssertTrue(full.contains("EXC_BAD_ACCESS"))
    }

    func testURLsAreEncodedAndBounded() throws {
        let long = String(repeating: "x", count: 20_000)
        let mail = try XCTUnwrap(FeedbackChannel.mailtoURL(to: "quin+deskorbit@kauibungalow.com", subject: "a & b", body: long))
        XCTAssertTrue(mail.absoluteString.hasPrefix("mailto:quin+deskorbit@kauibungalow.com?subject=a%20%26%20b"), mail.absoluteString)
        XCTAssertLessThan(mail.absoluteString.count, 7_000)
        let issue = try XCTUnwrap(FeedbackChannel.githubIssueURL(repository: "offDaCharts/namespaces", subject: "t", body: "b#1", labels: ["feedback", "bug"]))
        XCTAssertTrue(issue.absoluteString.hasPrefix("https://github.com/offDaCharts/namespaces/issues/new?"))
        XCTAssertTrue(issue.absoluteString.contains("labels=feedback,bug"))
        XCTAssertTrue(issue.absoluteString.contains("body=b%231"))
    }

    func testOnlyNewDeskOrbitCrashReportsArePending() {
        let now = Date()
        let reports: [(name: String, modified: Date)] = [
            ("DeskOrbit-2026-11-20-101010.ips", now.addingTimeInterval(-3 * 86_400)),
            ("DeskOrbit-2026-11-23-101010.ips", now.addingTimeInterval(-60)),
            ("Safari-2026-11-23.ips", now.addingTimeInterval(-30)),
        ]
        XCTAssertEqual(CrashReportPolicy.newReports(reports, since: now.addingTimeInterval(-86_400), now: now), ["DeskOrbit-2026-11-23-101010.ips"])
        XCTAssertEqual(CrashReportPolicy.newReports(reports, since: nil, now: now).count, 2)
        XCTAssertTrue(CrashReportPolicy.newReports(reports, since: now, now: now).isEmpty)
    }

    func testCrashExcerptHidesHomeAndIsBounded() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let text = "path: \(home)/Applications/DeskOrbit.app\n" + String(repeating: "y", count: 10_000)
        let excerpt = CrashReportPolicy.excerpt(text)
        XCTAssertFalse(excerpt.contains(home))
        XCTAssertTrue(excerpt.contains("~/Applications"))
        XCTAssertLessThan(excerpt.count, 3_100)
    }
}
