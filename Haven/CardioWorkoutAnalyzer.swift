import Foundation
import HealthKit

// MARK: - Cardio Activity Types

enum CardioActivityType: String, Codable, CaseIterable {
    case zone2 = "Zone 2"
    case vo2max = "VO2 Max"
    case hybrid = "Hybrid"
    case walk = "Walk"
    case cycle = "Cycle"
    case row = "Row"
    case swim = "Swim"
    case hike = "Hike"
    case generalCardio = "Cardio"

    var icon: String {
        switch self {
        case .zone2: return "heart.fill"
        case .vo2max: return "bolt.heart.fill"
        case .hybrid: return "waveform.path.ecg"
        case .walk: return "figure.walk"
        case .cycle: return "figure.outdoor.cycle"
        case .row: return "figure.rower"
        case .swim: return "figure.pool.swim"
        case .hike: return "figure.hiking"
        case .generalCardio: return "heart.circle.fill"
        }
    }

    var displayColor: String {
        switch self {
        case .zone2: return "atlasPrimary"
        case .vo2max: return "orange"
        case .hybrid: return "purple"
        case .walk: return "green"
        case .cycle: return "blue"
        case .row: return "cyan"
        case .swim: return "blue"
        case .hike: return "green"
        case .generalCardio: return "gray"
        }
    }
}

// MARK: - HR Sample

struct HRSample {
    let timestamp: Date
    let bpm: Double
}

// MARK: - Zone Breakdown

struct ZoneBreakdown: Codable {
    let zone1Seconds: Double
    let zone2Seconds: Double
    let zone3Seconds: Double
    let zone4Seconds: Double
    let zone5Seconds: Double
    let totalSeconds: Double

    var zone1Percent: Double { totalSeconds > 0 ? zone1Seconds / totalSeconds : 0 }
    var zone2Percent: Double { totalSeconds > 0 ? zone2Seconds / totalSeconds : 0 }
    var zone3Percent: Double { totalSeconds > 0 ? zone3Seconds / totalSeconds : 0 }
    var zone4Percent: Double { totalSeconds > 0 ? zone4Seconds / totalSeconds : 0 }
    var zone5Percent: Double { totalSeconds > 0 ? zone5Seconds / totalSeconds : 0 }

    var zone1Minutes: Int { Int(zone1Seconds / 60) }
    var zone2Minutes: Int { Int(zone2Seconds / 60) }
    var zone3Minutes: Int { Int(zone3Seconds / 60) }
    var zone4Minutes: Int { Int(zone4Seconds / 60) }
    var zone5Minutes: Int { Int(zone5Seconds / 60) }

    static let empty = ZoneBreakdown(
        zone1Seconds: 0, zone2Seconds: 0, zone3Seconds: 0,
        zone4Seconds: 0, zone5Seconds: 0, totalSeconds: 0
    )
}

// MARK: - Detected Interval

struct DetectedInterval: Codable {
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let peakHR: Double
    let avgHR: Double
    let zone: Int
    let recoveryAfter: RecoveryData?
}

// MARK: - Recovery Data

struct RecoveryData: Codable {
    let peakHR: Double
    let hrAt30Sec: Double?
    let hrAt60Sec: Double?
    let hrAt90Sec: Double?
    let dropIn60Sec: Double?
}

// MARK: - Workout Analysis Result

struct WorkoutAnalysisResult {
    let activityType: CardioActivityType
    let zoneBreakdown: ZoneBreakdown
    let intervals: [DetectedInterval]
    let postWorkoutRecoveryHR: Double?
    let postWorkoutRecoveryDrop: Double?
    let feedback: String
}

// MARK: - CardioWorkoutAnalyzer

struct CardioWorkoutAnalyzer {

    // MARK: - Full Analysis Pipeline

    /// Analyze HR samples for a workout and produce a complete analysis result.
    static func analyze(
        samples: [HRSample],
        zones: HeartRateZones,
        duration: Int, // minutes
        workoutType: HKWorkoutActivityType?,
        maxHeartRate: Double?,
        allSamplesIncludingPostWorkout: [HRSample]? = nil,
        workoutEndDate: Date? = nil
    ) -> WorkoutAnalysisResult {
        let breakdown = calculateZoneBreakdown(samples: samples, zones: zones)
        let activityType = classifyWorkout(
            breakdown: breakdown,
            hkType: workoutType
        )
        let intervals = detectIntervals(samples: samples, zones: zones)

        // Post-workout recovery
        var recoveryHR: Double? = nil
        var recoveryDrop: Double? = nil
        if let postSamples = allSamplesIncludingPostWorkout,
           let endDate = workoutEndDate,
           let peakHR = maxHeartRate {
            let recovery = calculatePostWorkoutRecovery(
                peakHR: peakHR,
                workoutEndTime: endDate,
                postSamples: postSamples
            )
            recoveryHR = recovery.hrAt60Sec
            if let hr60 = recovery.hrAt60Sec {
                recoveryDrop = peakHR - hr60
            }
        }

        let feedback = generateFeedback(
            activityType: activityType,
            breakdown: breakdown,
            intervals: intervals,
            zones: zones,
            duration: duration,
            recoveryDrop: recoveryDrop
        )

        return WorkoutAnalysisResult(
            activityType: activityType,
            zoneBreakdown: breakdown,
            intervals: intervals,
            postWorkoutRecoveryHR: recoveryHR,
            postWorkoutRecoveryDrop: recoveryDrop,
            feedback: feedback
        )
    }

    // MARK: - Zone Breakdown Calculation

    static func calculateZoneBreakdown(samples: [HRSample], zones: HeartRateZones) -> ZoneBreakdown {
        guard samples.count >= 2 else { return .empty }

        var zoneTimes: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]

        for i in 0..<(samples.count - 1) {
            let current = samples[i]
            let next = samples[i + 1]
            let duration = next.timestamp.timeIntervalSince(current.timestamp)

            // Skip gaps longer than 30 seconds (sensor dropout)
            guard duration > 0 && duration < 30 else { continue }

            let zone = CardioZoneCalculator.determineZone(heartRate: Int(current.bpm), zones: zones)
            zoneTimes[zone, default: 0] += duration
        }

        let total = zoneTimes.values.reduce(0, +)

        return ZoneBreakdown(
            zone1Seconds: zoneTimes[1] ?? 0,
            zone2Seconds: zoneTimes[2] ?? 0,
            zone3Seconds: zoneTimes[3] ?? 0,
            zone4Seconds: zoneTimes[4] ?? 0,
            zone5Seconds: zoneTimes[5] ?? 0,
            totalSeconds: total
        )
    }

    // MARK: - Workout Classification

    static func classifyWorkout(
        breakdown: ZoneBreakdown,
        hkType: HKWorkoutActivityType?
    ) -> CardioActivityType {
        // First check HealthKit activity type for non-running activities
        if let hkType = hkType {
            switch hkType {
            case .walking:
                return .walk
            case .cycling, .handCycling:
                return .cycle
            case .rowing, .paddleSports:
                return .row
            case .swimming:
                return .swim
            case .hiking:
                return .hike
            default:
                break // Fall through to zone-based classification
            }
        }

        // Zone-based classification for running and general workouts
        return classifyByZoneDistribution(breakdown)
    }

    static func classifyByZoneDistribution(_ breakdown: ZoneBreakdown) -> CardioActivityType {
        guard breakdown.totalSeconds > 0 else { return .generalCardio }

        let zone2Pct = breakdown.zone2Percent
        let zone4And5Pct = breakdown.zone4Percent + breakdown.zone5Percent

        if zone2Pct > 0.70 {
            return .zone2
        } else if zone4And5Pct > 0.30 {
            if zone2Pct > 0.25 {
                return .hybrid
            }
            return .vo2max
        } else {
            return .hybrid
        }
    }

    // MARK: - Interval Detection

    static func detectIntervals(samples: [HRSample], zones: HeartRateZones) -> [DetectedInterval] {
        guard samples.count >= 2 else { return [] }

        var intervals: [DetectedInterval] = []
        let zone4Threshold = Double(zones.zone4.min)
        let zone5Threshold = Double(zones.zone5.min)

        var inInterval = false
        var intervalStart: Date?
        var intervalSamples: [HRSample] = []
        var belowThresholdCount = 0

        for sample in samples {
            if sample.bpm >= zone4Threshold {
                if !inInterval {
                    inInterval = true
                    intervalStart = sample.timestamp
                    intervalSamples = []
                    belowThresholdCount = 0
                }
                intervalSamples.append(sample)
                belowThresholdCount = 0
            } else if inInterval {
                belowThresholdCount += 1
                intervalSamples.append(sample)

                // HR dropped for ~15+ seconds (4 samples at ~3-5s each)
                if belowThresholdCount >= 4 {
                    if let start = intervalStart, !intervalSamples.isEmpty {
                        let duration = intervalSamples.last!.timestamp.timeIntervalSince(start)
                        if duration >= 20 { // At least 20 seconds
                            let peakHR = intervalSamples.map(\.bpm).max() ?? 0
                            let avgHR = intervalSamples.map(\.bpm).reduce(0, +) / Double(intervalSamples.count)

                            let recovery = calculateIntervalRecovery(
                                peakHR: peakHR,
                                intervalEndTime: intervalSamples.last!.timestamp,
                                allSamples: samples
                            )

                            intervals.append(DetectedInterval(
                                startTime: start,
                                endTime: intervalSamples.last!.timestamp,
                                duration: duration,
                                peakHR: peakHR,
                                avgHR: avgHR,
                                zone: peakHR >= zone5Threshold ? 5 : 4,
                                recoveryAfter: recovery
                            ))
                        }
                    }
                    inInterval = false
                    intervalSamples = []
                }
            }
        }

        // Handle workout ending during an interval
        if inInterval, let start = intervalStart, !intervalSamples.isEmpty {
            let duration = intervalSamples.last!.timestamp.timeIntervalSince(start)
            if duration >= 20 {
                let peakHR = intervalSamples.map(\.bpm).max() ?? 0
                let avgHR = intervalSamples.map(\.bpm).reduce(0, +) / Double(intervalSamples.count)

                intervals.append(DetectedInterval(
                    startTime: start,
                    endTime: intervalSamples.last!.timestamp,
                    duration: duration,
                    peakHR: peakHR,
                    avgHR: avgHR,
                    zone: peakHR >= zone5Threshold ? 5 : 4,
                    recoveryAfter: nil
                ))
            }
        }

        return intervals
    }

    // MARK: - Recovery Between Intervals

    private static func calculateIntervalRecovery(
        peakHR: Double,
        intervalEndTime: Date,
        allSamples: [HRSample]
    ) -> RecoveryData {
        let samplesAfter = allSamples.filter { $0.timestamp > intervalEndTime }

        let hrAt30 = samplesAfter.first(where: {
            let elapsed = $0.timestamp.timeIntervalSince(intervalEndTime)
            return elapsed >= 25 && elapsed <= 35
        })?.bpm

        let hrAt60 = samplesAfter.first(where: {
            let elapsed = $0.timestamp.timeIntervalSince(intervalEndTime)
            return elapsed >= 55 && elapsed <= 65
        })?.bpm

        let hrAt90 = samplesAfter.first(where: {
            let elapsed = $0.timestamp.timeIntervalSince(intervalEndTime)
            return elapsed >= 85 && elapsed <= 95
        })?.bpm

        return RecoveryData(
            peakHR: peakHR,
            hrAt30Sec: hrAt30,
            hrAt60Sec: hrAt60,
            hrAt90Sec: hrAt90,
            dropIn60Sec: hrAt60 != nil ? peakHR - hrAt60! : nil
        )
    }

    // MARK: - Post-Workout Recovery

    static func calculatePostWorkoutRecovery(
        peakHR: Double,
        workoutEndTime: Date,
        postSamples: [HRSample]
    ) -> RecoveryData {
        let relevant = postSamples.filter {
            $0.timestamp > workoutEndTime &&
            $0.timestamp <= workoutEndTime.addingTimeInterval(180)
        }

        let hrAt30 = relevant.first(where: {
            let elapsed = $0.timestamp.timeIntervalSince(workoutEndTime)
            return elapsed >= 25 && elapsed <= 35
        })?.bpm

        let hrAt60 = relevant.first(where: {
            let elapsed = $0.timestamp.timeIntervalSince(workoutEndTime)
            return elapsed >= 55 && elapsed <= 65
        })?.bpm

        let hrAt90 = relevant.first(where: {
            let elapsed = $0.timestamp.timeIntervalSince(workoutEndTime)
            return elapsed >= 85 && elapsed <= 95
        })?.bpm

        return RecoveryData(
            peakHR: peakHR,
            hrAt30Sec: hrAt30,
            hrAt60Sec: hrAt60,
            hrAt90Sec: hrAt90,
            dropIn60Sec: hrAt60 != nil ? peakHR - hrAt60! : nil
        )
    }

    // MARK: - Deterministic Feedback Generation

    static func generateFeedback(
        activityType: CardioActivityType,
        breakdown: ZoneBreakdown,
        intervals: [DetectedInterval],
        zones: HeartRateZones,
        duration: Int,
        recoveryDrop: Double?
    ) -> String {
        switch activityType {
        case .zone2:
            return generateZone2Feedback(breakdown: breakdown, duration: duration)
        case .vo2max:
            return generateVO2MaxFeedback(breakdown: breakdown, intervals: intervals, recoveryDrop: recoveryDrop)
        case .hybrid:
            return generateHybridFeedback(breakdown: breakdown, intervals: intervals)
        case .walk:
            return generateWalkFeedback(breakdown: breakdown, duration: duration)
        default:
            return generateGeneralFeedback(breakdown: breakdown, duration: duration)
        }
    }

    // MARK: Zone 2 Feedback

    private static func generateZone2Feedback(breakdown: ZoneBreakdown, duration: Int) -> String {
        let z2Pct = Int(breakdown.zone2Percent * 100)
        let z3Pct = Int(breakdown.zone3Percent * 100)

        if z2Pct >= 70 && duration >= 30 {
            if z3Pct > 15 {
                return "Solid Zone 2 session — \(z2Pct)% in the target range. The \(z3Pct)% in Zone 3 was likely during hills or the first few minutes before settling in."
            }
            return "Excellent Zone 2 execution — \(z2Pct)% of your time was in the aerobic base zone. This is exactly what builds mitochondrial density."
        } else if z2Pct >= 50 {
            let aboveZ2 = Int((breakdown.zone3Percent + breakdown.zone4Percent + breakdown.zone5Percent) * 100)
            return "Zone 2 session was mixed — only \(z2Pct)% in target range with \(aboveZ2)% above. Try slowing down. Zone 2 should feel conversational."
        } else {
            return "Most of this session was above Zone 2. Slow down significantly next time. Zone 2 should feel almost too easy."
        }
    }

    // MARK: VO2 Max Feedback

    private static func generateVO2MaxFeedback(
        breakdown: ZoneBreakdown,
        intervals: [DetectedInterval],
        recoveryDrop: Double?
    ) -> String {
        let z5Minutes = breakdown.zone5Minutes
        let intervalCount = intervals.count

        var feedback = ""

        if intervalCount > 0 {
            let avgPeak = intervals.map(\.peakHR).reduce(0, +) / Double(intervalCount)
            feedback = "\(intervalCount) intervals detected with \(z5Minutes) minutes in Zone 5, avg peak \(Int(avgPeak)) BPM."

            // Check recovery degradation across intervals
            let recoveries = intervals.compactMap { $0.recoveryAfter?.dropIn60Sec }
            if recoveries.count >= 3 {
                let firstRecovery = recoveries.first!
                let lastRecovery = recoveries.last!
                let degradation = firstRecovery - lastRecovery

                if degradation > 8 {
                    feedback += " Recovery degraded from \(Int(firstRecovery)) to \(Int(lastRecovery)) BPM drop across intervals — consider fewer intervals next session."
                } else if degradation > 4 {
                    feedback += " Recovery slightly declined across intervals, which is normal fatigue."
                } else {
                    feedback += " Recovery was consistent across intervals — strong conditioning."
                }
            }
        } else {
            if z5Minutes >= 8 {
                feedback = "Strong VO2 Max stimulus with \(z5Minutes) minutes in Zone 5."
            } else if z5Minutes >= 3 {
                feedback = "Moderate VO2 Max stimulus — \(z5Minutes) minutes in Zone 5. Aim for 8-12 minutes total for optimal adaptation."
            } else {
                feedback = "Limited time in Zone 5 (\(z5Minutes) min). For VO2 Max improvement, aim for 4-minute intervals at 90-95% max HR."
            }
        }

        // Post-workout recovery note
        if let drop = recoveryDrop {
            if drop >= 30 {
                feedback += " Post-workout recovery looks strong (\(Int(drop)) BPM drop in 60s)."
            } else if drop >= 20 {
                feedback += " Post-workout recovery is adequate (\(Int(drop)) BPM drop in 60s)."
            } else if drop > 0 {
                feedback += " Slow post-workout recovery (\(Int(drop)) BPM drop in 60s) — monitor fatigue levels."
            }
        }

        return feedback
    }

    // MARK: Hybrid Feedback

    private static func generateHybridFeedback(
        breakdown: ZoneBreakdown,
        intervals: [DetectedInterval]
    ) -> String {
        let z2Pct = Int(breakdown.zone2Percent * 100)
        let z4z5Pct = Int((breakdown.zone4Percent + breakdown.zone5Percent) * 100)

        if intervals.count > 0 && z2Pct > 25 {
            return "Mixed session with \(z2Pct)% aerobic base and \(z4z5Pct)% high intensity (\(intervals.count) intervals). This was likely structured intervals with warmup/cooldown — solid work."
        } else if z4z5Pct > 30 {
            return "Effort drifted across zones — \(z2Pct)% Zone 2, \(z4z5Pct)% high intensity. Consider picking a clearer target: easy or hard, not in between."
        } else {
            let z3Pct = Int(breakdown.zone3Percent * 100)
            return "Session was mostly Zone 3 tempo (\(z3Pct)%). This 'gray zone' builds some fitness but is less efficient than dedicated Zone 2 or interval work."
        }
    }

    // MARK: Walk Feedback

    private static func generateWalkFeedback(breakdown: ZoneBreakdown, duration: Int) -> String {
        let z1z2Pct = Int((breakdown.zone1Percent + breakdown.zone2Percent) * 100)

        if duration >= 30 {
            if z1z2Pct >= 80 {
                return "Great recovery walk — \(duration) minutes at low intensity. This supports daily movement goals and active recovery."
            } else {
                return "\(duration)-minute walk with some moderate effort. Walks are best kept easy for recovery and daily step count."
            }
        } else {
            return "\(duration)-minute walk logged. Every bit of movement counts toward your daily step goal."
        }
    }

    // MARK: General Feedback

    private static func generateGeneralFeedback(breakdown: ZoneBreakdown, duration: Int) -> String {
        let primaryZone: Int
        let primaryPct: Double
        let zones = [
            (1, breakdown.zone1Percent),
            (2, breakdown.zone2Percent),
            (3, breakdown.zone3Percent),
            (4, breakdown.zone4Percent),
            (5, breakdown.zone5Percent)
        ]
        let sorted = zones.sorted { $0.1 > $1.1 }
        primaryZone = sorted.first?.0 ?? 2
        primaryPct = sorted.first?.1 ?? 0

        return "\(duration)-minute session primarily in Zone \(primaryZone) (\(Int(primaryPct * 100))%). Logged and tracked for your weekly cardio totals."
    }

    // MARK: - Weekly Summary Helpers

    /// Aggregate zone breakdown across multiple sessions
    static func weeklyZoneBreakdown(sessions: [CardioSession]) -> ZoneBreakdown {
        var z1: Double = 0, z2: Double = 0, z3: Double = 0, z4: Double = 0, z5: Double = 0

        for session in sessions {
            z1 += session.zone1Seconds ?? 0
            z2 += session.zone2Seconds ?? 0
            z3 += session.zone3Seconds ?? 0
            z4 += session.zone4Seconds ?? 0
            z5 += session.zone5Seconds ?? 0
        }

        let total = z1 + z2 + z3 + z4 + z5

        return ZoneBreakdown(
            zone1Seconds: z1, zone2Seconds: z2, zone3Seconds: z3,
            zone4Seconds: z4, zone5Seconds: z5, totalSeconds: total
        )
    }

    /// Build a coaching-context string for weekly check-in (deterministic, no AI)
    static func weeklyCardioSummary(sessions: [CardioSession]) -> String {
        guard !sessions.isEmpty else {
            return "CARDIO THIS WEEK: No sessions logged."
        }

        let breakdown = weeklyZoneBreakdown(sessions: sessions)
        let totalMinutes = sessions.reduce(0) { $0 + $1.duration }

        // Count by type
        var typeCounts: [String: Int] = [:]
        for session in sessions {
            typeCounts[session.sessionType, default: 0] += 1
        }

        var summary = "CARDIO THIS WEEK:\n"
        summary += "Sessions: \(sessions.count) (\(totalMinutes) min total)\n"

        for (type, count) in typeCounts.sorted(by: { $0.key < $1.key }) {
            summary += "  \(type): \(count) session(s)\n"
        }

        if breakdown.totalSeconds > 0 {
            summary += "\nZone distribution (all sessions combined):\n"
            summary += "  Z1: \(breakdown.zone1Minutes) min (\(Int(breakdown.zone1Percent * 100))%)\n"
            summary += "  Z2: \(breakdown.zone2Minutes) min (\(Int(breakdown.zone2Percent * 100))%)\n"
            summary += "  Z3: \(breakdown.zone3Minutes) min (\(Int(breakdown.zone3Percent * 100))%)\n"
            summary += "  Z4: \(breakdown.zone4Minutes) min (\(Int(breakdown.zone4Percent * 100))%)\n"
            summary += "  Z5: \(breakdown.zone5Minutes) min (\(Int(breakdown.zone5Percent * 100))%)\n"
        }

        // Interval quality across VO2 Max sessions
        let vo2Sessions = sessions.filter { $0.sessionType == CardioActivityType.vo2max.rawValue }
        if !vo2Sessions.isEmpty {
            let allIntervals = vo2Sessions.compactMap { $0.decodedIntervals }.flatMap { $0 }
            if !allIntervals.isEmpty {
                let avgPeakHR = allIntervals.map(\.peakHR).reduce(0, +) / Double(allIntervals.count)
                let recoveries = allIntervals.compactMap { $0.recoveryAfter?.dropIn60Sec }
                let avgRecovery = recoveries.isEmpty ? 0.0 : recoveries.reduce(0, +) / Double(recoveries.count)

                summary += "\nInterval quality:\n"
                summary += "  Total intervals: \(allIntervals.count)\n"
                summary += "  Avg peak HR: \(Int(avgPeakHR)) BPM\n"
                if avgRecovery > 0 {
                    summary += "  Avg recovery: -\(Int(avgRecovery)) BPM in 60s\n"
                }
            }
        }

        // Average post-workout recovery
        let recoveryDrops = sessions.compactMap { $0.postWorkoutRecoveryDrop }
        if !recoveryDrops.isEmpty {
            let avgDrop = recoveryDrops.reduce(0, +) / Double(recoveryDrops.count)
            summary += "\nAvg post-workout recovery: -\(Int(avgDrop)) BPM in 60s\n"
        }

        return summary
    }
}