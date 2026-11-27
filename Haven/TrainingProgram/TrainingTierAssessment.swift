import Foundation
import SwiftData

// MARK: - Training Tier Assessment

struct TrainingTierAssessment {
    
    // MARK: - Tier Definitions
    enum TrainingTier: Int, CaseIterable {
        case recovery = 0
        case beginner = 1
        case active = 2
        case advanced = 3
        case beastMode = 4
        
        var name: String {
            switch self {
            case .recovery: return "Recovery"
            case .beginner: return "Beginner"
            case .active: return "Active"
            case .advanced: return "Advanced"
            case .beastMode: return "Beast Mode"
            }
        }
        
        var maxNonNegotiables: Int {
            switch self {
            case .recovery: return 2
            case .beginner: return 2
            case .active: return 3
            case .advanced: return 4
            case .beastMode: return 5
            }
        }
        
        var description: String {
            switch self {
            case .recovery:
                return "Focus on healing. Sleep, nutrition, and approved movement only."
            case .beginner:
                return "Building the foundation. Sleep and simple movement habits."
            case .active:
                return "Building consistency. Sleep, protein, and regular training."
            case .advanced:
                return "Optimizing performance. Progressive overload and cardio progression."
            case .beastMode:
                return "Peak optimization. Periodized training and advanced protocols."
            }
        }
    }
    
    // MARK: - Assess Training Tier
    
    /// Assesses the user's training tier based on profile data
    /// Call this during onboarding and during tier reassessment
    static func assess(profile: UserProfile) -> TrainingTier {
        
        // TIER 0 CHECK: Medical restrictions / Recovery
        if shouldBeTierZero(profile: profile) {
            return .recovery
        }
        
        // Get assessment inputs
        let experienceLevel = profile.experienceLevel?.lowercased() ?? ""
        let activityLevel = profile.activityLevel?.lowercased() ?? ""
        let trainingDays = profile.trainingDaysPerWeek ?? 0
        let vo2Max = getLatestVO2Max(profile: profile)
        let sleep = getLatestSleep(profile: profile)
        let hrv = getLatestHRV(profile: profile)
        
        // ⭐ NEW APPROACH: Start with training frequency (respect existing habits)
        var tier = assessBaseTierFromFrequency(trainingDays: trainingDays)
        
        // ⭐ Adjust upward based on experience
        tier = adjustTierForExperience(baseTier: tier, experienceLevel: experienceLevel, activityLevel: activityLevel)
        
        // ⭐ Only downgrade if SEVERE overreaching (don't break existing habits)
        tier = protectFromOverreaching(tier: tier, sleep: sleep, hrv: hrv, vo2Max: vo2Max)
        
        print("📊 Tier Assessment: Days=\(trainingDays), Experience=\(experienceLevel), Result=Tier \(tier.rawValue)")
        
        return tier
    }
    
    // MARK: - New Tier Assessment Logic
    
    /// Step 1: Assign base tier from training frequency (primary factor)
    private static func assessBaseTierFromFrequency(trainingDays: Int) -> TrainingTier {
        if trainingDays >= 5 {
            return .beastMode  // Training 5+ days/week = Beast Mode baseline
        } else if trainingDays >= 4 {
            return .advanced  // 4 days/week = Advanced baseline
        } else if trainingDays >= 3 {
            return .active  // 3 days/week = Active baseline ⭐ YOUR USER
        } else if trainingDays >= 1 {
            return .beginner  // 1-2 days/week = Beginner baseline
        } else {
            return .beginner  // No current training = Beginner
        }
    }
    
    /// Step 2: Adjust tier upward if experience level warrants it
    private static func adjustTierForExperience(
        baseTier: TrainingTier,
        experienceLevel: String,
        activityLevel: String
    ) -> TrainingTier {
        
        // Check for advanced experience indicators
        let isAdvancedExperience = experienceLevel.contains("advanced") ||
                                  experienceLevel.contains("experienced") ||
                                  experienceLevel.contains("1_plus_years") ||
                                  experienceLevel.contains("1+ years") ||
                                  experienceLevel.contains("expert")
        
        // Check for intermediate experience indicators
        let isIntermediateExperience = experienceLevel.contains("intermediate") ||
                                       experienceLevel.contains("6_months") ||
                                       experienceLevel.contains("6 months") ||
                                       experienceLevel.contains("consistent") ||
                                       experienceLevel.contains("regular")
        
        // Check for very active lifestyle
        let isVeryActive = activityLevel.contains("very") || activityLevel.contains("highly")
        
        var adjustedTier = baseTier
        
        // Bump up if experience > frequency suggests
        if isAdvancedExperience && adjustedTier.rawValue < TrainingTier.advanced.rawValue {
            adjustedTier = .advanced
        } else if isIntermediateExperience && adjustedTier.rawValue < TrainingTier.active.rawValue {
            adjustedTier = .active
        }
        
        // Very active lifestyle can bump up one tier
        if isVeryActive && adjustedTier.rawValue < TrainingTier.beastMode.rawValue {
            adjustedTier = TrainingTier(rawValue: adjustedTier.rawValue + 1) ?? adjustedTier
        }
        
        return adjustedTier
    }
    
    /// Step 3: Protect from overreaching - only downgrade if metrics are SEVERELY bad
    private static func protectFromOverreaching(
        tier: TrainingTier,
        sleep: Double?,
        hrv: Double?,
        vo2Max: Double?
    ) -> TrainingTier {
        
        // Only downgrade if showing SEVERE signs of overtraining
        let severeSleepDeprivation = sleep != nil && sleep! < 5.5  // <5.5h = severe
        let severeHRVSuppression = hrv != nil && hrv! < 30  // HRV <30 = severe burnout
        let severeCardiovascularDecline = vo2Max != nil && vo2Max! < 25  // VO2 <25 = very poor
        
        // Must have MULTIPLE severe markers to downgrade
        var severeMarkers = 0
        if severeSleepDeprivation { severeMarkers += 1 }
        if severeHRVSuppression { severeMarkers += 1 }
        if severeCardiovascularDecline { severeMarkers += 1 }
        
        // Only downgrade one tier if 2+ severe markers
        if severeMarkers >= 2 && tier.rawValue > 0 {
            print("⚠️ Downgrading tier due to severe overreaching (sleep: \(sleep ?? 0)h, HRV: \(hrv ?? 0)ms)")
            return TrainingTier(rawValue: tier.rawValue - 1) ?? tier
        }
        
        return tier
    }
    
    // MARK: - Tier Check Functions (DEPRECATED - kept for backwards compatibility)
    
    /// Tier 0: Recovery - Medical restrictions or severe limitations
    private static func shouldBeTierZero(profile: UserProfile) -> Bool {
        let constraints = profile.trainingConstraints?.lowercased() ?? ""
        
        // Check for recovery condition flag
        if let condition = profile.recoveryCondition, !condition.isEmpty {
            return true
        }
        
        // Check for medical keywords in constraints
        let medicalKeywords = [
            "surgery", "post-surgery", "post surgery",
            "recovering", "recovery",
            "doctor", "pt ", "physical therapy",
            "medical", "clearance",
            "wheelchair", "walker",
            "severe", "significant limitation",
            "not cleared", "restricted"
        ]
        
        for keyword in medicalKeywords {
            if constraints.contains(keyword) {
                return true
            }
        }
        
        // Check if explicitly marked as needing clearance but not cleared
        if profile.hasMedicalClearance == false {
            return true
        }
        
        return false
    }
    
    // MARK: - Apply Assessment to Profile
    
    /// Assesses and saves the training tier to the profile
    static func assessAndSave(profile: UserProfile, modelContext: ModelContext) {
        let tier = assess(profile: profile)
        
        profile.trainingTier = tier.rawValue
        profile.trainingTierName = tier.name
        profile.trainingTierAssessedAt = Date()
        
        try? modelContext.save()
        
        print("✅ Training Tier Assessed: \(tier.rawValue) (\(tier.name))")
    }
    
    // MARK: - Tier Progression
    
    /// Check if user qualifies for tier upgrade based on consistency
    static func checkForTierProgression(
        profile: UserProfile,
        weeklyAdherence: Double,
        weeksConsistent: Int,
        modelContext: ModelContext
    ) -> (shouldProgress: Bool, newTier: TrainingTier?, reason: String?) {
        
        guard let currentTier = profile.trainingTier else {
            return (false, nil, nil)
        }
        
        let tier = TrainingTier(rawValue: currentTier) ?? .beginner
        
        // Can't progress beyond Beast Mode
        if tier == .beastMode {
            return (false, nil, nil)
        }
        
        // Can't auto-progress from Recovery - requires medical clearance
        if tier == .recovery {
            if profile.hasMedicalClearance == true {
                return (true, .beginner, "Medical clearance received. Ready to begin training.")
            }
            return (false, nil, nil)
        }
        
        // Progression criteria by tier
        let (requiredWeeks, requiredAdherence) = progressionCriteria(for: tier)
        
        if weeksConsistent >= requiredWeeks && weeklyAdherence >= requiredAdherence {
            let newTier = TrainingTier(rawValue: currentTier + 1)!
            let reason = progressionReason(from: tier, to: newTier, weeks: weeksConsistent)
            return (true, newTier, reason)
        }
        
        return (false, nil, nil)
    }
    
    /// Get progression criteria for each tier
    private static func progressionCriteria(for tier: TrainingTier) -> (weeks: Int, adherence: Double) {
        switch tier {
        case .recovery:
            return (0, 0) // Requires medical clearance, not time-based
        case .beginner:
            return (8, 0.80) // 8 weeks at 80%+ adherence
        case .active:
            return (12, 0.80) // 12 weeks at 80%+ adherence
        case .advanced:
            return (24, 0.85) // 24 weeks (6 months) at 85%+ adherence
        case .beastMode:
            return (0, 0) // Can't progress further
        }
    }
    
    /// Generate progression reason message
    private static func progressionReason(from: TrainingTier, to: TrainingTier, weeks: Int) -> String {
        switch to {
        case .active:
            return "You've been consistent for \(weeks) weeks. Time to build on that foundation."
        case .advanced:
            return "Your consistency is solid. Ready for more structured progression."
        case .beastMode:
            return "Beast Mode Activated. You've earned access to advanced protocols."
        default:
            return "Progressing to \(to.name)."
        }
    }
    
    /// Apply tier progression and save history
    static func applyTierProgression(
        profile: UserProfile,
        newTier: TrainingTier,
        reason: String,
        modelContext: ModelContext
    ) {
        let oldTier = profile.trainingTier ?? 1
        
        // Update profile
        profile.trainingTier = newTier.rawValue
        profile.trainingTierName = newTier.name
        profile.lastTrainingTierReassessmentDate = Date()
        profile.consistentWeeksAtCurrentTier = 0
        
        // Add to progression history
        let historyEntry: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: Date()),
            "fromTier": oldTier,
            "toTier": newTier.rawValue,
            "fromTierName": TrainingTier(rawValue: oldTier)?.name ?? "Unknown",
            "toTierName": newTier.name,
            "reason": reason
        ]
        
        var history: [[String: Any]] = []
        if let existingJSON = profile.tierProgressionHistoryJSON,
           let data = existingJSON.data(using: .utf8),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            history = existing
        }
        history.append(historyEntry)
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: history),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            profile.tierProgressionHistoryJSON = jsonString
        }
        
        try? modelContext.save()
        
        print("🎉 Tier Progression: \(TrainingTier(rawValue: oldTier)?.name ?? "Unknown") → \(newTier.name)")
        print("   Reason: \(reason)")
    }
    
    // MARK: - Helper Functions
    
    /// Get latest VO2 Max from health metrics
    private static func getLatestVO2Max(profile: UserProfile) -> Double? {
        // TODO: Implement if you want VO2-based tier protection
        // For now, return nil to skip this check
        return nil
    }
    
    /// Get latest sleep from health metrics
    private static func getLatestSleep(profile: UserProfile) -> Double? {
        // TODO: Implement if you want sleep-based tier protection
        // For now, return nil to skip this check
        return nil
    }
    
    /// Get latest HRV from health metrics
    private static func getLatestHRV(profile: UserProfile) -> Double? {
        // TODO: Implement if you want HRV-based tier protection
        // For now, return nil to skip this check
        return nil
    }
    
    /// Get tier from profile
    static func getTier(from profile: UserProfile) -> TrainingTier {
        guard let tierValue = profile.trainingTier else {
            return .beginner
        }
        return TrainingTier(rawValue: tierValue) ?? .beginner
    }
}
