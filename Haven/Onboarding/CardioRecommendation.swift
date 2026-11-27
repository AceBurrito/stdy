import Foundation

// MARK: - Cardio Recommendation Engine
// Generates an evidence-based cardio schedule for rest days after
// a strength plan has been assigned.
//
// Default framework (Peter Attia longevity cardio):
//   - 2× Zone 2 (low-intensity aerobic, conversational pace)
//   - 1× VO2 Max intervals (high-intensity)
// Scaled by available rest days.

struct CardioRecommendation {

    struct RecommendedCardioDay {
        let dayOfWeek: Int          // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
        let cardioType: String      // "Zone 2", "VO2 Max", etc.
        let durationMinutes: Int
    }

    // MARK: - Cardio Type Options

    struct CardioTypeOption: Identifiable {
        let id: String
        let name: String
        let defaultDuration: Int

        static let allOptions: [CardioTypeOption] = [
            CardioTypeOption(id: "zone2",   name: "Zone 2",   defaultDuration: 30),
            CardioTypeOption(id: "vo2max",  name: "VO2 Max",  defaultDuration: 25),
            CardioTypeOption(id: "walk",    name: "Walk",      defaultDuration: 30),
            CardioTypeOption(id: "cycle",   name: "Cycle",     defaultDuration: 30),
            CardioTypeOption(id: "row",     name: "Row",       defaultDuration: 20),
            CardioTypeOption(id: "swim",    name: "Swim",      defaultDuration: 30),
            CardioTypeOption(id: "run",     name: "Run",       defaultDuration: 30),
            CardioTypeOption(id: "general", name: "General",   defaultDuration: 30)
        ]

        static func defaultDuration(for typeName: String) -> Int {
            allOptions.first { $0.name == typeName }?.defaultDuration ?? 30
        }
    }

    // MARK: - Duration Options

    static let durationOptions: [Int] = [20, 25, 30, 45, 60]

    // MARK: - Generate Recommendation

    /// Generates a recommended cardio schedule for the remaining rest days
    /// after a strength plan has been assigned.
    static func recommend(restDays: [Int]) -> [RecommendedCardioDay] {
        guard !restDays.isEmpty else { return [] }

        let sorted = restDays.sorted()

        switch sorted.count {
        case 1:
            // 1 rest day — recommend 1 Zone 2 session
            return [
                RecommendedCardioDay(dayOfWeek: sorted[0], cardioType: "Zone 2", durationMinutes: 30)
            ]

        case 2:
            // 2 rest days — 1 Zone 2 + 1 VO2 Max
            return [
                RecommendedCardioDay(dayOfWeek: sorted[0], cardioType: "Zone 2", durationMinutes: 30),
                RecommendedCardioDay(dayOfWeek: sorted[1], cardioType: "VO2 Max", durationMinutes: 25)
            ]

        case 3:
            // 3 rest days — 2 Zone 2 + 1 VO2 Max (optimal longevity cardio)
            return [
                RecommendedCardioDay(dayOfWeek: sorted[0], cardioType: "Zone 2", durationMinutes: 30),
                RecommendedCardioDay(dayOfWeek: sorted[1], cardioType: "VO2 Max", durationMinutes: 25),
                RecommendedCardioDay(dayOfWeek: sorted[2], cardioType: "Zone 2", durationMinutes: 30)
            ]

        default:
            // 4+ rest days — pick 3 most spaced-out days for 2 Zone 2 + 1 VO2 Max
            let selected = pickSpacedDays(from: sorted, count: 3)
            return [
                RecommendedCardioDay(dayOfWeek: selected[0], cardioType: "Zone 2", durationMinutes: 30),
                RecommendedCardioDay(dayOfWeek: selected[1], cardioType: "VO2 Max", durationMinutes: 25),
                RecommendedCardioDay(dayOfWeek: selected[2], cardioType: "Zone 2", durationMinutes: 30)
            ]
        }
    }

    /// Selects N days from available days, maximizing spacing between them.
    private static func pickSpacedDays(from days: [Int], count: Int) -> [Int] {
        guard days.count >= count else { return days }

        if count == 3 && days.count >= 3 {
            // Take first, middle, and last for maximum spread
            return [days[0], days[days.count / 2], days[days.count - 1]]
        }

        return Array(days.prefix(count))
    }
}