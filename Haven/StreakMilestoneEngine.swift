import Foundation
import SwiftData

// MARK: - Streak Milestone

struct StreakMilestone {
    let days: Int
    let name: String
    let celebrationType: String  // "toast", "card", "fullscreen"
}

// MARK: - Streak Milestone Engine

struct StreakMilestoneEngine {
    static let milestones: [StreakMilestone] = [
        StreakMilestone(days: 3,   name: "Building",       celebrationType: "toast"),
        StreakMilestone(days: 7,   name: "One Week",       celebrationType: "card"),
        StreakMilestone(days: 14,  name: "Two Weeks",      celebrationType: "card"),
        StreakMilestone(days: 21,  name: "Habit Formed",   celebrationType: "fullscreen"),
        StreakMilestone(days: 30,  name: "Unbreakable",    celebrationType: "fullscreen"),
        StreakMilestone(days: 50,  name: "Elite",          celebrationType: "fullscreen"),
        StreakMilestone(days: 100, name: "Century",        celebrationType: "fullscreen"),
    ]

    /// Returns the milestone to celebrate, or nil if no new milestone.
    /// Only fires once per threshold — uses profile.lastCelebratedStreakMilestone to track.
    static func checkForMilestone(currentStreak: Int, profile: UserProfile) -> StreakMilestone? {
        // Find the highest milestone the streak qualifies for that hasn't been celebrated
        let eligible = milestones
            .filter { $0.days <= currentStreak && $0.days > profile.lastCelebratedStreakMilestone }
            .max(by: { $0.days < $1.days })

        return eligible
    }

    /// Call after displaying the celebration to prevent re-triggering.
    static func markCelebrated(milestone: StreakMilestone, profile: UserProfile) {
        profile.lastCelebratedStreakMilestone = milestone.days
    }

    /// If streak broke (reset to 0), reset milestone tracker so celebrations can fire on the next streak.
    static func handleStreakReset(currentStreak: Int, profile: UserProfile) {
        if currentStreak == 0 && profile.lastCelebratedStreakMilestone > 0 {
            profile.lastCelebratedStreakMilestone = 0
        }
    }
}