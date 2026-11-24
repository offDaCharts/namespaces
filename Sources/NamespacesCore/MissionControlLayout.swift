import CoreGraphics
import Foundation

/// Pure parsing and dismissal rules shared by the Mission Control integration.
public enum MissionControlLayout {
    public static func shouldCloseAfterMissingWindow(hasSeenWindow: Bool, secondsSinceOpen: TimeInterval) -> Bool {
        hasSeenWindow || secondsSinceOpen >= 0.7
    }

    /// Words macOS uses for "Desktop N" in Mission Control, in the system
    /// languages DeskOrbit is most likely to meet. Mission Control labels are
    /// localized, so an English-only parser drew no labels at all on, for
    /// example, a German or Japanese Mac. Longer words come first so that a
    /// word which is a prefix of another (bureau / bureaublad) is not tried
    /// before the longer match.
    public static let desktopWords: [String] = [
        "área de trabalho", "рабочий стол", "skrivebord", "bureaublad", "schreibtisch", "escritorio",
        "scrivania", "skrivbord", "työpöytä", "masaüstü", "plocha", "pulpit", "desktop", "bureau",
        "space", "デスクトップ", "데스크탑", "데스크톱", "桌面",
    ]

    public static func desktopIndex(in values: [String]) -> Int? {
        for value in values {
            let text = value.lowercased()
            for word in desktopWords {
                var searchStart = text.startIndex
                while let range = text.range(of: word, range: searchStart..<text.endIndex) {
                    searchStart = range.upperBound
                    // The keyword must start a word ("Mydesktop 3" is not a label).
                    if range.lowerBound > text.startIndex,
                       text[text.index(before: range.lowerBound)].isLetter,
                       word.unicodeScalars.first.map({ $0.isASCII }) == true { continue }
                    if let index = firstNumber(after: text[range.upperBound...]) { return index }
                }
            }
        }
        return nil
    }

    /// The first positive integer after a keyword. Separators and other whole
    /// words may come between ("Space 12, selected" / "Desktop, 3"), but the
    /// keyword must not continue as a longer word ("bureau" in "bureaublad").
    private static func firstNumber(after rest: Substring) -> Int? {
        if let first = rest.first, first.isLetter, first.unicodeScalars.first?.isASCII == true || first.isCased { return nil }
        var digits = ""
        for character in rest {
            if character.isASCII, character.isNumber { digits.append(character) }
            else if !digits.isEmpty { break }
        }
        guard let index = Int(digits), index > 0 else { return nil }
        return index
    }

    /// Width for a name badge drawn over a Mission Control thumbnail. Labels
    /// were sized only by name length (up to 190 pt), so with many Spaces on a
    /// laptop screen long names overlapped the neighbouring thumbnails' labels.
    /// The badge now never extends past half the gap to its nearest neighbour.
    public static func badgeWidth(nameLength: Int, anchor: CGRect, neighbors: [CGRect]) -> CGFloat {
        let desired = min(190, max(54, CGFloat(nameLength) * 6.4 + 18))
        var width = anchor.height > 50 ? min(desired, max(54, anchor.width - 12)) : desired
        let sameRow = neighbors.filter { $0 != anchor && abs($0.midY - anchor.midY) < max(anchor.height, 24) }
        if let nearest = sameRow.map({ abs($0.midX - anchor.midX) }).filter({ $0 > 0 }).min() {
            width = min(width, max(36, nearest - 6))
        }
        return width.rounded(.down)
    }
}

/// Which screen a native Space belongs to. Spaces were matched to screens by
/// the screen's marketing name, so two identical monitors (two "DELL U2723QE")
/// shared one name and every label went to the first, and with "Displays have
/// separate Spaces" turned off (display identifier "Main") no screen matched.
public enum DisplayMatching {
    public static func belongs(spaceDisplayID: String, spaceDisplayName: String, screenUUID: String?, screenName: String, isPrimaryScreen: Bool, screenCount: Int) -> Bool {
        if screenCount <= 1 { return true }
        if spaceDisplayID.caseInsensitiveCompare("Main") == .orderedSame { return isPrimaryScreen }
        if let screenUUID, !screenUUID.isEmpty {
            return spaceDisplayID.caseInsensitiveCompare(screenUUID) == .orderedSame
        }
        return !screenName.isEmpty && spaceDisplayName == screenName
    }
}
