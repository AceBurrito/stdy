import Foundation
import SwiftData

// MARK: - Deload Detector
// Sprint B, Item 7: Automatic Deload Detection
//
// Rule-based detector that flags when a user needs a recovery week.
// Feeds into weekly check-in AI analysis and Sunday commit card.
//
// DESIGN PRINCIPLE: Deload is a TEMPORARY OVERLAY — it does NOT modify
// the underlying training program, does NOT break habit streaks, and
// the following week snaps back to the normal plan. Think of it as a
// "recovery lens" on the same week's workouts.

struct DeloadDetector {
    
    // MARK: - Result Types
    
    struct DeloadRecommendation {
        let reason: DeloadReason
        let severity: DeloadSeverity
        let message: String
        let coachingContext: String  // Injected into AI system prompt
        let volumeReduction: Double // 0.0 to 1.0 — e.g., 0.50 means 50% volume
    }
    
    enum DeloadReason: String {
        case hrvDecline       // HRV dropping >15% over 2 weeks with high adherence
        case scheduled        // 5+ weeks without a deload and consistent training
        case userRequested    // User explicitly asked for recovery (future use)
    }
    
    enum DeloadSeverity: String {
        case suggested   // "You might want to consider..."
        case recommended // "Your body is telling you to back off."
    }
    
    // MARK: - Detection Thresholds
    
    private struct Thresholds {
        /// HRV must decline by more than this percentage over 2 weeks to trigger
        static let hrvDeclinePercent: Double = 0.15  // 15%
        
        /// Adherence must be above this to confirm they're training hard (not just skipping)
        static let minAdherenceForHRVTrigger: Double = 0.80  // 80%
        
        /// Weeks of consistent training before scheduled deload triggers
        static let scheduledDeloadWeeks: Int = 5
        
        /// Minimum adherence to count as "consistent training" for scheduled deload
        static let minAdherenceForScheduled: Double = 0.75  // 75%
        
        /// HRV decline that warrants a "watch" note (not full deload, but close)
        static let hrvWatchPercent: Double = 0.10  // 10%
        
        /// Volume reduction during deload (50% = same exercises, half the sets)
        static let deloadVolumeReduction: Double = 0.50
        
        /// Minimum days of HRV data required per week for reliable trend
        static let minHRVDataPointsPerWeek: Int = 3
    }
    
    // MARK: - Primary Detection Method
    
    /// Evaluates whether a deload should be recommended.
    /// Call this during weekly check-in analysis.
    ///
    /// - Parameters:
    ///   - profile: The user's profile
    ///   - recentMetrics: Last 21+ days of HealthMetrics (sorted newest first)
    ///   - recentCheckIns: Last 4-6 WeeklyCheckIns for adherence history
    ///   - activeProgram: The user's active TrainingProgram (if any)
    /// - Returns: A DeloadRecommendation if deload is warranted, nil otherwise
    static func evaluate(
        profile: UserProfile,
        recentMetrics: [HealthMetrics],
        recentCheckIns: [WeeklyCheckIn],
        activeProgram: TrainingProgram?
    ) -> DeloadRecommendation? {
        
        // Get the current periodization phase (if event training)
        let currentPhase = getCurrentPhase(profile: profile, program: activeProgram)
        
        // Never recommend deload during Taper — volume is already reduced
        if currentPhase?.lowercased() == "taper" {
            return nil
        }
        
        // Calculate HRV trend
        let hrvTrend = calculateHRVTrend(from: recentMetrics)
        
        // Calculate recent training adherence (last 2 weeks)
        let recentAdherence = calculateRecentAdherence(from: recentCheckIns, weeks: 2)
        
        // Calculate weeks since last deload
        let weeksSinceDeload = calculateWeeksSinceLastDeload(profile: profile)
        
        // ──────────────────────────────────────────────
        // RULE 1: HRV Decline Detection
        // HRV dropping >15% over 2 weeks
        // AND adherence >80% (training hard, not skipping)
        // AND in Build or Peak phase (or general training)
        // ──────────────────────────────────────────────
        
        if let twoWeekChange = hrvTrend.twoWeekChangePercent,
           twoWeekChange < -Thresholds.hrvDeclinePercent,
           recentAdherence > Thresholds.minAdherenceForHRVTrigger,
           isTrainingPhaseEligibleForDeload(currentPhase) {
            
            let declinePercent = Int(abs(twoWeekChange) * 100)
            
            return DeloadRecommendation(
                reason: .hrvDecline,
                severity: .recommended,
                message: "Your HRV has dropped \(declinePercent)% over two weeks despite solid training adherence. Your body is absorbing load but not recovering. Next week should be a deload — same exercises, \(Int(Thresholds.deloadVolumeReduction * 100))% volume. This isn't a setback — it's how you absorb the training you've done.",
                coachingContext: buildHRVDeloadContext(
                    hrvTrend: hrvTrend,
                    adherence: recentAdherence,
                    phase: currentPhase,
                    weeksSinceDeload: weeksSinceDeload
                ),
                volumeReduction: Thresholds.deloadVolumeReduction
            )
        }
        
        // ──────────────────────────────────────────────
        // RULE 2: Scheduled Deload
        // 5+ weeks of consistent training without a deload
        // AND adherence >75%
        // ──────────────────────────────────────────────
        
        if weeksSinceDeload >= Thresholds.scheduledDeloadWeeks,
           recentAdherence > Thresholds.minAdherenceForScheduled {
            
            return DeloadRecommendation(
                reason: .scheduled,
                severity: .suggested,
                message: "You've been training consistently for \(weeksSinceDeload) weeks. A planned deload week helps your body consolidate gains — same exercises, reduced volume. Think of it as letting the concrete set.",
                coachingContext: buildScheduledDeloadContext(
                    weeksSinceDeload: weeksSinceDeload,
                    adherence: recentAdherence,
                    phase: currentPhase
                ),
                volumeReduction: Thresholds.deloadVolumeReduction
            )
        }
        
        return nil
    }
    
    // MARK: - HRV Trend Calculation
    
    struct HRVTrend {
        let thisWeekAvg: Double?
        let lastWeekAvg: Double?
        let twoWeeksAgoAvg: Double?
        let twoWeekChangePercent: Double?  // Negative = decline
        let oneWeekChangePercent: Double?
        let dataQuality: DataQuality
        
        enum DataQuality {
            case sufficient    // 3+ data points per week
            case limited       // Some data but sparse
            case insufficient  // Not enough to make a call
        }
    }
    
    private static func calculateHRVTrend(from metrics: [HealthMetrics]) -> HRVTrend {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var thisWeekHRV: [Double] = []
        var lastWeekHRV: [Double] = []
        var twoWeeksAgoHRV: [Double] = []
        
        for metric in metrics {
            guard let hrv = metric.heartRateVariability, hrv > 0 else { continue }
            let daysDiff = calendar.dateComponents([.day], from: metric.date, to: today).day ?? 0
            
            if daysDiff >= 0 && daysDiff < 7 {
                thisWeekHRV.append(hrv)
            } else if daysDiff >= 7 && daysDiff < 14 {
                lastWeekHRV.append(hrv)
            } else if daysDiff >= 14 && daysDiff < 21 {
                twoWeeksAgoHRV.append(hrv)
            }
        }
        
        // Determine data quality
        let dataQuality: HRVTrend.DataQuality
        if thisWeekHRV.count >= Thresholds.minHRVDataPointsPerWeek &&
            lastWeekHRV.count >= Thresholds.minHRVDataPointsPerWeek {
            dataQuality = .sufficient
        } else if !thisWeekHRV.isEmpty && !lastWeekHRV.isEmpty {
            dataQuality = .limited
        } else {
            dataQuality = .insufficient
        }
        
        let thisWeekAvg = thisWeekHRV.isEmpty ? nil : thisWeekHRV.reduce(0, +) / Double(thisWeekHRV.count)
        let lastWeekAvg = lastWeekHRV.isEmpty ? nil : lastWeekHRV.reduce(0, +) / Double(lastWeekHRV.count)
        let twoWeeksAgoAvg = twoWeeksAgoHRV.isEmpty ? nil : twoWeeksAgoHRV.reduce(0, +) / Double(twoWeeksAgoHRV.count)
        
        // Calculate percentage changes
        var twoWeekChange: Double? = nil
        if let current = thisWeekAvg, let baseline = twoWeeksAgoAvg, baseline > 0 {
            twoWeekChange = (current - baseline) / baseline
        }
        
        var oneWeekChange: Double? = nil
        if let current = thisWeekAvg, let previous = lastWeekAvg, previous > 0 {
            oneWeekChange = (current - previous) / previous
        }
        
        return HRVTrend(
            thisWeekAvg: thisWeekAvg,
            lastWeekAvg: lastWeekAvg,
            twoWeeksAgoAvg: twoWeeksAgoAvg,
            twoWeekChangePercent: twoWeekChange,
            oneWeekChangePercent: oneWeekChange,
            dataQuality: dataQuality
        )
    }
    
    // MARK: - Adherence Calculation
    
    private static func calculateRecentAdherence(from checkIns: [WeeklyCheckIn], weeks: Int) -> Double {
        // checkIns are sorted newest first
        let recent = Array(checkIns.prefix(weeks))
        guard !recent.isEmpty else { return 0.0 }
        
        let rates = recent.compactMap { $0.habitCompletionRate }
        guard !rates.isEmpty else { return 0.0 }
        
        return rates.reduce(0, +) / Double(rates.count)
    }
    
    // MARK: - Weeks Since Last Deload
    
    private static func calculateWeeksSinceLastDeload(profile: UserProfile) -> Int {
        guard let lastDeload = profile.lastDeloadWeekDate else {
            // No deload ever recorded — use plan activation date or current week
            if let activationDate = profile.planActivationDate {
                return Calendar.current.dateComponents([.weekOfYear], from: activationDate, to: Date()).weekOfYear ?? 0
            }
            // Fallback to currentWeek
            return profile.currentWeek ?? 0
        }
        
        return Calendar.current.dateComponents([.weekOfYear], from: lastDeload, to: Date()).weekOfYear ?? 0
    }
    
    // MARK: - Phase Helpers
    
    private static func getCurrentPhase(profile: UserProfile, program: TrainingProgram?) -> String? {
        guard profile.isTrainingForEvent, let program = program else { return nil }
        return program.phaseName(for: profile.currentEventWeek)
    }
    
    private static func isTrainingPhaseEligibleForDeload(_ phase: String?) -> Bool {
        // Deload is appropriate during Build, Peak, or general training
        // NOT during Taper (already reduced) or Base (too early to need it usually)
        guard let phase = phase?.lowercased() else { return true } // Non-event users always eligible
        return phase == "build" || phase == "peak" || phase == "training"
    }
    
    // MARK: - Coaching Context Builders
    
    private static func buildHRVDeloadContext(
        hrvTrend: HRVTrend,
        adherence: Double,
        phase: String?,
        weeksSinceDeload: Int
    ) -> String {
        var context = """
        ## DELOAD RECOMMENDATION (HRV-TRIGGERED)
        
        Status: RECOMMENDED — HRV decline detected with high training adherence.
        
        HRV Data:
        """
        
        if let current = hrvTrend.thisWeekAvg {
            context += "\n  This week avg: \(String(format: "%.0f", current)) ms"
        }
        if let last = hrvTrend.lastWeekAvg {
            context += "\n  Last week avg: \(String(format: "%.0f", last)) ms"
        }
        if let twoWeeks = hrvTrend.twoWeeksAgoAvg {
            context += "\n  Two weeks ago avg: \(String(format: "%.0f", twoWeeks)) ms"
        }
        if let change = hrvTrend.twoWeekChangePercent {
            context += "\n  2-week decline: \(String(format: "%.0f", abs(change) * 100))%"
        }
        
        context += """
        
        
        Training adherence (2 weeks): \(Int(adherence * 100))%
        Weeks since last deload: \(weeksSinceDeload)
        """
        
        if let phase = phase {
            context += "\n  Current phase: \(phase)"
        }
        
        context += """
        
        
        Coaching guidance:
        - Acknowledge their hard work — high adherence is the REASON the deload is needed
        - Explain this is a sign of productive training, not failure
        - Recommend: Same exercises, 50% volume (fewer sets, same weight and reps)
        - Frame it: "Your body builds muscle and fitness DURING recovery, not during the workout"
        - This is a temporary overlay — next week returns to normal programming
        - Do NOT reduce their habit expectations or break their streak
        - If they're training for an event, reassure them this won't set them back
        """
        
        return context
    }
    
    private static func buildScheduledDeloadContext(
        weeksSinceDeload: Int,
        adherence: Double,
        phase: String?
    ) -> String {
        var context = """
        ## DELOAD RECOMMENDATION (SCHEDULED)
        
        Status: SUGGESTED — \(weeksSinceDeload) consecutive weeks of consistent training.
        
        Training adherence (recent): \(Int(adherence * 100))%
        Weeks since last deload: \(weeksSinceDeload)
        """
        
        if let phase = phase {
            context += "\n  Current phase: \(phase)"
        }
        
        context += """
        
        
        Coaching guidance:
        - Frame as proactive recovery, not reactive
        - "Every 4-6 weeks of hard training, a deload week lets your body consolidate gains"
        - Recommend: Same exercises, 50% volume
        - This is less urgent than HRV-triggered — user can choose to push through one more week
        - Present as a suggestion, not a mandate
        - If they decline, note it and monitor HRV closely next week
        - This is a temporary overlay — next week returns to normal programming
        """
        
        return context
    }
    
    // MARK: - Deload Week Status Check
    
    /// Check if the user is currently in a deload week.
    /// Used by TodayView and TrainingProgramView to show deload overlay.
    static func isCurrentlyInDeloadWeek(profile: UserProfile) -> Bool {
        guard let deloadDate = profile.lastDeloadWeekDate else { return false }
        let calendar = Calendar.current
        let daysSinceDeload = calendar.dateComponents([.day], from: deloadDate, to: Date()).day ?? 99
        // Deload week lasts 7 days from when it was accepted
        return daysSinceDeload >= 0 && daysSinceDeload < 7
    }
    
    /// Returns the volume reduction multiplier for the current deload.
    /// Returns 1.0 (no reduction) if not in deload.
    static func currentVolumeMultiplier(profile: UserProfile) -> Double {
        if isCurrentlyInDeloadWeek(profile: profile) {
            return Thresholds.deloadVolumeReduction
        }
        return 1.0
    }
    
    // MARK: - Record Deload
    
    /// Call when user accepts a deload recommendation.
    /// Sets the lastDeloadWeekDate on the profile.
    static func acceptDeload(profile: UserProfile) {
        profile.lastDeloadWeekDate = Date()
    }
}