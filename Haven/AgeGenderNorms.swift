import Foundation

// MARK: - Age/Gender Percentile Norms
// Sources: Nunan et al. (HRV), Framingham (RHR), Cooper Institute/ACSM (VO2 Max),
// Cappuccio et al. (Sleep), Paluch et al. (Steps), JAMA/Lancet (Strength)
//
// Each metric returns a percentile (0-100) for a given value, age, and gender.
// Age brackets: 18-29, 30-39, 40-49, 50-59, 60-69, 70+
// Gender: "Male", "Female", nil/other (averages both)

struct AgeGenderNorms {
    
    // MARK: - Age Bracket Helper
    
    enum AgeBracket: String, CaseIterable {
        case age18to29 = "18-29"
        case age30to39 = "30-39"
        case age40to49 = "40-49"
        case age50to59 = "50-59"
        case age60to69 = "60-69"
        case age70plus = "70+"
        
        static func bracket(for age: Int) -> AgeBracket {
            switch age {
            case ..<18: return .age18to29  // Treat under 18 as youngest bracket
            case 18...29: return .age18to29
            case 30...39: return .age30to39
            case 40...49: return .age40to49
            case 50...59: return .age50to59
            case 60...69: return .age60to69
            default: return .age70plus
            }
        }
    }
    
    // MARK: - Distribution Definition
    // Each distribution is defined by percentile anchor points (p5, p25, p50, p75, p95)
    // We interpolate smoothly between these to get any percentile
    
    struct Distribution {
        let p5: Double
        let p25: Double
        let p50: Double   // median
        let p75: Double
        let p95: Double
        
        /// Given a raw value, return the percentile (0-100)
        /// Uses linear interpolation between anchor points
        func percentile(for value: Double, higherIsBetter: Bool = true) -> Double {
            let anchors: [(percentile: Double, value: Double)]
            
            if higherIsBetter {
                // Higher value = higher percentile (HRV, VO2 Max, steps, sleep quality)
                anchors = [
                    (5.0, p5),
                    (25.0, p25),
                    (50.0, p50),
                    (75.0, p75),
                    (95.0, p95)
                ]
            } else {
                // Lower value = higher percentile (RHR)
                anchors = [
                    (95.0, p5),    // Lowest RHR = highest percentile
                    (75.0, p25),
                    (50.0, p50),
                    (25.0, p75),
                    (5.0, p95)     // Highest RHR = lowest percentile
                ]
            }
            
            // Sort anchors by value for interpolation
            let sorted = anchors.sorted { $0.value < $1.value }
            
            // Below minimum
            if value <= sorted.first!.value {
                return sorted.first!.percentile
            }
            
            // Above maximum
            if value >= sorted.last!.value {
                return sorted.last!.percentile
            }
            
            // Interpolate between anchor points
            for i in 0..<(sorted.count - 1) {
                let lower = sorted[i]
                let upper = sorted[i + 1]
                
                if value >= lower.value && value <= upper.value {
                    let fraction = (value - lower.value) / (upper.value - lower.value)
                    return lower.percentile + fraction * (upper.percentile - lower.percentile)
                }
            }
            
            return 50.0  // Fallback
        }
    }
    
    // MARK: - Strength Confidence Discount
    // Self-reported strength data is notoriously inflated.
    // Apply a confidence discount based on data source.
    // Real workout data (e1RM) gets full confidence.
    
    /// Apply confidence discount to strength percentile based on data source
    /// - Parameters:
    ///   - rawPercentile: The raw calculated strength percentile (0-100)
    ///   - source: Where the strength data came from
    /// - Returns: Adjusted percentile accounting for data reliability
    static func adjustedStrengthPercentile(
        rawPercentile: Double,
        source: String
    ) -> Double {
        switch source {
        case "selfReported":
            // 25% discount — memory inflation, ego bias
            return rawPercentile * 0.75
        case "bodyweightOnly":
            // 10% discount — harder to inflate effort-based tests
            return rawPercentile * 0.90
        case "dontKnow":
            // User doesn't know their maxes — not lifting consistently
            // Score at 27th percentile regardless of bodyweight assessments
            return 27.0
        case "workoutDerived":
            // Full confidence — verified through actual performance
            return rawPercentile
        default:
            // Unknown source — treat as self-reported
            return rawPercentile * 0.75
        }
    }
    
    // MARK: - HRV Percentiles (SDNN in ms)
    // Source: Nunan et al. systematic review, age-decade brackets
    // Higher HRV = better
    
    static func hrvPercentile(value: Double, age: Int, gender: String?) -> Double {
        let dist = hrvDistribution(age: age, gender: gender)
        return dist.percentile(for: value, higherIsBetter: true)
    }
    
    private static func hrvDistribution(age: Int, gender: String?) -> Distribution {
        let bracket = AgeBracket.bracket(for: age)
        
        // Male HRV norms (SDNN ms)
        let maleNorms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 20, p25: 35, p50: 50, p75: 70, p95: 105),
            .age30to39: Distribution(p5: 18, p25: 30, p50: 42, p75: 60, p95: 90),
            .age40to49: Distribution(p5: 14, p25: 24, p50: 35, p75: 50, p95: 78),
            .age50to59: Distribution(p5: 12, p25: 20, p50: 30, p75: 42, p95: 65),
            .age60to69: Distribution(p5: 10, p25: 17, p50: 26, p75: 38, p95: 58),
            .age70plus: Distribution(p5: 8, p25: 14, p50: 22, p75: 33, p95: 50)
        ]
        
        // Female HRV norms (slightly lower on average)
        let femaleNorms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 18, p25: 32, p50: 46, p75: 65, p95: 95),
            .age30to39: Distribution(p5: 16, p25: 27, p50: 38, p75: 55, p95: 82),
            .age40to49: Distribution(p5: 12, p25: 22, p50: 32, p75: 46, p95: 70),
            .age50to59: Distribution(p5: 10, p25: 18, p50: 27, p75: 39, p95: 60),
            .age60to69: Distribution(p5: 8, p25: 15, p50: 23, p75: 35, p95: 52),
            .age70plus: Distribution(p5: 7, p25: 12, p50: 20, p75: 30, p95: 45)
        ]
        
        switch gender?.lowercased() {
        case "male":
            return maleNorms[bracket] ?? maleNorms[.age40to49]!
        case "female":
            return femaleNorms[bracket] ?? femaleNorms[.age40to49]!
        default:
            // Average of male and female
            let male = maleNorms[bracket] ?? maleNorms[.age40to49]!
            let female = femaleNorms[bracket] ?? femaleNorms[.age40to49]!
            return Distribution(
                p5: (male.p5 + female.p5) / 2,
                p25: (male.p25 + female.p25) / 2,
                p50: (male.p50 + female.p50) / 2,
                p75: (male.p75 + female.p75) / 2,
                p95: (male.p95 + female.p95) / 2
            )
        }
    }
    
    // MARK: - Resting Heart Rate Percentiles (bpm)
    // Source: Framingham Heart Study, Copenhagen City Heart Study
    // Lower RHR = better
    
    static func rhrPercentile(value: Double, age: Int, gender: String?) -> Double {
        let dist = rhrDistribution(age: age, gender: gender)
        return dist.percentile(for: value, higherIsBetter: false)
    }
    
    private static func rhrDistribution(age: Int, gender: String?) -> Distribution {
        let bracket = AgeBracket.bracket(for: age)
        
        // Male RHR norms (bpm) — p5 is LOWEST (best), p95 is HIGHEST (worst)
        let maleNorms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 48, p25: 58, p50: 65, p75: 73, p95: 85),
            .age30to39: Distribution(p5: 49, p25: 59, p50: 66, p75: 74, p95: 86),
            .age40to49: Distribution(p5: 50, p25: 60, p50: 67, p75: 75, p95: 88),
            .age50to59: Distribution(p5: 50, p25: 60, p50: 68, p75: 76, p95: 89),
            .age60to69: Distribution(p5: 50, p25: 59, p50: 67, p75: 76, p95: 90),
            .age70plus: Distribution(p5: 50, p25: 59, p50: 66, p75: 75, p95: 90)
        ]
        
        // Female RHR norms (slightly higher on average)
        let femaleNorms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 50, p25: 61, p50: 68, p75: 76, p95: 90),
            .age30to39: Distribution(p5: 51, p25: 62, p50: 69, p75: 77, p95: 90),
            .age40to49: Distribution(p5: 52, p25: 62, p50: 69, p75: 77, p95: 91),
            .age50to59: Distribution(p5: 52, p25: 62, p50: 69, p75: 78, p95: 91),
            .age60to69: Distribution(p5: 52, p25: 61, p50: 69, p75: 78, p95: 92),
            .age70plus: Distribution(p5: 52, p25: 61, p50: 68, p75: 77, p95: 92)
        ]
        
        switch gender?.lowercased() {
        case "male":
            return maleNorms[bracket] ?? maleNorms[.age40to49]!
        case "female":
            return femaleNorms[bracket] ?? femaleNorms[.age40to49]!
        default:
            let male = maleNorms[bracket] ?? maleNorms[.age40to49]!
            let female = femaleNorms[bracket] ?? femaleNorms[.age40to49]!
            return Distribution(
                p5: (male.p5 + female.p5) / 2,
                p25: (male.p25 + female.p25) / 2,
                p50: (male.p50 + female.p50) / 2,
                p75: (male.p75 + female.p75) / 2,
                p95: (male.p95 + female.p95) / 2
            )
        }
    }
    
    // MARK: - VO2 Max Percentiles (ml/kg/min)
    // Source: Cooper Institute / ACSM fitness categories
    // Higher VO2 Max = better
    
    static func vo2MaxPercentile(value: Double, age: Int, gender: String?) -> Double {
        let dist = vo2MaxDistribution(age: age, gender: gender)
        return dist.percentile(for: value, higherIsBetter: true)
    }
    
    private static func vo2MaxDistribution(age: Int, gender: String?) -> Distribution {
        let bracket = AgeBracket.bracket(for: age)
        
        // Male VO2 Max norms (ml/kg/min)
        let maleNorms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 28, p25: 36, p50: 42, p75: 50, p95: 60),
            .age30to39: Distribution(p5: 26, p25: 34, p50: 40, p75: 47, p95: 56),
            .age40to49: Distribution(p5: 24, p25: 32, p50: 38, p75: 44, p95: 53),
            .age50to59: Distribution(p5: 21, p25: 29, p50: 35, p75: 41, p95: 49),
            .age60to69: Distribution(p5: 18, p25: 26, p50: 32, p75: 38, p95: 45),
            .age70plus: Distribution(p5: 15, p25: 22, p50: 28, p75: 34, p95: 42)
        ]
        
        // Female VO2 Max norms
        let femaleNorms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 22, p25: 30, p50: 36, p75: 42, p95: 52),
            .age30to39: Distribution(p5: 20, p25: 28, p50: 34, p75: 40, p95: 48),
            .age40to49: Distribution(p5: 18, p25: 26, p50: 32, p75: 38, p95: 46),
            .age50to59: Distribution(p5: 16, p25: 24, p50: 29, p75: 35, p95: 42),
            .age60to69: Distribution(p5: 14, p25: 21, p50: 26, p75: 32, p95: 38),
            .age70plus: Distribution(p5: 12, p25: 18, p50: 23, p75: 28, p95: 34)
        ]
        
        switch gender?.lowercased() {
        case "male":
            return maleNorms[bracket] ?? maleNorms[.age40to49]!
        case "female":
            return femaleNorms[bracket] ?? femaleNorms[.age40to49]!
        default:
            let male = maleNorms[bracket] ?? maleNorms[.age40to49]!
            let female = femaleNorms[bracket] ?? femaleNorms[.age40to49]!
            return Distribution(
                p5: (male.p5 + female.p5) / 2,
                p25: (male.p25 + female.p25) / 2,
                p50: (male.p50 + female.p50) / 2,
                p75: (male.p75 + female.p75) / 2,
                p95: (male.p95 + female.p95) / 2
            )
        }
    }
    
    // MARK: - Sleep Duration Percentiles (hours)
    // Source: Cappuccio et al. meta-analysis — U-shaped mortality curve
    // Optimal: 7.0-8.0h. Penalize <6h and >9h.
    // NOT age/gender dependent (mortality curve is consistent across demographics)
    
    static func sleepPercentile(value: Double, age: Int, gender: String?) -> Double {
        // U-shaped scoring: optimal at 7.0-8.0h
        // Score drops symmetrically below 6h and above 9h
        
        if value >= 7.0 && value <= 8.0 {
            // Optimal zone — scale from 70th to 90th percentile
            // 7.5h is peak (90th), 7.0 and 8.0 are 70th
            let distFromPeak = abs(value - 7.5)
            return 90.0 - (distFromPeak / 0.5) * 20.0
        } else if value >= 6.5 && value < 7.0 {
            // Slightly short — 50th to 70th
            let fraction = (value - 6.5) / 0.5
            return 50.0 + fraction * 20.0
        } else if value > 8.0 && value <= 8.5 {
            // Slightly long — 50th to 70th
            let fraction = (8.5 - value) / 0.5
            return 50.0 + fraction * 20.0
        } else if value >= 6.0 && value < 6.5 {
            // Short — 25th to 50th
            let fraction = (value - 6.0) / 0.5
            return 25.0 + fraction * 25.0
        } else if value > 8.5 && value <= 9.0 {
            // Long — 25th to 50th
            let fraction = (9.0 - value) / 0.5
            return 25.0 + fraction * 25.0
        } else if value >= 5.0 && value < 6.0 {
            // Very short — 5th to 25th
            let fraction = (value - 5.0) / 1.0
            return 5.0 + fraction * 20.0
        } else if value > 9.0 && value <= 10.0 {
            // Very long — 5th to 25th
            let fraction = (10.0 - value) / 1.0
            return 5.0 + fraction * 20.0
        } else if value < 5.0 {
            // Extremely short
            return max(2.0, 5.0 * (value / 5.0))
        } else {
            // Extremely long (>10h)
            return max(2.0, 5.0 * ((12.0 - value) / 2.0))
        }
    }
    
    // MARK: - Steps Percentiles (daily count)
    // Source: Paluch et al. (Lancet 2022)
    // Age-adjusted: younger adults optimal ~10K, over 60 optimal ~7-8K
    
    static func stepsPercentile(value: Double, age: Int, gender: String?) -> Double {
        let bracket = AgeBracket.bracket(for: age)
        
        // Age-adjusted step targets (not gender-dependent per Paluch)
        let norms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 2000, p25: 5000, p50: 7500, p75: 10000, p95: 15000),
            .age30to39: Distribution(p5: 2000, p25: 5000, p50: 7500, p75: 10000, p95: 14000),
            .age40to49: Distribution(p5: 2000, p25: 4500, p50: 7000, p75: 10000, p95: 13500),
            .age50to59: Distribution(p5: 1500, p25: 4000, p50: 6500, p75: 9000, p95: 12500),
            .age60to69: Distribution(p5: 1500, p25: 3500, p50: 5500, p75: 8000, p95: 11000),
            .age70plus: Distribution(p5: 1000, p25: 2500, p50: 4500, p75: 7000, p95: 10000)
        ]
        
        let dist = norms[bracket] ?? norms[.age40to49]!
        return dist.percentile(for: value, higherIsBetter: true)
    }
    
    // MARK: - Functional Strength Percentile (Composite)
    // Sources: JAMA 2019 (pushups), Brito et al. (sit-to-stand),
    // Leong et al. Lancet (grip/hang proxy), strength-to-bodyweight ratios
    
    static func strengthPercentile(
        age: Int,
        gender: String?,
        pushupRange: String?,
        canStandFromSitting: Bool?,
        deadHangRange: String?,
        benchPressMax: Double?,
        squatMax: Double?,
        deadliftMax: Double?,
        bodyweight: Double?
    ) -> Double? {
        
        var components: [(percentile: Double, weight: Double)] = []
        let hasLiftData = (benchPressMax != nil || squatMax != nil || deadliftMax != nil) && bodyweight != nil
        
        // Weights depend on whether we have lift data
        let pushupWeight: Double = hasLiftData ? 0.25 : 0.35
        let hangWeight: Double = hasLiftData ? 0.25 : 0.35
        let sitStandWeight: Double = hasLiftData ? 0.10 : 0.30
        let liftWeight: Double = hasLiftData ? 0.40 : 0.0
        
        // 1. Pushup percentile
        if let pushups = pushupRange {
            let pct = pushupPercentile(range: pushups, age: age, gender: gender)
            components.append((pct, pushupWeight))
        }
        
        // 2. Dead hang percentile
        if let hang = deadHangRange {
            let pct = deadHangPercentile(range: hang, age: age, gender: gender)
            components.append((pct, hangWeight))
        }
        
        // 3. Sit-to-stand
        if let canStand = canStandFromSitting {
            // Brito et al.: inability = 5-6x mortality risk
            // Pass adds ~15 percentile points; fail subtracts ~15
            let pct: Double = canStand ? 65.0 : 20.0
            components.append((pct, sitStandWeight))
        }
        
        // 4. Lift maxes (if available)
        if hasLiftData, let bw = bodyweight {
            let liftPct = liftPercentile(
                benchMax: benchPressMax,
                squatMax: squatMax,
                deadliftMax: deadliftMax,
                bodyweight: bw,
                gender: gender
            )
            components.append((liftPct, liftWeight))
        }
        
        guard !components.isEmpty else { return nil }
        
        // Weighted average
        let totalWeight = components.reduce(0.0) { $0 + $1.weight }
        let weightedSum = components.reduce(0.0) { $0 + $1.percentile * $1.weight }
        
        return weightedSum / totalWeight
    }
    
    // MARK: - Pushup Percentile
    
    private static func pushupPercentile(range: String, age: Int, gender: String?) -> Double {
        // Map ranges to approximate rep counts for percentile lookup
        let midpoint: Double
        switch range {
        case "0-5": midpoint = 3
        case "6-15": midpoint = 10
        case "16-30": midpoint = 23
        case "31-50": midpoint = 40
        case "50+": midpoint = 55
        default: midpoint = 10
        }
        
        let bracket = AgeBracket.bracket(for: age)
        
        // Male pushup norms by age
        let maleNorms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 4, p25: 17, p50: 29, p75: 36, p95: 56),
            .age30to39: Distribution(p5: 2, p25: 13, p50: 22, p75: 30, p95: 46),
            .age40to49: Distribution(p5: 1, p25: 10, p50: 17, p75: 25, p95: 40),
            .age50to59: Distribution(p5: 1, p25: 7, p50: 13, p75: 21, p95: 35),
            .age60to69: Distribution(p5: 1, p25: 5, p50: 10, p75: 17, p95: 30),
            .age70plus: Distribution(p5: 0, p25: 3, p50: 8, p75: 14, p95: 25)
        ]
        
        let femaleNorms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 2, p25: 10, p50: 18, p75: 26, p95: 42),
            .age30to39: Distribution(p5: 1, p25: 8, p50: 14, p75: 22, p95: 36),
            .age40to49: Distribution(p5: 1, p25: 6, p50: 11, p75: 18, p95: 30),
            .age50to59: Distribution(p5: 0, p25: 4, p50: 8, p75: 14, p95: 25),
            .age60to69: Distribution(p5: 0, p25: 3, p50: 6, p75: 12, p95: 22),
            .age70plus: Distribution(p5: 0, p25: 2, p50: 5, p75: 10, p95: 18)
        ]
        
        let dist: Distribution
        switch gender?.lowercased() {
        case "male":
            dist = maleNorms[bracket] ?? maleNorms[.age40to49]!
        case "female":
            dist = femaleNorms[bracket] ?? femaleNorms[.age40to49]!
        default:
            let male = maleNorms[bracket] ?? maleNorms[.age40to49]!
            let female = femaleNorms[bracket] ?? femaleNorms[.age40to49]!
            dist = Distribution(
                p5: (male.p5 + female.p5) / 2,
                p25: (male.p25 + female.p25) / 2,
                p50: (male.p50 + female.p50) / 2,
                p75: (male.p75 + female.p75) / 2,
                p95: (male.p95 + female.p95) / 2
            )
        }
        
        return dist.percentile(for: midpoint, higherIsBetter: true)
    }
    
    // MARK: - Dead Hang Percentile
    
    private static func deadHangPercentile(range: String, age: Int, gender: String?) -> Double {
        // Map ranges to approximate seconds
        let midpoint: Double
        switch range {
        case "cant": midpoint = 0
        case "under_15": midpoint = 8
        case "15-30": midpoint = 22
        case "30-60": midpoint = 45
        case "60+": midpoint = 75
        default: midpoint = 22
        }
        
        let bracket = AgeBracket.bracket(for: age)
        
        // Male dead hang norms (seconds) — proxy for grip strength
        let maleNorms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 5, p25: 25, p50: 45, p75: 70, p95: 110),
            .age30to39: Distribution(p5: 5, p25: 20, p50: 40, p75: 60, p95: 95),
            .age40to49: Distribution(p5: 3, p25: 15, p50: 35, p75: 55, p95: 85),
            .age50to59: Distribution(p5: 2, p25: 12, p50: 28, p75: 45, p95: 72),
            .age60to69: Distribution(p5: 1, p25: 8, p50: 22, p75: 38, p95: 60),
            .age70plus: Distribution(p5: 0, p25: 5, p50: 15, p75: 30, p95: 50)
        ]
        
        let femaleNorms: [AgeBracket: Distribution] = [
            .age18to29: Distribution(p5: 3, p25: 15, p50: 30, p75: 50, p95: 80),
            .age30to39: Distribution(p5: 2, p25: 12, p50: 25, p75: 42, p95: 68),
            .age40to49: Distribution(p5: 1, p25: 10, p50: 22, p75: 38, p95: 60),
            .age50to59: Distribution(p5: 1, p25: 8, p50: 18, p75: 32, p95: 52),
            .age60to69: Distribution(p5: 0, p25: 5, p50: 14, p75: 26, p95: 42),
            .age70plus: Distribution(p5: 0, p25: 3, p50: 10, p75: 20, p95: 35)
        ]
        
        let dist: Distribution
        switch gender?.lowercased() {
        case "male":
            dist = maleNorms[bracket] ?? maleNorms[.age40to49]!
        case "female":
            dist = femaleNorms[bracket] ?? femaleNorms[.age40to49]!
        default:
            let male = maleNorms[bracket] ?? maleNorms[.age40to49]!
            let female = femaleNorms[bracket] ?? femaleNorms[.age40to49]!
            dist = Distribution(
                p5: (male.p5 + female.p5) / 2,
                p25: (male.p25 + female.p25) / 2,
                p50: (male.p50 + female.p50) / 2,
                p75: (male.p75 + female.p75) / 2,
                p95: (male.p95 + female.p95) / 2
            )
        }
        
        return dist.percentile(for: midpoint, higherIsBetter: true)
    }
    
    // MARK: - Lift Percentile (Strength-to-Bodyweight Ratios)
    
    private static func liftPercentile(
        benchMax: Double?,
        squatMax: Double?,
        deadliftMax: Double?,
        bodyweight: Double,
        gender: String?
    ) -> Double {
        guard bodyweight > 0 else { return 50.0 }
        
        var components: [Double] = []
        
        // "Good" benchmarks (50th percentile targets):
        // Male: Bench 1.0x BW, Squat 1.5x BW, Deadlift 2.0x BW
        // Female: Bench 0.6x BW, Squat 1.0x BW, Deadlift 1.5x BW
        
        let isMale = gender?.lowercased() != "female"
        
        if let bench = benchMax {
            let ratio = bench / bodyweight
            let target = isMale ? 1.0 : 0.6
            let pct = ratioToPercentile(ratio: ratio, target50th: target)
            components.append(pct)
        }
        
        if let squat = squatMax {
            let ratio = squat / bodyweight
            let target = isMale ? 1.5 : 1.0
            let pct = ratioToPercentile(ratio: ratio, target50th: target)
            components.append(pct)
        }
        
        if let deadlift = deadliftMax {
            let ratio = deadlift / bodyweight
            let target = isMale ? 2.0 : 1.5
            let pct = ratioToPercentile(ratio: ratio, target50th: target)
            components.append(pct)
        }
        
        guard !components.isEmpty else { return 50.0 }
        return components.reduce(0.0, +) / Double(components.count)
    }
    
    /// Convert a strength-to-bodyweight ratio to a percentile
    /// target50th is the ratio that equals the 50th percentile
    private static func ratioToPercentile(ratio: Double, target50th: Double) -> Double {
        // Scale: 0x = ~5th percentile, target = 50th, 1.5x target = ~85th, 2x target = ~95th
        let normalized = ratio / target50th  // 1.0 = 50th percentile
        
        if normalized <= 0 {
            return 5.0
        } else if normalized < 0.5 {
            // 0 to 0.5x target → 5th to 25th
            return 5.0 + (normalized / 0.5) * 20.0
        } else if normalized < 1.0 {
            // 0.5x to 1.0x target → 25th to 50th
            return 25.0 + ((normalized - 0.5) / 0.5) * 25.0
        } else if normalized < 1.5 {
            // 1.0x to 1.5x target → 50th to 80th
            return 50.0 + ((normalized - 1.0) / 0.5) * 30.0
        } else if normalized < 2.0 {
            // 1.5x to 2.0x target → 80th to 95th
            return 80.0 + ((normalized - 1.5) / 0.5) * 15.0
        } else {
            // 2.0x+ target → 95th+
            return min(99.0, 95.0 + (normalized - 2.0) * 4.0)
        }
    }
}