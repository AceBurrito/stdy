import Foundation
import SwiftData

// MARK: - Data Transfer Objects (Seed-specific)

struct SeedWeeklyCheckInData {
    let weekNumber: Int
    let date: Date
    let energyLevel: Int?
    let overallRating: Int?
    let biggestWin: String?
    let biggestChallenge: String?
    let sleepAverage: Double?
    let hrvAverage: Double?
    let rhrAverage: Double?
    let habitCompletionRate: Double?
    let aiCoachingFeedback: String?
}

struct SeedHealthMetricData {
    let date: Date
    let sleepDuration: Double?
    let hrv: Double?
    let rhr: Double?
    let vo2Max: Double?
    let weight: Double?
}

struct SeedWorkoutData {
    let date: Date
    let name: String
    let exercises: [SeedExerciseData]
}

struct SeedExerciseData {
    let name: String
    let sets: [SeedSetData]
}

struct SeedSetData {
    let weight: Double?
    let reps: Int
    let isBodyweight: Bool
}

// MARK: - DataSeeder Class

class DataSeeder {
    
    // MARK: - Seed Plan Activation Date
    static func seedPlanActivation(
        profile: UserProfile,
        activationDate: Date,
        modelContext: ModelContext
    ) {
        profile.planActivationDate = activationDate
        profile.onboardingComplete = true
        profile.currentDay = 8
        
        // Calculate current week based on activation date
        let calendar = Calendar.current
        let weeksSinceActivation = calendar.dateComponents([.weekOfYear], from: activationDate, to: Date()).weekOfYear ?? 0
        profile.currentWeek = weeksSinceActivation
        
        // Set week start to most recent Sunday
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday == 1 ? 0 : (weekday - 1)
        if let lastSunday = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) {
            profile.currentWeekStartDate = calendar.startOfDay(for: lastSunday)
        }
        
        try? modelContext.save()
        print("✅ Plan activation backdated to \(activationDate)")
        print("✅ Current week: \(profile.currentWeek)")
    }
    
    // MARK: - Seed Weekly Check-ins
    static func seedWeeklyCheckIns(
        profile: UserProfile,
        checkIns: [SeedWeeklyCheckInData],
        modelContext: ModelContext
    ) {
        for checkInData in checkIns {
            let checkIn = WeeklyCheckIn(weekNumber: checkInData.weekNumber, date: checkInData.date)
            checkIn.userProfile = profile
            
            checkIn.energyLevel = checkInData.energyLevel
            checkIn.overallRating = checkInData.overallRating
            checkIn.biggestWin = checkInData.biggestWin
            checkIn.biggestChallenge = checkInData.biggestChallenge
            
            checkIn.sleepAverage = checkInData.sleepAverage
            checkIn.hrvAverage = checkInData.hrvAverage
            checkIn.rhrAverage = checkInData.rhrAverage
            checkIn.habitCompletionRate = checkInData.habitCompletionRate
            
            checkIn.aiCoachingFeedback = checkInData.aiCoachingFeedback ?? generateMockCoaching(week: checkInData.weekNumber)
            
            modelContext.insert(checkIn)
        }
        
        try? modelContext.save()
        print("✅ Seeded \(checkIns.count) weekly check-ins")
    }
    
    // MARK: - Seed Health Metrics History
    static func seedHealthMetrics(
        profile: UserProfile,
        metrics: [SeedHealthMetricData],
        modelContext: ModelContext
    ) {
        for metricData in metrics {
            let metric = HealthMetrics(date: metricData.date)
            metric.userProfile = profile
            
            metric.sleepDuration = metricData.sleepDuration
            metric.heartRateVariability = metricData.hrv
            metric.restingHeartRate = metricData.rhr
            metric.vo2Max = metricData.vo2Max
            metric.weight = metricData.weight
            
            modelContext.insert(metric)
        }
        
        try? modelContext.save()
        print("✅ Seeded \(metrics.count) health metric entries")
    }
    
    // MARK: - Seed Workout History
    static func seedWorkouts(
        profile: UserProfile,
        workouts: [SeedWorkoutData],
        modelContext: ModelContext
    ) {
        for workoutData in workouts {
            let session = WorkoutSession(date: workoutData.date, workoutName: workoutData.name)
            session.userProfile = profile
            
            for (index, exerciseData) in workoutData.exercises.enumerated() {
                let exercise = Exercise(name: exerciseData.name, orderIndex: index)
                exercise.workoutSession = session
                
                for (setIndex, setData) in exerciseData.sets.enumerated() {
                    let set = WorkoutSet(
                        setNumber: setIndex + 1,
                        weight: setData.weight,
                        reps: setData.reps,
                        isBodyweight: setData.isBodyweight
                    )
                    set.exercise = exercise
                    exercise.sets.append(set)
                }
                
                modelContext.insert(exercise)
                session.exercises.append(exercise)
            }
            
            modelContext.insert(session)
        }
        
        try? modelContext.save()
        print("✅ Seeded \(workouts.count) workouts")
    }
    
    // MARK: - Generate Mock Coaching (fallback)
    static func generateMockCoaching(week: Int) -> String {
        return """
        Week \(week) shows solid consistency. Your metrics are trending in the right direction. Sleep is stable at your target range, and HRV is recovering well. Keep focusing on the fundamentals - progressive overload on your lifts, consistent cardio work, and maintaining that sleep schedule. You're building a strong foundation here.
        """
    }
}