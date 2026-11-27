import SwiftUI
import SwiftData
import HealthKit

struct CardioImportConfirmationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    let workout: WorkoutSummary
    let analysisResult: WorkoutAnalysisResult

    @State private var selectedType: CardioActivityType
    @State private var isSaving = false

    // Optional callback and habit
    var habit: Habit? = nil
    var onComplete: (() -> Void)? = nil

    private var userProfile: UserProfile? {
        profiles.first
    }

    init(workout: WorkoutSummary, analysisResult: WorkoutAnalysisResult, habit: Habit? = nil, onComplete: (() -> Void)? = nil) {
        self.workout = workout
        self.analysisResult = analysisResult
        self.habit = habit
        self.onComplete = onComplete
        self._selectedType = State(initialValue: analysisResult.activityType)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Workout header
                        headerSection

                        // Zone Breakdown
                        if analysisResult.zoneBreakdown.totalSeconds > 0 {
                            zoneBreakdownSection
                        }

                        // Intervals
                        if !analysisResult.intervals.isEmpty {
                            intervalsSection
                        }

                        // Post-Workout Recovery
                        if analysisResult.postWorkoutRecoveryDrop != nil {
                            recoverySection
                        }

                        // Coaching Feedback
                        feedbackSection

                        // Activity Type Override
                        typeOverrideSection

                        // Save button
                        Button(action: saveWorkout) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(Color.atlasBackground)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Workout")
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.atlasBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.atlasPrimary)
                            .cornerRadius(12)
                        }
                        .disabled(isSaving)

                        Spacer().frame(height: 40)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Import Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.atlasTextMuted)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)

                Text("Imported from Apple Health")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            HStack(spacing: 8) {
                Image(systemName: selectedType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.atlasPrimary)

                Text(workout.workoutType)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.atlasText)

                Text("·")
                    .foregroundColor(.atlasTextMuted)

                Text("\(Int(workout.duration / 60)) min")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.atlasText)

                if let avgHR = workout.avgHeartRate {
                    Text("·")
                        .foregroundColor(.atlasTextMuted)

                    Text("Avg \(Int(avgHR)) BPM")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted)
                }

                Spacer()
            }

            HStack(spacing: 6) {
                Text("Auto-classified:")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)

                Text(selectedType.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.atlasPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Mini zone bar
            if analysisResult.zoneBreakdown.totalSeconds > 0 {
                MiniZoneBar(breakdown: analysisResult.zoneBreakdown)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .background(Color.red.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Zone Breakdown

    private var zoneBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ZONE BREAKDOWN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)

            FullZoneBreakdownView(breakdown: analysisResult.zoneBreakdown)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Intervals

    private var intervalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INTERVALS DETECTED")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(2)

                Spacer()

                Text("\(analysisResult.intervals.count)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.atlasText)
            }

            HStack(spacing: 20) {
                let avgPeak = analysisResult.intervals.map(\.peakHR).reduce(0, +) / Double(analysisResult.intervals.count)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avg Peak HR")
                        .font(.system(size: 11))
                        .foregroundColor(.atlasTextMuted)
                    Text("\(Int(avgPeak)) BPM")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasText)
                }

                let recoveries = analysisResult.intervals.compactMap { $0.recoveryAfter?.dropIn60Sec }
                if !recoveries.isEmpty {
                    let avgRecovery = recoveries.reduce(0, +) / Double(recoveries.count)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avg Recovery")
                            .font(.system(size: 11))
                            .foregroundColor(.atlasTextMuted)
                        Text("-\(Int(avgRecovery)) BPM in 60s")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasText)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Recovery

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("POST-WORKOUT RECOVERY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)

            if let maxHR = workout.maxHeartRate, let drop = analysisResult.postWorkoutRecoveryDrop {
                HStack(spacing: 4) {
                    Text("\(Int(maxHR)) BPM")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasText)

                    Text("→")
                        .foregroundColor(.atlasTextMuted)

                    if let hr60 = analysisResult.postWorkoutRecoveryHR {
                        Text("\(Int(hr60)) BPM")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasText)
                    }

                    Text("(-\(Int(drop)) in 60s)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(drop >= 30 ? .green : drop >= 20 ? .atlasPrimary : .orange)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .foregroundColor(.atlasPrimary)

                Text("ANALYSIS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasPrimary)
                    .tracking(2)
            }

            Text(analysisResult.feedback)
                .font(.system(size: 15))
                .foregroundColor(.atlasText)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.atlasPrimary.opacity(0.08))
        .cornerRadius(16)
    }

    // MARK: - Type Override

    private var typeOverrideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OVERRIDE TYPE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasTextMuted)
                .tracking(2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CardioActivityType.allCases, id: \.self) { type in
                        Button(action: { selectedType = type }) {
                            HStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 12))
                                Text(type.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedType == type ? Color.atlasPrimary : Color.white.opacity(0.08))
                            .foregroundColor(selectedType == type ? Color.atlasBackground : Color.atlasText)
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func saveWorkout() {
        isSaving = true

        let session = CardioSession(
            date: workout.startDate,
            duration: Int(workout.duration / 60),
            sessionType: selectedType.rawValue
        )
        session.avgHeartRate = workout.avgHeartRate
        session.maxHeartRate = workout.maxHeartRate
        session.calories = workout.calories
        session.distance = workout.distance
        session.importedFromHealthKit = true
        session.healthKitWorkoutID = workout.hkWorkout.uuid.uuidString
        session.userProfile = userProfile

        // Populate analysis data
        session.populate(from: analysisResult)

        // Override session type if user changed it
        session.sessionType = selectedType.rawValue

        modelContext.insert(session)

        // Mark habit complete if provided
        if let habit = habit {
            let dataController = DataController(modelContext: modelContext)
            dataController.markHabitComplete(habit)
        }

        do {
            try modelContext.save()
            print("✅ Imported workout: \(selectedType.rawValue) — \(Int(workout.duration/60)) min")
            onComplete?()
            dismiss()
        } catch {
            print("❌ Failed to save imported workout: \(error)")
            isSaving = false
        }
    }
}