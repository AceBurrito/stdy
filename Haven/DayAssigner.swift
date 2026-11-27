import Foundation

// MARK: - Day Assigner
// Assigns template workouts to optimal weekdays based on
// the number of training days. Uses standard spacing patterns
// to avoid back-to-back sessions.

struct DayAssigner {

    // MARK: - Day Assignment Result

    struct DayAssignment {
        let dayOfWeek: Int          // 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
        let workoutName: String
        let workoutType: String     // "strength" or "rest"
        let templateWorkout: TemplateWorkout?
    }

    // MARK: - Spacing Patterns
    // Maps number of training days → which weekdays to use
    // 1=Mon, 2=Tue, ... 6=Sat, 0=Sun
    // These are optimal defaults; users can swap via the day picker

    private static let spacingPatterns: [Int: [Int]] = [
        2: [1, 4],              // Mon, Thu
        3: [1, 3, 5],           // Mon, Wed, Fri
        4: [1, 2, 4, 5],       // Mon, Tue, Thu, Fri
        5: [1, 2, 3, 4, 5],   // Mon-Fri
        6: [1, 2, 3, 4, 5, 6], // Mon-Sat
        7: [0, 1, 2, 3, 4, 5, 6] // Every day
    ]

    // MARK: - Public API

    /// Assigns workouts from a template plan to weekdays using optimal spacing.
    /// Returns a full 7-day week with workouts and rest days.
    static func assignDays(for plan: TrainingPlanTemplate) -> [DayAssignment] {
        let workouts = plan.workouts
        let trainingDays = spacingPatterns[workouts.count] ?? generateSpacing(for: workouts.count)

        var assignments: [DayAssignment] = []

        // Create full 7-day week
        for dayOfWeek in 0...6 {
            if let trainingIndex = trainingDays.firstIndex(of: dayOfWeek) {
                let workoutIndex = trainingIndex
                if workoutIndex < workouts.count {
                    let workout = workouts[workoutIndex]
                    assignments.append(DayAssignment(
                        dayOfWeek: dayOfWeek,
                        workoutName: workout.name,
                        workoutType: "strength",
                        templateWorkout: workout
                    ))
                } else {
                    assignments.append(DayAssignment(
                        dayOfWeek: dayOfWeek,
                        workoutName: "Rest",
                        workoutType: "rest",
                        templateWorkout: nil
                    ))
                }
            } else {
                assignments.append(DayAssignment(
                    dayOfWeek: dayOfWeek,
                    workoutName: "Rest",
                    workoutType: "rest",
                    templateWorkout: nil
                ))
            }
        }

        return assignments
    }

    /// Assigns workouts to specific user-chosen days.
    /// Used when the user swaps days in the preview or picks custom days.
    static func assignToSpecificDays(
        workouts: [TemplateWorkout],
        trainingDays: [Int]
    ) -> [DayAssignment] {
        let sortedDays = trainingDays.sorted()
        var assignments: [DayAssignment] = []

        for dayOfWeek in 0...6 {
            if let index = sortedDays.firstIndex(of: dayOfWeek), index < workouts.count {
                let workout = workouts[index]
                assignments.append(DayAssignment(
                    dayOfWeek: dayOfWeek,
                    workoutName: workout.name,
                    workoutType: "strength",
                    templateWorkout: workout
                ))
            } else {
                assignments.append(DayAssignment(
                    dayOfWeek: dayOfWeek,
                    workoutName: "Rest",
                    workoutType: "rest",
                    templateWorkout: nil
                ))
            }
        }

        return assignments
    }

    /// Assigns custom plan days (strength + cardio mixed).
    /// Used in Build Your Own flow.
    static func assignCustomDays(
        strengthDays: [Int],           // weekday indices for strength
        cardioDays: [Int],             // weekday indices for cardio
        strengthWorkoutNames: [String] // names for each strength day, in order
    ) -> [DayAssignment] {
        let sortedStrength = strengthDays.sorted()
        var assignments: [DayAssignment] = []

        for dayOfWeek in 0...6 {
            if let sIndex = sortedStrength.firstIndex(of: dayOfWeek), sIndex < strengthWorkoutNames.count {
                assignments.append(DayAssignment(
                    dayOfWeek: dayOfWeek,
                    workoutName: strengthWorkoutNames[sIndex],
                    workoutType: "strength",
                    templateWorkout: nil
                ))
            } else if cardioDays.contains(dayOfWeek) {
                assignments.append(DayAssignment(
                    dayOfWeek: dayOfWeek,
                    workoutName: "Cardio",
                    workoutType: "cardio",
                    templateWorkout: nil
                ))
            } else {
                assignments.append(DayAssignment(
                    dayOfWeek: dayOfWeek,
                    workoutName: "Rest",
                    workoutType: "rest",
                    templateWorkout: nil
                ))
            }
        }

        return assignments
    }

    // MARK: - Helpers

    /// Day name from weekday index
    static func dayName(for dayOfWeek: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard dayOfWeek >= 0, dayOfWeek < names.count else { return "?" }
        return names[dayOfWeek]
    }

    /// Full day name from weekday index
    static func fullDayName(for dayOfWeek: Int) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard dayOfWeek >= 0, dayOfWeek < names.count else { return "?" }
        return names[dayOfWeek]
    }

    /// Generate evenly spaced days for non-standard counts
    private static func generateSpacing(for count: Int) -> [Int] {
        guard count > 0, count <= 7 else { return [1, 3, 5] }

        // Distribute across Mon-Sat (1-6), add Sunday only if needed
        var days: [Int] = []
        let weekdays = [1, 2, 3, 4, 5, 6] // Mon-Sat

        if count <= weekdays.count {
            let step = Double(weekdays.count) / Double(count)
            for i in 0..<count {
                let index = Int(Double(i) * step)
                days.append(weekdays[min(index, weekdays.count - 1)])
            }
        } else {
            days = [0, 1, 2, 3, 4, 5, 6]
        }

        return days
    }
}