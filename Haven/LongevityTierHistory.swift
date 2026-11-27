import Foundation
import SwiftData

@Model
class LongevityTierHistory {
    var id: UUID = UUID()
    var assessmentDate: Date = Date()
    
    // Tier Results
    var tier: String = ""  // "at_risk", "rising", "phoenix", "optimal", "elite"
    var percentile: Int = 0
    var completenessPercentage: Int = 0
    
    // Component Scores (snapshot at time of assessment)
    var vo2MaxPercentile: Int?
    var strengthPercentile: Int?
    var sleepScore: Int?
    var hrvPercentile: Int?
    var rhrPercentile: Int?
    
    // Raw Values (for reference)
    var vo2MaxValue: Double?
    var sleepAverage: Double?
    var hrvValue: Double?
    var rhrValue: Double?
    
    // Analysis
    var limitingFactor: String?
    var primaryRecommendation: String?
    var missingComponents: String?  // Comma-separated list
    
    // Relationship
    var userProfile: UserProfile?
    
    init(
        assessmentDate: Date,
        tier: String,
        percentile: Int,
        completenessPercentage: Int,
        vo2MaxPercentile: Int? = nil,
        strengthPercentile: Int? = nil,
        sleepScore: Int? = nil,
        hrvPercentile: Int? = nil,
        rhrPercentile: Int? = nil,
        vo2MaxValue: Double? = nil,
        sleepAverage: Double? = nil,
        hrvValue: Double? = nil,
        rhrValue: Double? = nil,
        limitingFactor: String? = nil,
        primaryRecommendation: String? = nil,
        missingComponents: String? = nil
    ) {
        self.id = UUID()
        self.assessmentDate = assessmentDate
        self.tier = tier
        self.percentile = percentile
        self.completenessPercentage = completenessPercentage
        self.vo2MaxPercentile = vo2MaxPercentile
        self.strengthPercentile = strengthPercentile
        self.sleepScore = sleepScore
        self.hrvPercentile = hrvPercentile
        self.rhrPercentile = rhrPercentile
        self.vo2MaxValue = vo2MaxValue
        self.sleepAverage = sleepAverage
        self.hrvValue = hrvValue
        self.rhrValue = rhrValue
        self.limitingFactor = limitingFactor
        self.primaryRecommendation = primaryRecommendation
        self.missingComponents = missingComponents
    }
}