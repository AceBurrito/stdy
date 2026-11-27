import Foundation

struct DaysGainedCalculator {
    
    /// Calculate cumulative days gained since user started.
    /// When pace < 1.0, user is aging slower → gaining days.
    /// When pace > 1.0, we count 0 gained (never show negative).
    static func totalDaysGained(
        paceHistory: [(date: Date, pace: Double)]
    ) -> Double {
        guard paceHistory.count >= 2 else { return 0 }
        
        var totalDays: Double = 0
        
        for i in 1..<paceHistory.count {
            let daysBetween = Calendar.current.dateComponents(
                [.day],
                from: paceHistory[i - 1].date,
                to: paceHistory[i].date
            ).day ?? 0
            
            let pace = paceHistory[i].pace
            if pace < 1.0 {
                totalDays += Double(daysBetween) * (1.0 - pace)
            }
            // pace >= 1.0: 0 gained, no negative
        }
        
        return totalDays
    }
    
    /// Days gained in the current month
    static func daysGainedThisMonth(
        paceHistory: [(date: Date, pace: Double)]
    ) -> Double {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return 0
        }
        
        let thisMonthHistory = paceHistory.filter { $0.date >= monthStart }
        return totalDaysGained(paceHistory: thisMonthHistory)
    }
    
    /// Projected days gained per year at current pace
    static func projectedAnnualDaysGained(currentPace: Double) -> Double {
        guard currentPace < 1.0 else { return 0 }
        return 365.0 * (1.0 - currentPace)
    }
}