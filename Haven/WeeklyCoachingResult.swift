import Foundation
import SwiftData

@Model
class WeeklyCoachingResult {
    var weekStartDate: Date = Date()
    var weekEndDate: Date = Date()
    var createdAt: Date = Date()

    // Store sections as JSON (SwiftData handles nested custom types poorly)
    var sectionsJSON: String = "[]"

    // Quick-access fields for list display without JSON parsing
    var weeklyFocusText: String?
    var biggestWinText: String?
    var paceStart: Double?
    var paceEnd: Double?

    init(weekStart: Date, weekEnd: Date, analysis: WeeklyAnalysis, paceStart: Double?, paceEnd: Double?) {
        self.weekStartDate = weekStart
        self.weekEndDate = weekEnd
        self.createdAt = Date()
        self.paceStart = paceStart
        self.paceEnd = paceEnd

        // Encode sections
        let sectionData = analysis.sections.map { CoachingSectionData(from: $0) }
        if let jsonData = try? JSONEncoder().encode(sectionData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.sectionsJSON = jsonString
        } else {
            self.sectionsJSON = "[]"
        }

        // Extract quick-access fields
        self.weeklyFocusText = analysis.sections.first(where: { $0.type == .weeklyFocus })?.body
        self.biggestWinText = analysis.sections.first(where: { $0.type == .biggestWin })?.body
    }

    /// Decode stored sections back into CoachingSection objects for display
    func decodeSections() -> [CoachingSection] {
        guard let data = sectionsJSON.data(using: .utf8),
              let sectionData = try? JSONDecoder().decode([CoachingSectionData].self, from: data) else {
            return []
        }
        return sectionData.map { $0.toCoachingSection() }
    }
}

// MARK: - Codable Wrapper for JSON Storage

struct CoachingSectionData: Codable {
    let type: String
    let title: String
    let body: String
    let icon: String
    let accentColor: String

    init(from section: CoachingSection) {
        self.type = section.type.rawValue
        self.title = section.title
        self.body = section.body
        self.icon = section.icon
        self.accentColor = section.accentColor
    }

    func toCoachingSection() -> CoachingSection {
        CoachingSection(
            type: SectionType(rawValue: type) ?? .weeklyFocus,
            title: title,
            body: body,
            icon: icon,
            accentColor: accentColor
        )
    }
}