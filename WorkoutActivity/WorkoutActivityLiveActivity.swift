// WorkoutActivityLiveActivity.swift
// WorkoutActivity (Widget Extension target ONLY)

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct WorkoutActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.9))
                .activitySystemActionForegroundColor(.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        if context.state.isWorkoutComplete {
                            Text("Workout Complete")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.teal)
                        } else {
                            Text(context.state.exerciseName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text("Set \(context.state.currentSet)/\(context.state.totalSets)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isWorkoutComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.teal)
                    } else if context.state.isResting, let endTime = context.state.restTimerEnd, endTime > Date() {
                        Text(timerInterval: Date.now...endTime, countsDown: true)
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.teal)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    } else {
                        weightRepsCompact(context: context)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.state.isWorkoutComplete {
                        HStack(spacing: 10) {
                            if context.state.isResting,
                               let endTime = context.state.restTimerEnd,
                               endTime > Date() {
                                Button(intent: SkipRestIntent()) {
                                    Text("Skip")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button(intent: LogSetIntent()) {
                                Text("✓ Log")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.teal)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.teal)
                
            } compactTrailing: {
                if context.state.isWorkoutComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.teal)
                } else if context.state.isResting, let endTime = context.state.restTimerEnd, endTime > Date() {
                    Text(timerInterval: Date.now...endTime, countsDown: true)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.teal)
                        .frame(width: 40)
                } else {
                    Text("\(context.state.currentSet)/\(context.state.totalSets)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.teal)
                }
                
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.teal)
            }
        }
    }
    
    // MARK: - Lock Screen Router
    
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        if context.state.isWorkoutComplete {
            workoutCompleteView(context: context)
        } else if context.state.isResting, let endTime = context.state.restTimerEnd, endTime > Date() {
            restingView(context: context, endTime: endTime)
        } else {
            readyToLogView(context: context)
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MODE 0: WORKOUT COMPLETE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    @ViewBuilder
    private func workoutCompleteView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.teal)
                    Text(context.state.workoutName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer()
                if let start = context.state.workoutStartTime {
                    Text(timerInterval: start...Date.now, countsDown: false)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.teal)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout Complete")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(context.state.totalExercises) exercises · \(context.state.totalSets) sets")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color.teal.opacity(0.08))
            .cornerRadius(10)
            
            Text("Open app to save workout")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.35))
            
            progressBar(context: context, overrideProgress: 1.0)
        }
        .padding(14)
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MODE 1: RESTING
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    @ViewBuilder
    private func restingView(context: ActivityViewContext<WorkoutActivityAttributes>, endTime: Date) -> some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.teal)
                    Text(context.state.workoutName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer()
                if let start = context.state.workoutStartTime {
                    Text(timerInterval: start...Date.now, countsDown: false)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.exerciseName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 0) {
                    Text("Next: set \(context.state.currentSet) of \(context.state.totalSets)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                    
                    if !context.state.isBodyweight, let w = context.state.nextWeight {
                        Text(" · \(Int(w)) × \(context.state.nextReps)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    } else if context.state.isBodyweight {
                        Text(" · BW × \(context.state.nextReps)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 10) {
                Text("Rest:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.teal.opacity(0.75))
                
                Text(timerInterval: Date.now...endTime, countsDown: true)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(intent: SubtractRestTimeIntent()) {
                    Text("−15s")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(intent: AddRestTimeIntent()) {
                    Text("+15s")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(intent: SkipRestIntent()) {
                    Text("Skip")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.teal.opacity(0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color.teal.opacity(0.07))
            .cornerRadius(10)
            
            progressBar(context: context)
        }
        .padding(14)
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MODE 2: READY TO LOG
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    @ViewBuilder
    private func readyToLogView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.teal)
                    Text(context.state.workoutName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer()
                if let start = context.state.workoutStartTime {
                    Text(timerInterval: start...Date.now, countsDown: false)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.exerciseName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                Text("\(context.state.completedExercises)/\(context.state.totalExercises)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.teal)
            }
            
            HStack(spacing: 6) {
                if context.state.isBodyweight {
                    Text("BW")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                    
                    Text("×")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.35))
                    
                    Button(intent: SubtractRepIntent()) {
                        Text("−")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.teal)
                            .frame(width: 26, height: 30)
                            .background(Color.teal.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(context.state.nextReps)")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(minWidth: 28)
                        .multilineTextAlignment(.center)
                    
                    Button(intent: AddRepIntent()) {
                        Text("+")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.teal)
                            .frame(width: 26, height: 30)
                            .background(Color.teal.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    
                } else {
                    Button(intent: SubtractWeightIntent()) {
                        Text("−")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.teal)
                            .frame(width: 26, height: 30)
                            .background(Color.teal.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(Int(context.state.nextWeight ?? 0))")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(minWidth: 32)
                        .multilineTextAlignment(.center)
                    
                    Button(intent: AddWeightIntent()) {
                        Text("+")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.teal)
                            .frame(width: 26, height: 30)
                            .background(Color.teal.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    
                    Text("×")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.35))
                    
                    Button(intent: SubtractRepIntent()) {
                        Text("−")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.teal)
                            .frame(width: 26, height: 30)
                            .background(Color.teal.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(context.state.nextReps)")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(minWidth: 28)
                        .multilineTextAlignment(.center)
                    
                    Button(intent: AddRepIntent()) {
                        Text("+")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.teal)
                            .frame(width: 26, height: 30)
                            .background(Color.teal.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(intent: LogSetIntent()) {
                    HStack(spacing: 3) {
                        Text("✓")
                            .font(.system(size: 12, weight: .bold))
                        Text("Log")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.teal)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            
            progressBar(context: context)
        }
        .padding(14)
    }
    
    // MARK: - Shared
    
    @ViewBuilder
    private func progressBar(context: ActivityViewContext<WorkoutActivityAttributes>, overrideProgress: CGFloat? = nil) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 3)
                let progress = overrideProgress ?? (context.state.totalExercises > 0
                    ? CGFloat(context.state.completedExercises) / CGFloat(context.state.totalExercises)
                    : 0)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.teal)
                    .frame(width: geo.size.width * progress, height: 3)
            }
        }
        .frame(height: 3)
    }
    
    @ViewBuilder
    private func weightRepsCompact(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        if context.state.isBodyweight {
            Text("BW×\(context.state.nextReps)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        } else if let w = context.state.nextWeight {
            Text("\(Int(w))×\(context.state.nextReps)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
