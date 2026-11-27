// ProfileOptions.swift
// Steady — the fixed choices a user makes about themselves (goal, experience,
// equipment). Stored on UserProfile as plain strings for CloudKit safety;
// these enums are the single place that maps them to labels.

import Foundation

// MARK: - Goal

enum SteadyGoal: String, CaseIterable, Identifiable {
    case loseFat = "lose_fat"
    case buildMuscle = "build_muscle"
    case recomp = "recomp"
    case maintain = "maintain"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseFat: return "Lose Fat"
        case .buildMuscle: return "Build Muscle"
        case .recomp: return "Recomp"
        case .maintain: return "Maintain"
        }
    }

    var subtitle: String {
        switch self {
        case .loseFat: return "Drop body fat, keep the muscle you have."
        case .buildMuscle: return "Add size and strength. Some fat gain is fine."
        case .recomp: return "Lose fat and gain muscle at the same time."
        case .maintain: return "Hold your current body. Keep getting stronger."
        }
    }

    var icon: String {
        switch self {
        case .loseFat: return "arrow.down.right"
        case .buildMuscle: return "arrow.up.right"
        case .recomp: return "arrow.left.arrow.right"
        case .maintain: return "equal"
        }
    }

    /// Display name for any stored goal string, including legacy Atlas goals.
    static func displayName(for raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Not set" }
        if let goal = SteadyGoal(rawValue: raw) { return goal.title }
        return raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Experience

enum SteadyExperience: String, CaseIterable, Identifiable {
    case beginner, intermediate, advanced

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var subtitle: String {
        switch self {
        case .beginner: return "Under a year of consistent lifting."
        case .intermediate: return "1–3 years. You know the main lifts."
        case .advanced: return "3+ years. Progress takes planning."
        }
    }
}

// MARK: - Equipment

/// Stored in UserProfile.availableEquipment as `title`, which
/// PlanRecommendationEngine.mapEquipment parses.
enum SteadyEquipment: String, CaseIterable, Identifiable {
    case bodyweight, dumbbells, fullGym

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyweight: return "Bodyweight"
        case .dumbbells: return "Dumbbells"
        case .fullGym: return "Full Gym"
        }
    }

    var subtitle: String {
        switch self {
        case .bodyweight: return "No equipment, or a pull-up bar."
        case .dumbbells: return "Adjustable dumbbells or a home setup."
        case .fullGym: return "Barbells, racks, cables, machines."
        }
    }

    var icon: String {
        switch self {
        case .bodyweight: return "figure.cooldown"
        case .dumbbells: return "dumbbell"
        case .fullGym: return "figure.strengthtraining.traditional"
        }
    }

    /// Best match for a stored free-text equipment string.
    static func from(_ raw: String?) -> SteadyEquipment {
        switch PlanRecommendationEngine.mapEquipment(raw) {
        case .bodyweight: return .bodyweight
        case .dumbbells: return .dumbbells
        case .fullGym: return .fullGym
        }
    }
}
