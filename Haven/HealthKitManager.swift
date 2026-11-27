import Foundation
import HealthKit
import Combine
import SwiftData

struct HealthData {
    var age: Int?
    var biologicalSex: String?
    var height: Double? // in inches
    var weight: Double? // in pounds
    var bodyFatPercentage: Double? // fraction, 0.18 = 18%
    var vo2Max: Double?
    var restingHeartRate: Double?
    var heartRateVariability: Double?
}

// MARK: - Fetch Recent Workouts (for Cardio Import)

struct WorkoutSummary: Identifiable {
    let id: UUID
    let workoutType: String
    let startDate: Date
    let duration: TimeInterval // in seconds
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let calories: Double?
    let distance: Double? // in miles
    let hkWorkout: HKWorkout // Keep reference for detailed data
}

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var healthData = HealthData()
    
    // MARK: - Sync Debounce
    // Prevents multiple simultaneous syncs from HealthKit observers + .task + foreground notification
    private var isSyncing = false
    private var syncRequestedWhileBusy = false
    private var lastSyncDate: Date?
    
    /// Minimum interval between syncs (seconds). Prevents quadruple-firing on app launch.
    private let minimumSyncInterval: TimeInterval = 30
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        let typesToRead: Set<HKObjectType> = [
            // Characteristics
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            
            // Body measurements
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!, // weight
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            
            // Sleep
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            
            // Recovery metrics
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!, // For workout HR data
            
            // Fitness
            HKObjectType.quantityType(forIdentifier: .vo2Max)!,
            
            // Activity
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            
            // Workouts
            HKObjectType.workoutType()
        ]

        // FEAT-002: Include workout write permission for Apple Watch session
        let typesToShare: Set<HKSampleType> = [
            HKWorkoutType.workoutType()
        ]
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        self.isAuthorized = true
        
        // Fetch all available data after authorization
        await fetchAllHealthData()
    }
    
    // MARK: - Fetch All Data
    func fetchAllHealthData() async {
        async let age = fetchAge()
        async let sex = fetchBiologicalSex()
        async let height = fetchHeight()
        async let weight = fetchWeight()
        async let bodyFat = fetchBodyFatPercentage()
        async let vo2 = fetchVO2Max()
        async let rhr = fetchRestingHeartRate()
        async let hrv = fetchHeartRateVariability()
        
        healthData.age = await age
        healthData.biologicalSex = await sex
        healthData.height = await height
        healthData.weight = await weight
        healthData.bodyFatPercentage = await bodyFat
        healthData.vo2Max = await vo2
        healthData.restingHeartRate = await rhr
        healthData.heartRateVariability = await hrv
        
        print("✅ Health data fetched:")
        print("   Age: \(healthData.age?.description ?? "nil")")
        print("   Sex: \(healthData.biologicalSex ?? "nil")")
        print("   Height: \(healthData.height?.description ?? "nil") inches")
        print("   Weight: \(healthData.weight?.description ?? "nil") lbs")
        print("   VO2 Max: \(healthData.vo2Max?.description ?? "nil")")
        print("   RHR: \(healthData.restingHeartRate?.description ?? "nil")")
        print("   HRV: \(healthData.heartRateVariability?.description ?? "nil")")
    }
    
    // MARK: - Daily Snapshot (Yesterday's single-day values for TodayView)
    func fetchDailySnapshot(for date: Date = Date()) async -> HealthMetrics {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let metrics = HealthMetrics(date: startOfDay)
        
        // Fetch THIS DAY's single-day values (not week average)
        async let sleepForDate = fetchSleepForDate(date)
        async let hrvForDate = fetchHRVForDate(date)
        async let rhrForDate = fetchRHRForDate(date)
        async let stepsForDate = fetchStepsForDate(date)
        async let vo2Latest = fetchVO2Max()  // Latest value (doesn't change daily)
        async let weightLatest = fetchWeight()  // Latest single measurement
        
        // Populate metrics with this day's values
        let sleepData = await sleepForDate
        metrics.sleepDuration = sleepData?.duration
        
        metrics.heartRateVariability = await hrvForDate
        metrics.restingHeartRate = await rhrForDate
        metrics.stepCount = await stepsForDate
        metrics.vo2Max = await vo2Latest
        metrics.weight = await weightLatest
        
        print("📊 Daily snapshot (\(date.formatted(date: .abbreviated, time: .omitted))): Sleep: \(metrics.sleepDuration ?? 0)h, HRV: \(metrics.heartRateVariability ?? 0)ms, RHR: \(metrics.restingHeartRate ?? 0)bpm, Steps: \(Int(metrics.stepCount ?? 0))")
        
        return metrics
    }
    
    // MARK: - Monthly Averages (30-day) for Plan Generation
    func fetchMonthlyAveragesForPlanGeneration(endDate: Date = Date()) async -> HealthMetrics {
        let metrics = HealthMetrics(date: endDate)
        
        print("📊 Fetching 30-day averages for plan generation...")
        
        // Fetch 30-day averages for all metrics (with 7-day fallback)
        async let sleep30 = fetchSleepAverage30Days(endDate: endDate)
        async let hrv30 = fetchHRVAverage30Days(endDate: endDate)
        async let rhr30 = fetchRHRAverage30Days(endDate: endDate)
        async let weight30 = fetchWeightAverage30Days(endDate: endDate)
        async let steps30 = fetchStepsAverage30Days(endDate: endDate)
        async let vo2Latest = fetchVO2Max()  // Latest value is fine
        
        // Populate metrics
        metrics.sleepDuration = await sleep30
        metrics.heartRateVariability = await hrv30
        metrics.restingHeartRate = await rhr30
        metrics.weight = await weight30
        metrics.stepCount = await steps30
        metrics.vo2Max = await vo2Latest
        
        print("📊 30-day averages:")
        print("   Sleep: \(String(format: "%.1f", metrics.sleepDuration ?? 0))h")
        print("   HRV: \(String(format: "%.0f", metrics.heartRateVariability ?? 0))ms")
        print("   RHR: \(String(format: "%.0f", metrics.restingHeartRate ?? 0))bpm")
        print("   Steps: \(Int(metrics.stepCount ?? 0))/day")
        print("   Weight: \(String(format: "%.1f", metrics.weight ?? 0))lbs")
        print("   VO2 Max: \(String(format: "%.1f", metrics.vo2Max ?? 0))")
        
        return metrics
    }

    /// Backfill metrics for any missing days (up to specified days back)
    func syncMissingMetrics(modelContext: ModelContext, daysBack: Int = 7) async {
        let calendar = Calendar.current
        
        print("📊 Checking for missing metrics (last \(daysBack) days)...")
        
        for dayOffset in 1...daysBack {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfTargetDay = calendar.startOfDay(for: targetDate)
            
            // Check if we already have metrics for this day
            let descriptor = FetchDescriptor<HealthMetrics>(
                predicate: #Predicate { $0.date == startOfTargetDay }
            )
            
            do {
                let existingMetrics = try modelContext.fetch(descriptor)
                
                if existingMetrics.isEmpty {
                    print("📊 Backfilling metrics for \(startOfTargetDay.formatted(date: .abbreviated, time: .omitted))...")
                    
                    let metrics = await fetchDailySnapshot(for: targetDate)
                    
                    // Only save if we got meaningful data
                    if metrics.sleepDuration != nil || metrics.heartRateVariability != nil || metrics.restingHeartRate != nil {
                        modelContext.insert(metrics)
                        try modelContext.save()
                        print("✅ Saved metrics for \(startOfTargetDay.formatted(date: .abbreviated, time: .omitted))")
                    } else {
                        print("⚠️ No data available for \(startOfTargetDay.formatted(date: .abbreviated, time: .omitted)), skipping")
                    }
                }
            } catch {
                print("❌ Failed to backfill metrics for \(startOfTargetDay): \(error)")
            }
        }
        
        print("✅ Metrics sync complete")
    }

    // MARK: - Check for Recent Sleep Data

    func hasRecentSleepData() async -> Bool {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return false
        }
        
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: sevenDaysAgo,
            end: Date(),
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                continuation.resume(returning: (samples?.count ?? 0) > 0)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - 30-Day Average Helpers (with 7-day fallback)
    
    private func fetchSleepAverage30Days(endDate: Date) async -> Double? {
        if let avg30 = await fetchSleepAverageForDays(endDate: endDate, days: 30) {
            print("   Sleep: 30-day average available")
            return avg30
        }
        
        print("   Sleep: Insufficient 30-day data, using 7-day average")
        return await fetchSleepAverageForDays(endDate: endDate, days: 7)
    }
    
    func fetchSleepAverageForDays(endDate: Date, days: Int) async -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                guard let samples = results as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // BUG-004: Deduplicate across sources before any further processing
                let dedupedSamples = self.deduplicateSleepSamples(samples)
                
                // Filter to actual asleep stages (matches Apple Health "Time Asleep")
                let asleepSamples: [HKCategorySample]
                if #available(iOS 16.0, *) {
                    asleepSamples = dedupedSamples.filter { sample in
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    }
                } else {
                    asleepSamples = dedupedSamples.filter { sample in
                        sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }
                
                // Fallback to inBed if no staged data available
                let samplesToUse: [HKCategorySample]
                if asleepSamples.isEmpty {
                    let inBedSamples = dedupedSamples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
                    samplesToUse = inBedSamples
                } else {
                    samplesToUse = asleepSamples
                }
                
                guard !samplesToUse.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Group all samples into sleep sessions (merges overlapping/adjacent samples)
                // Then sum the actual asleep durations within each session
                let sessions = self.groupSleepSamples(samplesToUse)
                
                print("🛏️ Sleep avg: \(samplesToUse.count) asleep samples (deduped) → \(sessions.count) sessions")
                
                guard !sessions.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // For each session, sum the individual sample durations that fall within it
                var nightlyDurations: [Double] = []
                
                for (index, session) in sessions.enumerated() {
                    let sessionBuffer: TimeInterval = 30 * 60
                    let samplesInSession = samplesToUse.filter { sample in
                        sample.startDate >= session.start.addingTimeInterval(-sessionBuffer) &&
                        sample.endDate <= session.end.addingTimeInterval(sessionBuffer)
                    }
                    
                    let totalAsleep = samplesInSession.reduce(0.0) { total, sample in
                        total + sample.endDate.timeIntervalSince(sample.startDate)
                    }
                    let hours = totalAsleep / 3600.0
                    
                    let sessionSpan = session.end.timeIntervalSince(session.start) / 3600.0
                    print("🛏️   Session \(index + 1): \(session.start.formatted(date: .abbreviated, time: .shortened)) → \(session.end.formatted(date: .abbreviated, time: .shortened)) | span: \(String(format: "%.1f", sessionSpan))h | asleep: \(String(format: "%.1f", hours))h | samples: \(samplesInSession.count)\(hours < 2.0 ? " [SKIPPED <2h]" : "")")
                    
                    // Only count sessions that look like real sleep (>2h)
                    if hours >= 2.0 {
                        nightlyDurations.append(hours)
                    }
                }
                
                print("🛏️ Nightly durations: \(nightlyDurations.map { String(format: "%.1f", $0) }) → avg: \(String(format: "%.2f", nightlyDurations.isEmpty ? 0 : nightlyDurations.reduce(0,+) / Double(nightlyDurations.count)))h")
                
                // BUG-008: Average across nights WITH data only, not total days in window
                // Need at least a few nights of data
                guard nightlyDurations.count >= max(days / 4, 1) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let totalHours = nightlyDurations.reduce(0, +)
                let avgDuration = totalHours / Double(nightlyDurations.count)
                
                continuation.resume(returning: avgDuration)
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchHRVAverage30Days(endDate: Date) async -> Double? {
        if let avg30 = await fetchHRVAverageForDays(endDate: endDate, days: 30) {
            print("   HRV: 30-day average available")
            return avg30
        }
        
        print("   HRV: Insufficient 30-day data, using 7-day average")
        return await fetchHRVAverageForDays(endDate: endDate, days: 7)
    }
    
    // NOTE: HRV uses HKStatisticsQuery .discreteAverage which naturally averages only
    // across days WITH readings. No BUG-008 fix needed — HealthKit handles it.
    func fetchHRVAverageForDays(endDate: Date, days: Int) async -> Double? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, _ in
                if let average = statistics?.averageQuantity() {
                    let hrv = average.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    continuation.resume(returning: hrv)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchRHRAverage30Days(endDate: Date) async -> Double? {
        if let avg30 = await fetchRHRAverageForDays(endDate: endDate, days: 30) {
            print("   RHR: 30-day average available")
            return avg30
        }
        
        print("   RHR: Insufficient 30-day data, using 7-day average")
        return await fetchRHRAverageForDays(endDate: endDate, days: 7)
    }
    
    // NOTE: RHR uses HKStatisticsQuery .discreteAverage — same as HRV, no BUG-008 fix needed.
    func fetchRHRAverageForDays(endDate: Date, days: Int) async -> Double? {
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: rhrType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, _ in
                if let average = statistics?.averageQuantity() {
                    let rhr = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    continuation.resume(returning: rhr)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchWeightAverage30Days(endDate: Date) async -> Double? {
        if let avg30 = await fetchWeightAverageForDays(endDate: endDate, days: 30) {
            print("   Weight: 30-day average available")
            return avg30
        }
        
        print("   Weight: Insufficient 30-day data, using 7-day average")
        return await fetchWeightAverageForDays(endDate: endDate, days: 7)
    }
    
    private func fetchWeightAverageForDays(endDate: Date, days: Int) async -> Double? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: weightType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, _ in
                if let average = statistics?.averageQuantity() {
                    let weightInKg = average.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    let weightInLbs = weightInKg * 2.20462
                    continuation.resume(returning: weightInLbs)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchStepsAverage30Days(endDate: Date) async -> Double? {
        if let avg30 = await fetchStepsAverageForDays(endDate: endDate, days: 30) {
            print("   Steps: 30-day average available")
            return avg30
        }
        
        print("   Steps: Insufficient 30-day data, using 7-day average")
        return await fetchStepsAverageForDays(endDate: endDate, days: 7)
    }
    
    // ⭐ BUG-008 FIX: Steps average now counts actual days with data, not calendar days.
    // Steps uses cumulativeSum which sums ALL steps in the window into one total.
    // We need to know how many days actually had step data to divide correctly.
    // Use HKStatisticsCollectionQuery to get per-day breakdown.
    func fetchStepsAverageForDays(endDate: Date, days: Int) async -> Double? {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: endDate)!)
        let endOfToday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: endDate)!)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endOfToday, options: .strictStartDate)
        
        // Use collection query to get per-day totals
        let anchorDate = calendar.startOfDay(for: startDate)
        let interval = DateComponents(day: 1)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, error in
                guard let statsCollection = results else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var daysWithData = 0
                var totalSteps = 0.0
                
                statsCollection.enumerateStatistics(from: startDate, to: endOfToday) { statistics, _ in
                    if let sum = statistics.sumQuantity() {
                        let daySteps = sum.doubleValue(for: HKUnit.count())
                        if daySteps > 0 {
                            totalSteps += daySteps
                            daysWithData += 1
                        }
                    }
                }
                
                guard daysWithData > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let avgSteps = totalSteps / Double(daysWithData)
                print("📊 Steps avg: \(Int(totalSteps)) total over \(daysWithData) days with data → \(Int(avgSteps))/day")
                continuation.resume(returning: avgSteps)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Single-Day Helpers (for daily snapshots)
    
    private func fetchHRVForDate(_ date: Date) async -> Double? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, _ in
                if let average = statistics?.averageQuantity() {
                    let hrv = average.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    continuation.resume(returning: hrv)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchRHRForDate(_ date: Date) async -> Double? {
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: rhrType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, _ in
                if let average = statistics?.averageQuantity() {
                    let rhr = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    continuation.resume(returning: rhr)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchStepsForDate(_ date: Date) async -> Double? {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                if let sum = statistics?.sumQuantity() {
                    let steps = sum.doubleValue(for: HKUnit.count())
                    continuation.resume(returning: steps)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Individual Fetch Methods
    
    private func fetchAge() async -> Int? {
        do {
            let dateOfBirth = try healthStore.dateOfBirthComponents()
            let now = Calendar.current.dateComponents([.year], from: Date())
            if let birthYear = dateOfBirth.year, let currentYear = now.year {
                return currentYear - birthYear
            }
        } catch {
            print("Failed to fetch age: \(error)")
        }
        return nil
    }
    
    private func fetchBiologicalSex() async -> String? {
        do {
            let biologicalSex = try healthStore.biologicalSex()
            switch biologicalSex.biologicalSex {
            case .male: return "Male"
            case .female: return "Female"
            case .other: return "Other"
            case .notSet: return nil
            @unknown default: return nil
            }
        } catch {
            print("Failed to fetch biological sex: \(error)")
        }
        return nil
    }
    
    private func fetchHeight() async -> Double? {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, _ in
                if let sample = results?.first as? HKQuantitySample {
                    let heightInMeters = sample.quantity.doubleValue(for: HKUnit.meter())
                    let heightInInches = heightInMeters * 39.3701
                    continuation.resume(returning: heightInInches)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchWeight() async -> Double? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, _ in
                if let sample = results?.first as? HKQuantitySample {
                    let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    let weightInLbs = weightInKg * 2.20462
                    continuation.resume(returning: weightInLbs)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    /// Latest body fat sample as a fraction (0.18 = 18%).
    func fetchBodyFatPercentage() async -> Double? {
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: bodyFatType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, _ in
                if let sample = results?.first as? HKQuantitySample {
                    continuation.resume(returning: sample.quantity.doubleValue(for: HKUnit.percent()))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Body Composition Import (Sprint 2)

    /// Asks only for types the user hasn't been asked about yet (e.g. body fat,
    /// added after their original onboarding). No-op when nothing is new.
    func requestAuthorizationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let read: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
        ]
        let status: HKAuthorizationRequestStatus = await withCheckedContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: read) { status, _ in
                continuation.resume(returning: status)
            }
        }
        if status == .shouldRequest {
            try? await requestAuthorization()
        }
    }

    /// All samples of a quantity type since `start`, oldest first.
    private func fetchQuantitySamples(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, since start: Date) async -> [(date: Date, value: Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                let samples = (results as? [HKQuantitySample]) ?? []
                continuation.resume(returning: samples.map { (date: $0.endDate, value: $0.quantity.doubleValue(for: unit)) })
            }
            self.healthStore.execute(query)
        }
    }

    private static let bodyCompImportKey = "bodyCompHealthImportDate"

    /// Copies weight and body fat readings from Apple Health into BodyCompEntry,
    /// one entry per day. Days the user logged by hand keep their weight; a
    /// missing body fat value is filled in from Health. First run looks back a
    /// year, later runs only re-check the last few days.
    func importBodyComposition(modelContext: ModelContext) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let calendar = Calendar.current
        let defaults = UserDefaults.standard

        let start: Date
        if let last = defaults.object(forKey: Self.bodyCompImportKey) as? Date {
            start = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: last)) ?? last
        } else {
            start = calendar.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        }

        async let weightSamples = fetchQuantitySamples(.bodyMass, unit: .pound(), since: start)
        async let fatSamples = fetchQuantitySamples(.bodyFatPercentage, unit: .percent(), since: start)
        let weights = await weightSamples
        let fats = await fatSamples
        guard !weights.isEmpty || !fats.isEmpty else {
            defaults.set(Date(), forKey: Self.bodyCompImportKey)
            return
        }

        // Latest reading per day (samples are sorted oldest first)
        var weightByDay: [Date: (date: Date, value: Double)] = [:]
        for sample in weights where sample.value > 0 { weightByDay[calendar.startOfDay(for: sample.date)] = sample }
        var fatByDay: [Date: Double] = [:]
        for sample in fats where sample.value > 0 && sample.value < 1 { fatByDay[calendar.startOfDay(for: sample.date)] = sample.value }

        let existing = (try? modelContext.fetch(FetchDescriptor<BodyCompEntry>(
            predicate: #Predicate { $0.date >= start }
        ))) ?? []
        var entriesByDay: [Date: [BodyCompEntry]] = [:]
        for entry in existing { entriesByDay[calendar.startOfDay(for: entry.date), default: []].append(entry) }

        let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first
        var inserted = 0
        var updated = 0

        for day in Set(weightByDay.keys).union(fatByDay.keys) {
            let dayEntries = entriesByDay[day] ?? []
            let healthEntry = dayEntries.first { $0.isFromHealth }
            let manualEntries = dayEntries.filter { !$0.isFromHealth }
            let fat = fatByDay[day]

            if !manualEntries.isEmpty {
                // Hand-logged day: only fill a missing body fat value
                if let fat, let latest = manualEntries.max(by: { $0.date < $1.date }), latest.bodyFat == nil {
                    latest.bodyFat = fat
                    updated += 1
                }
                continue
            }

            if let healthEntry {
                if let w = weightByDay[day], abs(healthEntry.weight - w.value) > 0.01 {
                    healthEntry.weight = w.value
                    healthEntry.date = w.date
                    updated += 1
                }
                if let fat, healthEntry.bodyFat != fat {
                    healthEntry.bodyFat = fat
                    updated += 1
                }
            } else if let w = weightByDay[day] {
                let entry = BodyCompEntry(date: w.date, weight: w.value)
                entry.bodyFat = fat
                entry.source = "health"
                entry.userProfile = profile
                modelContext.insert(entry)
                inserted += 1
            }
            // A body fat reading with no weight that day is skipped: every entry needs a weight.
        }

        defaults.set(Date(), forKey: Self.bodyCompImportKey)
        if inserted + updated > 0 {
            try? modelContext.save()
            BodyProfileSync.apply(modelContext: modelContext)
            print("✅ [Body] Imported from Apple Health — \(inserted) new, \(updated) updated")
        }
    }

    // MARK: - Fetch Sleep for Specific Date
    func fetchSleepForDate(_ date: Date) async -> (duration: Double, bedtime: Date, wakeTime: Date)? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("❌ Sleep type not available")
            return nil
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        print("🔍 Fetching sleep for: \(date.formatted(date: .abbreviated, time: .shortened))")
        print("   Looking from: \(calendar.date(byAdding: .hour, value: -12, to: startOfDay)!.formatted(date: .abbreviated, time: .shortened))")
        print("   Until: \(endOfDay.formatted(date: .abbreviated, time: .shortened))")
        
        // Look for sleep that ENDED on this date
        let predicate = HKQuery.predicateForSamples(withStart: calendar.date(byAdding: .hour, value: -12, to: startOfDay), end: endOfDay, options: .strictEndDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { [weak self] _, results, error in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let samples = results as? [HKCategorySample], !samples.isEmpty else {
                    print("   Found 0 sleep samples from 0 source(s)")
                    continuation.resume(returning: nil)
                    return
                }
                
                let sources = Set(samples.map { $0.sourceRevision.source.bundleIdentifier })
                print("   Found \(samples.count) sleep samples from \(sources.count) source(s)")
                
                let dedupedSamples = self.deduplicateSleepSamples(samples)
                
                print("   After source dedup: \(dedupedSamples.count) samples")
                
                // Filter to only actual sleep stages (NOT inBed, NOT awake)
                let asleepSamples: [HKCategorySample]
                if #available(iOS 16.0, *) {
                    asleepSamples = dedupedSamples.filter { sample in
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    }
                } else {
                    asleepSamples = dedupedSamples.filter { sample in
                        sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }
                
                // Also get inBed + asleep for session boundaries (bedtime/wake time)
                let allSleepSamples = dedupedSamples.filter { sample in
                    if #available(iOS 16.0, *) {
                        return sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    } else {
                        return sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }
                
                print("   Found \(asleepSamples.count) asleep samples, \(allSleepSamples.count) total sleep/inBed samples")
                
                guard !asleepSamples.isEmpty else {
                    // Fallback: if no staged sleep data, try inBed samples
                    let inBedSamples = dedupedSamples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
                    if !inBedSamples.isEmpty {
                        let sessions = self.groupSleepSamples(inBedSamples)
                        if let longest = sessions.max(by: { $0.end.timeIntervalSince($0.start) < $1.end.timeIntervalSince($1.start) }) {
                            let duration = longest.end.timeIntervalSince(longest.start) / 3600.0
                            print("⚠️ No asleep stages found, falling back to inBed: \(String(format: "%.1f", duration))h")
                            continuation.resume(returning: (duration: duration, bedtime: longest.start, wakeTime: longest.end))
                            return
                        }
                    }
                    print("❌ No valid sleep session found")
                    continuation.resume(returning: nil)
                    return
                }
                
                // Group ALL sleep samples (including inBed) to find session boundaries
                let sessions = self.groupSleepSamples(allSleepSamples)
                
                print("   Grouped into \(sessions.count) sleep session(s)")
                
                // Find the longest session for bedtime/wake time
                guard let longestSession = sessions.max(by: { $0.end.timeIntervalSince($0.start) < $1.end.timeIntervalSince($1.start) }) else {
                    print("❌ No valid sleep session found")
                    continuation.resume(returning: nil)
                    return
                }
                
                // Sum actual asleep durations from samples within the longest session window
                let sessionBuffer: TimeInterval = 30 * 60 // 30 min buffer
                let asleepInSession = asleepSamples.filter { sample in
                    sample.startDate >= longestSession.start.addingTimeInterval(-sessionBuffer) &&
                    sample.endDate <= longestSession.end.addingTimeInterval(sessionBuffer)
                }
                
                // Sum individual sample durations (this is "Time Asleep", not "Time in Bed")
                let totalAsleepSeconds = asleepInSession.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                let duration = totalAsleepSeconds / 3600.0
                
                let sessionSpan = longestSession.end.timeIntervalSince(longestSession.start) / 3600.0
                print("   Session span: \(String(format: "%.1f", sessionSpan))h (bed to wake)")
                print("✅ Time asleep: \(String(format: "%.1f", duration))h (summed sleep stages, deduped)")
                
                continuation.resume(returning: (duration: duration, bedtime: longestSession.start, wakeTime: longestSession.end))
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - BUG-004: Source deduplication for sleep data
    private func deduplicateSleepSamples(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        guard !samples.isEmpty else { return samples }
        
        let appleSourcePrefixes = ["com.apple"]
        
        func isAppleSource(_ sample: HKCategorySample) -> Bool {
            let bundle = sample.sourceRevision.source.bundleIdentifier
            return appleSourcePrefixes.contains(where: { bundle.hasPrefix($0) })
        }
        
        let appleSamples = samples.filter { isAppleSource($0) }
        let thirdPartySamples = samples.filter { !isAppleSource($0) }
        
        guard !thirdPartySamples.isEmpty else {
            print("🛏️ Source dedup: only Apple sources — no dedup needed (\(appleSamples.count) samples)")
            return appleSamples
        }
        
        guard !appleSamples.isEmpty else {
            print("🛏️ Source dedup: only third-party sources — using as-is (\(thirdPartySamples.count) samples)")
            return thirdPartySamples
        }
        
        let appleSessions = groupSleepSamples(appleSamples)
        
        let sessionBuffer: TimeInterval = 2 * 3600
        let nonOverlappingThirdParty = thirdPartySamples.filter { tpSample in
            !appleSessions.contains { session in
                tpSample.startDate < session.end.addingTimeInterval(sessionBuffer) &&
                tpSample.endDate > session.start.addingTimeInterval(-sessionBuffer)
            }
        }
        
        let totalSources = Set(samples.map { $0.sourceRevision.source.bundleIdentifier })
        print("🛏️ Source dedup: \(totalSources.count) source(s) → kept \(appleSamples.count) Apple + \(nonOverlappingThirdParty.count) non-overlapping third-party (discarded \(thirdPartySamples.count - nonOverlappingThirdParty.count) duplicates)")
        
        return appleSamples + nonOverlappingThirdParty
    }
    
    /// Group overlapping sleep samples into continuous sessions
    private func groupSleepSamples(_ samples: [HKCategorySample]) -> [(start: Date, end: Date)] {
        guard !samples.isEmpty else { return [] }
        
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var sessions: [(start: Date, end: Date)] = []
        
        var currentStart = sorted[0].startDate
        var currentEnd = sorted[0].endDate
        
        for sample in sorted.dropFirst() {
            if sample.startDate <= currentEnd.addingTimeInterval(2 * 3600) {
                currentEnd = max(currentEnd, sample.endDate)
            } else {
                sessions.append((start: currentStart, end: currentEnd))
                currentStart = sample.startDate
                currentEnd = sample.endDate
            }
        }
        
        sessions.append((start: currentStart, end: currentEnd))
        
        return sessions
    }
    
    private func fetchVO2Max() async -> Double? {
        guard let vo2MaxType = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: vo2MaxType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, _ in
                if let sample = results?.first as? HKQuantitySample {
                    let vo2Max = sample.quantity.doubleValue(for: HKUnit(from: "ml/kg*min"))
                    continuation.resume(returning: vo2Max)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRate() async -> Double? {
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: rhrType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, _ in
                if let average = statistics?.averageQuantity() {
                    let rhr = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    continuation.resume(returning: rhr)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchHeartRateVariability() async -> Double? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, _ in
                if let average = statistics?.averageQuantity() {
                    let hrv = average.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    continuation.resume(returning: hrv)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Daily Metrics Sync (OLD - DEPRECATED, USE syncMetricsWithSmartRefresh INSTEAD)

    func syncYesterdaysMetricsIfNeeded(modelContext: ModelContext) async {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        
        let descriptor = FetchDescriptor<HealthMetrics>(
            predicate: #Predicate { $0.date == startOfYesterday }
        )
        
        do {
            let existingMetrics = try modelContext.fetch(descriptor)
            
            if existingMetrics.isEmpty {
                print("📊 No metrics for yesterday, fetching from HealthKit...")
                let metrics = await fetchDailySnapshot(for: yesterday)
                modelContext.insert(metrics)
                try modelContext.save()
                print("✅ Yesterday's metrics saved")
            } else {
                print("✅ Yesterday's metrics already exist")
            }
        } catch {
            print("❌ Failed to sync yesterday's metrics: \(error)")
        }
    }
    
    // MARK: - ⭐ ENHANCED METRICS SYNC (WITH DEBOUNCE) ⭐
    
    /// Debounced sync — prevents multiple simultaneous calls from HealthKit observers,
    /// .task modifier, and foreground notifications all firing at once on app launch.
    func syncMetricsWithSmartRefresh(modelContext: ModelContext) async {
        // Gate: if we already synced within the last 30 seconds, skip
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < minimumSyncInterval {
            print("📊 Sync skipped — last sync was \(Int(Date().timeIntervalSince(lastSync)))s ago (min \(Int(minimumSyncInterval))s)")
            return
        }
        
        // Gate: if another sync is actively running, flag that we want a re-sync after
        guard !isSyncing else {
            syncRequestedWhileBusy = true
            print("📊 Sync already in progress — will re-sync after current completes")
            return
        }
        
        isSyncing = true
        lastSyncDate = Date()
        
        print("📊 Starting smart metrics sync...")
        
        await syncToday(modelContext: modelContext)
        await syncYesterdayWithRefresh(modelContext: modelContext)
        // 30 days of history feeds the Recovery Score's personal baselines
        await syncMissingMetrics(modelContext: modelContext, daysBack: 30)
        
        print("✅ Smart metrics sync complete")
        
        isSyncing = false
        
        // If someone requested a sync while we were busy, do one more pass
        if syncRequestedWhileBusy {
            syncRequestedWhileBusy = false
            // Don't re-sync immediately — the debounce interval will catch it on next trigger
            print("📊 Deferred sync request noted — will run on next trigger")
        }
    }
    
    /// Syncs this morning's recovery inputs: last night's sleep plus today's
    /// HRV and resting heart rate (Apple Watch records both overnight).
    private func syncToday(modelContext: ModelContext) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        print("📊 Syncing today's recovery inputs...")
        
        let sleepData = await fetchSleepForDate(Date())
        let hrv = await fetchHRVForDate(Date())
        let rhr = await fetchRHRForDate(Date())
        
        guard sleepData != nil || hrv != nil || rhr != nil else {
            print("⚠️ No recovery data available for today yet")
            return
        }
        
        let descriptor = FetchDescriptor<HealthMetrics>(
            predicate: #Predicate { $0.date == today }
        )
        
        do {
            let metrics: HealthMetrics
            if let existing = try modelContext.fetch(descriptor).first {
                metrics = existing
            } else {
                metrics = HealthMetrics(date: today)
                modelContext.insert(metrics)
            }
            
            if let sleepData {
                metrics.sleepDuration = sleepData.duration
                metrics.bedtime = sleepData.bedtime
                metrics.wakeTime = sleepData.wakeTime
            }
            if let hrv { metrics.heartRateVariability = hrv }
            if let rhr { metrics.restingHeartRate = rhr }
            
            try modelContext.save()
            print("✅ Today's recovery inputs — sleep: \(sleepData.map { String(format: "%.1f", $0.duration) } ?? "–")h, HRV: \(hrv.map { String(format: "%.0f", $0) } ?? "–"), RHR: \(rhr.map { String(format: "%.0f", $0) } ?? "–")")
        } catch {
            print("❌ Failed to sync today's recovery inputs: \(error)")
        }
    }
    
    private func syncYesterdayWithRefresh(modelContext: ModelContext) async {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        
        let descriptor = FetchDescriptor<HealthMetrics>(
            predicate: #Predicate { $0.date == startOfYesterday }
        )
        
        do {
            let existingMetrics = try modelContext.fetch(descriptor)
            
            if let existing = existingMetrics.first {
                let needsRefresh = isDataIncomplete(existing) || isDataStale(existing)
                
                if needsRefresh {
                    print("📊 Yesterday's data is stale/incomplete, refreshing...")
                    let freshMetrics = await fetchDailySnapshot(for: yesterday)
                    
                    existing.sleepDuration = freshMetrics.sleepDuration
                    existing.heartRateVariability = freshMetrics.heartRateVariability
                    existing.restingHeartRate = freshMetrics.restingHeartRate
                    existing.stepCount = freshMetrics.stepCount
                    existing.vo2Max = freshMetrics.vo2Max
                    existing.weight = freshMetrics.weight
                    
                    try modelContext.save()
                    print("✅ Refreshed yesterday's metrics")
                } else {
                    print("✅ Yesterday's metrics are fresh")
                }
            } else {
                print("📊 No metrics for yesterday, fetching...")
                let metrics = await fetchDailySnapshot(for: yesterday)
                modelContext.insert(metrics)
                try modelContext.save()
                print("✅ Created yesterday's metrics")
            }
        } catch {
            print("❌ Failed to sync yesterday's metrics: \(error)")
        }
    }
    
    private func isDataIncomplete(_ metrics: HealthMetrics) -> Bool {
        return metrics.heartRateVariability == nil || 
               metrics.restingHeartRate == nil || 
               metrics.stepCount == nil
    }
    
    private func isDataStale(_ metrics: HealthMetrics) -> Bool {
        let calendar = Calendar.current
        let metricsDate = metrics.date
        
        guard let expectedAvailableTime = calendar.date(byAdding: .hour, value: 32, to: metricsDate) else {
            return false
        }
        
        return Date() > expectedAvailableTime.addingTimeInterval(4 * 3600)
    }
    
    // MARK: - HealthKit Observers (Debounced)
    
    func setupHealthKitObservers(modelContext: ModelContext) {
        print("📊 Setting up HealthKit observers...")
        
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            setupObserver(for: sleepType, modelContext: modelContext, name: "Sleep")
        }
        
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            setupObserver(for: hrvType, modelContext: modelContext, name: "HRV")
        }
        
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            setupObserver(for: stepsType, modelContext: modelContext, name: "Steps")
        }
        
        print("✅ HealthKit observers active")
    }
    
    private func setupObserver(for sampleType: HKSampleType, modelContext: ModelContext, name: String) {
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] query, completionHandler, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Observer error for \(name): \(error)")
                completionHandler()
                return
            }
            
            print("📊 \(name) data updated in HealthKit - syncing...")
            
            Task { @MainActor in
                await self.syncMetricsWithSmartRefresh(modelContext: modelContext)
                completionHandler()
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - ⭐ PERIODIC REFRESH ⭐
    
    func startPeriodicRefresh(modelContext: ModelContext) -> Timer {
        print("⏰ Starting periodic refresh (every 2 hours)")
        
        return Timer.scheduledTimer(withTimeInterval: 7200, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            print("⏰ Periodic refresh triggered")
            Task { @MainActor in
                await self.syncMetricsWithSmartRefresh(modelContext: modelContext)
            }
        }
    }

    // MARK: - Workout Fetching

    func fetchRecentWorkouts() async -> [WorkoutSummary] {
        let workoutType = HKObjectType.workoutType()
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -3, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 20, sortDescriptors: [sortDescriptor]) { _, results, error in
                guard let workouts = results as? [HKWorkout] else {
                    print("❌ Failed to fetch workouts: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: [])
                    return
                }
                
                Task {
                    var summaries: [WorkoutSummary] = []
                    
                    for workout in workouts {
                        let hrData = await self.fetchHeartRateForWorkout(workout)
                        
                        let summary = WorkoutSummary(
                            id: UUID(),
                            workoutType: self.workoutTypeName(workout.workoutActivityType),
                            startDate: workout.startDate,
                            duration: workout.duration,
                            avgHeartRate: hrData.avg,
                            maxHeartRate: hrData.max,
                            calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                            distance: workout.totalDistance?.doubleValue(for: .mile()),
                            hkWorkout: workout
                        )
                        summaries.append(summary)
                    }
                    
                    print("✅ Fetched \(summaries.count) workouts from last 3 days")
                    continuation.resume(returning: summaries)
                }
            }
            self.healthStore.execute(query)
        }
    }

    private func fetchHeartRateForWorkout(_ workout: HKWorkout) async -> (avg: Double?, max: Double?) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return (nil, nil)
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax]
            ) { _, statistics, _ in
                let avgHR = statistics?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let maxHR = statistics?.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: (avgHR, maxHR))
            }
            self.healthStore.execute(query)
        }
    }

    /// Convert HKWorkoutActivityType to readable string
    private func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .crossTraining: return "Cross Training"
        case .mixedCardio: return "Mixed Cardio"
        case .highIntensityIntervalTraining: return "HIIT"
        case .jumpRope: return "Jump Rope"
        case .kickboxing: return "Kickboxing"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        case .cooldown: return "Cooldown"
        case .coreTraining: return "Core Training"
        default: return "Workout"
        }
    }

    /// Fetch detailed heart rate samples for a specific workout
    func fetchHeartRateSamples(for workout: HKWorkout) async -> [HRSample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample] else {
                    print("❌ Failed to fetch HR samples: \(error?.localizedDescription ?? "Unknown")")
                    continuation.resume(returning: [])
                    return
                }

                let hrSamples = samples.map { sample in
                    HRSample(
                        timestamp: sample.startDate,
                        bpm: sample.quantity.doubleValue(
                            for: HKUnit.count().unitDivided(by: .minute())
                        )
                    )
                }

                print("✅ Fetched \(hrSamples.count) HR samples for workout")
                continuation.resume(returning: hrSamples)
            }
            self.healthStore.execute(query)
        }
    }

    /// Fetch HR samples for the 3-minute window after a workout ends (for post-workout recovery)
    func fetchPostWorkoutHRSamples(for workout: HKWorkout) async -> [HRSample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.endDate,
            end: workout.endDate.addingTimeInterval(180),
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let hrSamples = samples.map { sample in
                    HRSample(
                        timestamp: sample.startDate,
                        bpm: sample.quantity.doubleValue(
                            for: HKUnit.count().unitDivided(by: .minute())
                        )
                    )
                }

                print("✅ Fetched \(hrSamples.count) post-workout HR samples")
                continuation.resume(returning: hrSamples)
            }
            self.healthStore.execute(query)
        }
    }

    /// Full workout analysis
    func analyzeWorkout(
        _ workout: HKWorkout,
        age: Int,
        restingHR: Double?
    ) async -> WorkoutAnalysisResult {
        let zones = CardioZoneCalculator.calculateZones(age: age, restingHR: restingHR)
        let duration = Int(workout.duration / 60)

        let workoutSamples = await fetchHeartRateSamples(for: workout)
        let postSamples = await fetchPostWorkoutHRSamples(for: workout)

        let maxHR = workoutSamples.map(\.bpm).max()
            ?? workout.statistics(for: HKQuantityType(.heartRate))?
                .maximumQuantity()?
                .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        let allSamples = workoutSamples + postSamples

        let result = CardioWorkoutAnalyzer.analyze(
            samples: workoutSamples,
            zones: zones,
            duration: duration,
            workoutType: workout.workoutActivityType,
            maxHeartRate: maxHR,
            allSamplesIncludingPostWorkout: allSamples,
            workoutEndDate: workout.endDate
        )

        print("✅ Workout analyzed: \(result.activityType.rawValue)")
        print("   Zone breakdown: Z1=\(result.zoneBreakdown.zone1Minutes)m Z2=\(result.zoneBreakdown.zone2Minutes)m Z3=\(result.zoneBreakdown.zone3Minutes)m Z4=\(result.zoneBreakdown.zone4Minutes)m Z5=\(result.zoneBreakdown.zone5Minutes)m")
        print("   Intervals: \(result.intervals.count)")
        if let drop = result.postWorkoutRecoveryDrop {
            print("   Post-workout recovery: -\(Int(drop)) BPM in 60s")
        }

        return result
    }

    /// Check if a workout has already been imported (by HealthKit UUID)
    func isWorkoutAlreadyImported(_ workout: HKWorkout, modelContext: ModelContext) -> Bool {
        let workoutUUID = workout.uuid.uuidString
        let descriptor = FetchDescriptor<CardioSession>(
            predicate: #Predicate<CardioSession> { $0.healthKitWorkoutID == workoutUUID }
        )
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }
}

enum HealthKitError: Error {
    case notAvailable
}