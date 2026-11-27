import Foundation
import SwiftData

@Model
class LongevityPlan {
    var id: UUID = UUID()
    var phase: Int = 1
    var personalizedRationale: String = ""
    var nonNegotiablesJSON: String = ""
    var trainingScheduleJSON: String = ""
    var createdAt: Date = Date()
    var isActive: Bool = true
    
    // Relationship
    var userProfile: UserProfile?
    
    init(
        phase: Int = 1,
        personalizedRationale: String,
        nonNegotiablesJSON: String,
        trainingScheduleJSON: String
    ) {
        self.id = UUID()
        self.phase = phase
        self.personalizedRationale = personalizedRationale
        self.nonNegotiablesJSON = nonNegotiablesJSON
        self.trainingScheduleJSON = trainingScheduleJSON
        self.createdAt = Date()
        self.isActive = true
    }
}

// MARK: - Parsed Structures (for UI, not stored)

struct NonNegotiable: Codable, Identifiable {
    var id: UUID = UUID()
    let title: String
    let icon: String
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case title, icon, reason
    }
}

struct TrainingDay: Codable, Identifiable {
    var id: UUID = UUID()
    let day: String
    let type: String  // "strength", "cardio", "rest"
    let name: String
    let duration: Int
    
    enum CodingKeys: String, CodingKey {
        case day, type, name, duration
    }
}