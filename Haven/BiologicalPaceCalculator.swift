import Foundation
import SwiftData

// MARK: - Biological Pace Score (Daily Record)
// Stores one Pace calculation per calendar day.
// Used for trend analysis, history display, and coaching context.

@Model
class BiologicalPaceScore {
    var id: UUID = UUID()
    var date: Date = Date()           // Calendar day (start of day)
    var paceValue: Double = 0.0       // 0.85 to 1.25 (lower = aging slower)
    var confidenceLevel: String = ""  // "full", "limited", "partial"
    
    // Component percentiles (nil if data was missing)
    var sleepPercentile: Double?
    var hrvPercentile: Double?
    var rhrPercentile: Double?
    var vo2MaxPercentile: Double?
    var stepsPercentile: Double?
    var strengthPercentile: Double?
    
    // Raw inputs used (for transparency & debugging)
    var sleepHoursUsed: Double?
    var hrvUsed: Double?
    var rhrUsed: Double?
    var vo2MaxUsed: Double?
    var stepsUsed: Double?
    
    // Composite
    var compositePercentile: Double = 0.0
    var componentsAvailable: Int = 0
    
    // Trend (calculated after historical lookup)
    var trend30Day: Double?           // Change in Pace over 30 days (negative = improving)
    var trendDirection: String?       // "improving", "stable", "declining"
    
    // Strongest/weakest
    var strongestComponent: String?
    var weakestComponent: String?
    
    // Relationship
    var userProfile: UserProfile?
    
    init(date: Date, paceValue: Double, compositePercentile: Double, confidenceLevel: String, componentsAvailable: Int) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.paceValue = paceValue
        self.compositePercentile = compositePercentile
        self.confidenceLevel = confidenceLevel
        self.componentsAvailable = componentsAvailable
    }
    
    /// Populate from a PaceResult
    func populate(from result: PaceResult) {
        self.sleepPercentile = result.sleepPercentile
        self.hrvPercentile = result.hrvPercentile
        self.rhrPercentile = result.rhrPercentile
        self.vo2MaxPercentile = result.vo2MaxPercentile
        self.stepsPercentile = result.stepsPercentile
        self.strengthPercentile = result.strengthPercentile
        
        self.sleepHoursUsed = result.sleepHoursUsed
        self.hrvUsed = result.hrvUsed
        self.rhrUsed = result.rhrUsed
        self.vo2MaxUsed = result.vo2MaxUsed
        self.stepsUsed = result.stepsUsed
        
        self.trend30Day = result.trend30Day
        self.trendDirection = result.trendDirection
        self.strongestComponent = result.strongestComponent
        self.weakestComponent = result.weakestComponent
    }
}