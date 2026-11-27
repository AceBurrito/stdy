import Foundation
import SwiftData

/// Small helpers over the model context. The Atlas habit, lesson, streak and
/// check-in helpers were removed in the Steady pivot.
class DataController {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - User Profile
    func getOrCreateUserProfile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()

        if let existingProfile = try? modelContext.fetch(descriptor).first {
            return existingProfile
        }

        let newProfile = UserProfile()
        modelContext.insert(newProfile)

        do {
            try modelContext.save()
            print("✅ Created new user profile")
        } catch {
            print("❌ Failed to create profile: \(error)")
        }

        return newProfile
    }

    // MARK: - Training History

    /// Returns recent PersonalRecords from the last N days.
    func recentPRs(days: Int) -> [PersonalRecord] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate<PersonalRecord> { $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Returns the number of workouts logged in the last N days.
    func workoutCountInLastDays(_ days: Int) -> Int {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return 0 }
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.date >= cutoff }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
}
