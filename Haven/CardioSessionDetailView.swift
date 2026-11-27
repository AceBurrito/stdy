import SwiftUI
import SwiftData

struct CardioSessionDetailView: View {
    let session: CardioSession
    let userAge: Int
    let restingHR: Double?

    private var activityType: CardioActivityType {
        CardioActivityType(rawValue: session.sessionType) ?? .generalCardio
    }

    private var zones: HeartRateZones {
        CardioZoneCalculator.calculateZones(age: userAge, restingHR: restingHR)
    }

    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Coaching Feedback
                    if let feedback = session.coachingFeedback, !feedback.isEmpty {
                        feedbackSection(feedback)
                    }

                    // Zone Breakdown
                    if session.hasZoneData {
                        zoneBreakdownSection
                    }

                    // Intervals
                    if let intervals = session.decodedIntervals as [DetectedInterval]?,
                       !intervals.isEmpty {
                        intervalsSection(intervals)
                    }

                    // Post-Workout Recovery
                    if session.postWorkoutRecoveryDrop != nil {
                        postWorkoutRecoverySection
                    }

                    // Notes
                    if let notes = session.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(24)
            }
        }
        .navigationTitle(activityType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon and type
            HStack(spacing: 12) {
                Image(systemName: activityType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.atlasPrimary)
                    .frame(width: 48, height: 48)
                    .background(Color.atlasPrimary.opacity(0.15))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(activityType.rawValue)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.atlasText)

                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }

                Spacer()

                if session.importedFromHealthKit {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            // Stats grid
            HStack(spacing: 12) {
                statCard(value: "\(session.duration)", label: "Minutes")
                if let avgHR = session.avgHeartRate {
                    statCard(value: "\(Int(avgHR))", label: "Avg BPM")
                }
                if let maxHR = session.maxHeartRate {
                    statCard(value: "\(Int(maxHR))", label: "Max BPM")
                }
                if let distance = session.distance, distance > 0 {
                    statCard(value: String(format: "%.1f", distance), label: "Miles")
                }
            }

            // Mini zone bar
            if session.hasZoneData {
                MiniZoneBar(breakdown: session.zoneBreakdown)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.atlasText)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.atlasTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Coaching Feedback

    private func feedbackSection(_ feedback: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .foregroundColor(.atlasAccent)

                Text("SESSION ANALYSIS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(2)
            }

            Text(feedback)
                .font(.system(size: 15))
                .foregroundColor(.atlasText)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.atlasPrimary.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.atlasPrimary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Zone Breakdown

    private var zoneBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ZONE BREAKDOWN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)

            FullZoneBreakdownView(breakdown: session.zoneBreakdown)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Intervals

    private func intervalsSection(_ intervals: [DetectedInterval]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("INTERVALS DETECTED")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(2)

                Spacer()

                Text("\(intervals.count) intervals")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.atlasText)
            }

            // Summary stats
            if let avgPeak = session.avgIntervalPeakHR {
                HStack(spacing: 20) {
                    intervalStat(label: "Avg Peak", value: "\(Int(avgPeak)) BPM")
                    if let avgRecovery = session.avgRecoveryDrop60s, avgRecovery > 0 {
                        intervalStat(label: "Avg Recovery", value: "-\(Int(avgRecovery)) BPM/60s")
                    }
                }
                .padding(.bottom, 4)
            }

            // Individual intervals
            ForEach(Array(intervals.enumerated()), id: \.offset) { index, interval in
                intervalRow(index: index + 1, interval: interval)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func intervalStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.atlasTextMuted)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasText)
        }
    }

    private func intervalRow(index: Int, interval: DetectedInterval) -> some View {
        HStack(spacing: 12) {
            // Index
            Text("#\(index)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(zoneColor(interval.zone))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("\(formatIntervalDuration(interval.duration))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasText)

                    Text("Peak \(Int(interval.peakHR))")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)

                    Text("Zone \(interval.zone)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(zoneColor(interval.zone))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(zoneColor(interval.zone).opacity(0.15))
                        .cornerRadius(4)
                }

                // Recovery
                if let recovery = interval.recoveryAfter, let drop = recovery.dropIn60Sec {
                    Text("Recovery: -\(Int(drop)) BPM in 60s")
                        .font(.system(size: 12))
                        .foregroundColor(drop >= 25 ? .green : drop >= 15 ? .atlasTextMuted : .orange)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    private func formatIntervalDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins):\(String(format: "%02d", secs))"
        }
        return "\(secs)s"
    }

    // MARK: - Post-Workout Recovery

    private var postWorkoutRecoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("POST-WORKOUT RECOVERY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)

            HStack(spacing: 20) {
                if let maxHR = session.maxHeartRate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Peak HR")
                            .font(.system(size: 11))
                            .foregroundColor(.atlasTextMuted)
                        Text("\(Int(maxHR)) BPM")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.atlasText)
                    }
                }

                if let hr60 = session.postWorkoutHR60s {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("At 60s")
                            .font(.system(size: 11))
                            .foregroundColor(.atlasTextMuted)
                        Text("\(Int(hr60)) BPM")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.atlasText)
                    }
                }

                if let drop = session.postWorkoutRecoveryDrop {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recovery")
                            .font(.system(size: 11))
                            .foregroundColor(.atlasTextMuted)
                        Text("-\(Int(drop)) BPM")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(drop >= 30 ? .green : drop >= 20 ? .atlasPrimary : .orange)
                    }
                }
            }

            // Interpretation
            if let drop = session.postWorkoutRecoveryDrop {
                Text(recoveryInterpretation(drop))
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func recoveryInterpretation(_ drop: Double) -> String {
        if drop >= 40 {
            return "Excellent cardiac recovery. Strong autonomic nervous system response."
        } else if drop >= 30 {
            return "Good recovery. Your heart is responding well to training."
        } else if drop >= 20 {
            return "Adequate recovery. This is within normal range."
        } else {
            return "Slow recovery — could indicate fatigue, dehydration, or need for more rest."
        }
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)

            Text(notes)
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}