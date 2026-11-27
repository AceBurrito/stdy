import SwiftUI
import SwiftData

struct PaceCalculatingScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    let healthKitManager: HealthKitManager
    let onCalculationComplete: (PaceResult) -> Void
    
    @State private var currentPhase = 0
    @State private var calculationDone = false
    @State private var calculatedResult: PaceResult?
    @State private var pulseScale: CGFloat = 1.0
    @State private var ringRotation: Double = 0
    @State private var minimumTimeElapsed = false
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    private let phases = [
        "Connecting to your health data...",
        "Analyzing sleep patterns...",
        "Measuring recovery signals...",
        "Calculating your Pace..."
    ]
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Pulsing ring animation
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(
                            Color.atlasPrimary.opacity(0.15),
                            lineWidth: 3
                        )
                        .frame(width: 120, height: 120)
                    
                    // Animated arc
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            Color.atlasPrimary.opacity(0.6),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(ringRotation))
                    
                    // Inner pulse
                    Circle()
                        .fill(Color.atlasPrimary.opacity(0.08))
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseScale)
                    
                    // Center dot
                    Circle()
                        .fill(Color.atlasPrimary.opacity(0.4))
                        .frame(width: 12, height: 12)
                }
                
                // Phase text
                VStack(spacing: 12) {
                    Text(phases[min(currentPhase, phases.count - 1)])
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color.atlasText)
                        .animation(.easeInOut(duration: 0.3), value: currentPhase)
                    
                    // Subtle progress dots
                    HStack(spacing: 8) {
                        ForEach(0..<phases.count, id: \.self) { index in
                            Circle()
                                .fill(index <= currentPhase ? Color.atlasPrimary : Color.atlasTextMuted.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            startAnimations()
            startPhaseProgression()
            startCalculation()
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
        
        // Ring rotation
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
    }
    
    // MARK: - Phase Progression
    
    private func startPhaseProgression() {
        // Phase 0 → 1 at 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { currentPhase = 1 }
        }
        // Phase 1 → 2 at 3.0s
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { currentPhase = 2 }
        }
        // Phase 2 → 3 at 4.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation { currentPhase = 3 }
        }
        // Minimum 5.5s display time
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            minimumTimeElapsed = true
            proceedIfReady()
        }
    }
    
    // MARK: - Calculation
    
    private func startCalculation() {
        Task {
            guard let profile = userProfile else {
                // Fallback: return default result
                await MainActor.run {
                    let fallback = LifespanPaceCalculator.calculate(
                        age: 40, gender: nil,
                        sleepAverage: nil, hrvAverage: nil, rhrAverage: nil,
                        vo2Max: nil, stepsAverage: nil,
                        bodyweight: nil, height: nil,
                        pushupRange: nil, canStandFromSitting: nil, deadHangRange: nil,
                        benchPressMax: nil, squatMax: nil, deadliftMax: nil,
                        strengthDataSource: "selfReported"
                    )
                    calculatedResult = fallback
                    calculationDone = true
                    proceedIfReady()
                }
                return
            }
            
            // Fetch health data from stored HealthMetrics (synced during BaselineDataView)
            let descriptor = FetchDescriptor<HealthMetrics>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let allMetrics = (try? modelContext.fetch(descriptor)) ?? []
            let recentMetrics = Array(allMetrics.prefix(7))
            
            // Calculate averages from stored metrics
            let sleepAvg: Double? = {
                let values = recentMetrics.compactMap { $0.sleepDuration }
                guard !values.isEmpty else {
                    // Fall back to self-reported sleep
                    return profile.selfReportedSleepHours
                }
                return values.reduce(0, +) / Double(values.count)
            }()
            
            let hrvAvg: Double? = {
                let values = recentMetrics.compactMap { $0.heartRateVariability }
                guard !values.isEmpty else { return nil }
                return values.reduce(0, +) / Double(values.count)
            }()
            
            let rhrAvg: Double? = {
                let values = recentMetrics.compactMap { $0.restingHeartRate }
                guard !values.isEmpty else { return nil }
                return values.reduce(0, +) / Double(values.count)
            }()
            
            let vo2Max: Double? = recentMetrics.compactMap({ $0.vo2Max }).first
            
            let stepsAvg: Double? = {
                let values = recentMetrics.compactMap { $0.stepCount }
                guard !values.isEmpty else { return nil }
                return values.reduce(0, +) / Double(values.count)
            }()
            
            // Determine strength data source from profile
            let strengthSource = profile.strengthDataSource ?? "selfReported"
            
            // Run Pace calculation
            let result = LifespanPaceCalculator.calculate(
                age: profile.age ?? 40,
                gender: profile.gender,
                sleepAverage: sleepAvg,
                hrvAverage: hrvAvg,
                rhrAverage: rhrAvg,
                vo2Max: vo2Max,
                stepsAverage: stepsAvg,
                bodyweight: profile.weight,
                height: profile.height,
                pushupRange: profile.pushupRange,
                canStandFromSitting: profile.canStandFromSitting,
                deadHangRange: profile.deadHangRange,
                benchPressMax: profile.benchPressMax,
                squatMax: profile.squatMax,
                deadliftMax: profile.deadliftMax,
                strengthDataSource: strengthSource
            )
            
            // Store the score
            await MainActor.run {
                let paceScore = BiologicalPaceScore(
                    date: Date(),
                    paceValue: result.paceValue,
                    compositePercentile: result.compositePercentile,
                    confidenceLevel: result.confidenceLevel,
                    componentsAvailable: result.componentsAvailable
                )
                paceScore.populate(from: result)
                paceScore.userProfile = profile
                modelContext.insert(paceScore)
                
                // Update UserProfile
                profile.latestPaceValue = result.paceValue
                profile.latestPaceDate = Date()
                profile.latestPaceConfidence = result.confidenceLevel
                profile.paceBaselineValue = result.paceValue
                profile.paceBaselineDate = Date()
                profile.bestPaceEver = result.paceValue
                profile.bestPaceDate = Date()
                profile.lastStrengthAssessmentDate = Date()
                
                try? modelContext.save()
                
                print("✅ Pace calculated: \(String(format: "%.2f", result.paceValue))")
                print("   Confidence: \(result.confidenceLevel) (\(result.componentsAvailable)/6 components)")
                print("   Strength source: \(strengthSource)")
                print(LifespanPaceCalculator.debugDescription(for: result))
                
                calculatedResult = result
                calculationDone = true
                proceedIfReady()
            }
        }
    }
    
    private func proceedIfReady() {
        guard calculationDone, minimumTimeElapsed, let result = calculatedResult else { return }
        onCalculationComplete(result)
    }
}
