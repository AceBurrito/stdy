import Foundation

// MARK: - Pace Result
struct PaceResult {
    let paceValue: Double              // 0.85 to 1.25 (lower = aging slower)
    let compositePercentile: Double    // 0-100
    let confidenceLevel: String        // "full", "limited", "partial"
    let componentsAvailable: Int       // 0-6
    
    // Individual component percentiles (nil if data missing)
    let sleepPercentile: Double?
    let hrvPercentile: Double?
    let rhrPercentile: Double?
    let vo2MaxPercentile: Double?
    let stepsPercentile: Double?
    let strengthPercentile: Double?
    
    // Raw inputs used (for transparency)
    let sleepHoursUsed: Double?
    let hrvUsed: Double?
    let rhrUsed: Double?
    let vo2MaxUsed: Double?
    let stepsUsed: Double?
    
    // Trend (set separately after historical lookup)
    var trend30Day: Double?            // Change in Pace over 30 days (negative = improving)
    var trendDirection: String?        // "improving", "stable", "declining"
    
    // Which components are helping/hurting most
    var strongestComponent: String?    // e.g., "sleep"
    var weakestComponent: String?      // e.g., "vo2Max"
}

// MARK: - Pace Calculator
struct LifespanPaceCalculator {
    
    // Component weights (based on mortality prediction research)
    private static let weights: [(name: String, weight: Double)] = [
        ("sleep", 0.20),       // Cappuccio et al. meta-analysis
        ("hrv", 0.20),         // Tsuji et al., Framingham
        ("rhr", 0.15),         // Copenhagen City Heart Study
        ("vo2Max", 0.20),      // Mandsager et al. (JACC 2018)
        ("steps", 0.10),       // Paluch et al. (Lancet 2022)
        ("strength", 0.15)     // Composite: JAMA 2019, Brito, Leong
    ]
    
    // Percentile-to-Pace anchor points (sigmoid-adjusted)
    // Lower Pace = better (aging slower)
    private static let paceAnchors: [(percentile: Double, pace: Double)] = [
        (5.0, 1.25),
        (20.0, 1.12),
        (40.0, 1.04),
        (50.0, 1.00),
        (60.0, 0.97),
        (80.0, 0.92),
        (95.0, 0.85)
    ]
    
    // MARK: - Main Calculation
    
    static func calculate(
        age: Int,
        gender: String?,
        // 7-day averages (or latest available)
        sleepAverage: Double?,        // hours
        hrvAverage: Double?,          // ms SDNN
        rhrAverage: Double?,          // bpm
        vo2Max: Double?,              // ml/kg/min
        stepsAverage: Double?,        // daily count
        // Body
        bodyweight: Double?,          // lbs
        height: Double?,              // inches
        // Strength assessment
        pushupRange: String?,         // "0-5", "6-15", "16-30", "31-50", "50+"
        canStandFromSitting: Bool?,
        deadHangRange: String?,       // "cant", "under_15", "15-30", "30-60", "60+"
        benchPressMax: Double?,       // lbs
        squatMax: Double?,            // lbs
        deadliftMax: Double?,         // lbs
        // Strength data confidence
        strengthDataSource: String = "selfReported"  // "selfReported", "bodyweightOnly", "dontKnow", "workoutDerived"
    ) -> PaceResult {
        
        // Step 1: Calculate individual percentiles
        let sleepPct = sleepAverage.map { AgeGenderNorms.sleepPercentile(value: $0, age: age, gender: gender) }
        let hrvPct = hrvAverage.map { AgeGenderNorms.hrvPercentile(value: $0, age: age, gender: gender) }
        let rhrPct = rhrAverage.map { AgeGenderNorms.rhrPercentile(value: $0, age: age, gender: gender) }
        let vo2Pct = vo2Max.map { AgeGenderNorms.vo2MaxPercentile(value: $0, age: age, gender: gender) }
        let stepsPct = stepsAverage.map { AgeGenderNorms.stepsPercentile(value: $0, age: age, gender: gender) }
        
        // Calculate raw strength percentile
        let rawStrengthPct = AgeGenderNorms.strengthPercentile(
            age: age,
            gender: gender,
            pushupRange: pushupRange,
            canStandFromSitting: canStandFromSitting,
            deadHangRange: deadHangRange,
            benchPressMax: benchPressMax,
            squatMax: squatMax,
            deadliftMax: deadliftMax,
            bodyweight: bodyweight
        )
        
        // Apply confidence discount based on data source
        let strengthPct: Double? = rawStrengthPct.map {
            AgeGenderNorms.adjustedStrengthPercentile(rawPercentile: $0, source: strengthDataSource)
        }
        
        // Step 2: Build available components with weights
        var availableComponents: [(name: String, percentile: Double, baseWeight: Double)] = []
        
        if let pct = sleepPct { availableComponents.append(("sleep", pct, 0.20)) }
        if let pct = hrvPct { availableComponents.append(("hrv", pct, 0.20)) }
        if let pct = rhrPct { availableComponents.append(("rhr", pct, 0.15)) }
        if let pct = vo2Pct { availableComponents.append(("vo2Max", pct, 0.20)) }
        if let pct = stepsPct { availableComponents.append(("steps", pct, 0.10)) }
        if let pct = strengthPct { availableComponents.append(("strength", pct, 0.15)) }
        
        let componentCount = availableComponents.count
        
        // Step 3: Determine confidence level
        let confidence: String
        switch componentCount {
        case 5...6: confidence = "full"
        case 3...4: confidence = "limited"
        case 1...2: confidence = "partial"
        default: confidence = "insufficient"
        }
        
        // Step 4: If no components, return insufficient data result
        guard componentCount > 0 else {
            return PaceResult(
                paceValue: 1.0,
                compositePercentile: 50.0,
                confidenceLevel: "insufficient",
                componentsAvailable: 0,
                sleepPercentile: nil,
                hrvPercentile: nil,
                rhrPercentile: nil,
                vo2MaxPercentile: nil,
                stepsPercentile: nil,
                strengthPercentile: nil,
                sleepHoursUsed: nil,
                hrvUsed: nil,
                rhrUsed: nil,
                vo2MaxUsed: nil,
                stepsUsed: nil,
                trend30Day: nil,
                trendDirection: nil,
                strongestComponent: nil,
                weakestComponent: nil
            )
        }
        
        // Step 5: Redistribute weights proportionally for missing components
        let totalAvailableWeight = availableComponents.reduce(0.0) { $0 + $1.baseWeight }
        let weightMultiplier = 1.0 / totalAvailableWeight
        
        // Step 6: Calculate weighted composite percentile
        var compositePercentile = 0.0
        for component in availableComponents {
            let adjustedWeight = component.baseWeight * weightMultiplier
            compositePercentile += component.percentile * adjustedWeight
        }
        
        // Clamp composite percentile to valid range
        compositePercentile = max(1.0, min(99.0, compositePercentile))
        
        // Step 7: Map composite percentile to Pace value
        let paceValue = percentileToPace(compositePercentile)
        
        // Step 8: Find strongest and weakest components
        let sorted = availableComponents.sorted { $0.percentile > $1.percentile }
        let strongest = sorted.first?.name
        let weakest = sorted.last?.name
        
        // Step 9: Build result
        return PaceResult(
            paceValue: paceValue,
            compositePercentile: compositePercentile,
            confidenceLevel: confidence,
            componentsAvailable: componentCount,
            sleepPercentile: sleepPct,
            hrvPercentile: hrvPct,
            rhrPercentile: rhrPct,
            vo2MaxPercentile: vo2Pct,
            stepsPercentile: stepsPct,
            strengthPercentile: strengthPct,
            sleepHoursUsed: sleepAverage,
            hrvUsed: hrvAverage,
            rhrUsed: rhrAverage,
            vo2MaxUsed: vo2Max,
            stepsUsed: stepsAverage,
            trend30Day: nil,
            trendDirection: nil,
            strongestComponent: strongest,
            weakestComponent: weakest
        )
    }
    
    // MARK: - Percentile to Pace Mapping
    // Uses smooth interpolation between anchor points with sigmoid compression at extremes
    
    private static func percentileToPace(_ percentile: Double) -> Double {
        let anchors = paceAnchors
        
        // Below minimum anchor
        if percentile <= anchors.first!.percentile {
            return anchors.first!.pace
        }
        
        // Above maximum anchor
        if percentile >= anchors.last!.percentile {
            return anchors.last!.pace
        }
        
        // Interpolate between anchor points using smoothstep for natural curve
        for i in 0..<(anchors.count - 1) {
            let lower = anchors[i]
            let upper = anchors[i + 1]
            
            if percentile >= lower.percentile && percentile <= upper.percentile {
                // Normalized position between anchors (0 to 1)
                let t = (percentile - lower.percentile) / (upper.percentile - lower.percentile)
                
                // Smoothstep interpolation (cubic Hermite) for natural feel
                let smooth = t * t * (3.0 - 2.0 * t)
                
                // Interpolate pace value
                let pace = lower.pace + smooth * (upper.pace - lower.pace)
                
                // Hard clamp to valid range
                return max(0.85, min(1.25, pace))
            }
        }
        
        // Fallback (shouldn't reach here)
        return 1.0
    }
    
    // MARK: - Trend Calculation
    
    /// Calculate 30-day trend from historical Pace scores
    /// Returns (trendValue, trendDirection)
    /// trendValue: negative = improving (Pace going down), positive = declining
    static func calculateTrend(
        currentPace: Double,
        historicalScores: [(date: Date, paceValue: Double)]
    ) -> (trend: Double?, direction: String?) {
        
        // Need at least 7 days of history for a meaningful trend
        guard historicalScores.count >= 7 else {
            return (nil, nil)
        }
        
        // Get the score from ~30 days ago (or earliest available)
        let sortedScores = historicalScores.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        // Find the score closest to 30 days ago
        let referenceScore = sortedScores.first { $0.date >= thirtyDaysAgo }?.paceValue
            ?? sortedScores.first?.paceValue
        
        guard let reference = referenceScore else {
            return (nil, nil)
        }
        
        let trend = currentPace - reference  // negative = improving
        
        let direction: String
        if trend < -0.02 {
            direction = "improving"
        } else if trend > 0.02 {
            direction = "declining"
        } else {
            direction = "stable"
        }
        
        return (trend, direction)
    }
    
    // MARK: - Strength Reassessment Check
    
    /// Check if user should be prompted for strength reassessment (30+ days)
    static func shouldPromptStrengthReassessment(
        pushupRange: String?,
        lastAssessmentDate: Date?
    ) -> Bool {
        // No assessment exists
        guard pushupRange != nil else { return true }
        
        // Check if 30+ days since last assessment
        guard let lastDate = lastAssessmentDate else { return true }
        
        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return daysSince >= 30
    }
    
    // MARK: - Debug Description
    
    static func debugDescription(for result: PaceResult) -> String {
        var lines: [String] = []
        lines.append("=== Pace Score Debug ===")
        lines.append("Pace: \(String(format: "%.2f", result.paceValue))")
        lines.append("Composite Percentile: \(String(format: "%.1f", result.compositePercentile))th")
        lines.append("Confidence: \(result.confidenceLevel) (\(result.componentsAvailable)/6 components)")
        lines.append("")
        
        if let pct = result.sleepPercentile {
            lines.append("  Sleep: \(String(format: "%.1f", pct))th pct (\(String(format: "%.1f", result.sleepHoursUsed ?? 0))h)")
        }
        if let pct = result.hrvPercentile {
            lines.append("  HRV: \(String(format: "%.1f", pct))th pct (\(String(format: "%.0f", result.hrvUsed ?? 0))ms)")
        }
        if let pct = result.rhrPercentile {
            lines.append("  RHR: \(String(format: "%.1f", pct))th pct (\(String(format: "%.0f", result.rhrUsed ?? 0))bpm)")
        }
        if let pct = result.vo2MaxPercentile {
            lines.append("  VO2 Max: \(String(format: "%.1f", pct))th pct (\(String(format: "%.1f", result.vo2MaxUsed ?? 0)) ml/kg/min)")
        }
        if let pct = result.stepsPercentile {
            lines.append("  Steps: \(String(format: "%.1f", pct))th pct (\(String(format: "%.0f", result.stepsUsed ?? 0))/day)")
        }
        if let pct = result.strengthPercentile {
            lines.append("  Strength: \(String(format: "%.1f", pct))th pct")
        }
        
        lines.append("")
        if let strongest = result.strongestComponent {
            lines.append("  💪 Strongest: \(strongest)")
        }
        if let weakest = result.weakestComponent {
            lines.append("  ⚠️ Weakest: \(weakest)")
        }
        if let trend = result.trend30Day, let dir = result.trendDirection {
            lines.append("  📈 30-day trend: \(String(format: "%+.3f", trend)) (\(dir))")
        }
        
        return lines.joined(separator: "\n")
    }
}