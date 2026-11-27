import Foundation

struct LongevityPlanPrompts {
    
     // MARK: - User Context
    struct UserContext {
        let name: String
        let age: Int
        let gender: String?
        let primaryGoal: String
        let secondaryGoal: String
        let activityLevel: String
        let experienceLevel: String
        let trainingDaysPerWeek: Int
        let minutesPerSession: Int
        let currentActivities: String
        let constraints: String?
        let sleepAverage: Double?
        let vo2Max: Double?
        let hrv: Double?
        let rhr: Double?
        let weight: Double?
        let height: Double?
        let proteinGrams: Double?
        let stepCount: Double?
        let bodyweight: Double?
        
        let proteinTarget: Int?        // Auto-calculated if nil: bodyweight * 0.8
        let hydrationTarget: Int?      // Auto-calculated if nil: bodyweight * 0.5
        let vo2MaxPercentile: Int?
        
        // Tier information
        let trainingTier: Int
        let trainingTierName: String
        let longevityTier: String?
        
        // Event training (optional)
        let isTrainingForEvent: Bool
        let eventName: String?
        let eventDate: Date?
        let weeksUntilEvent: Int?
        
        // Wake time for bedtime calculation
        let targetWakeTime: Date?
        
        /// Full initializer with auto-calculation of derived fields
        init(
            name: String,
            age: Int,
            gender: String?,
            primaryGoal: String,
            secondaryGoal: String,
            activityLevel: String,
            experienceLevel: String,
            trainingDaysPerWeek: Int,
            minutesPerSession: Int,
            currentActivities: String,
            constraints: String?,
            sleepAverage: Double?,
            vo2Max: Double?,
            hrv: Double?,
            rhr: Double?,
            weight: Double?,
            height: Double?,
            proteinGrams: Double?,
            stepCount: Double?,
            bodyweight: Double?,
            proteinTarget: Int? = nil,
            hydrationTarget: Int? = nil,
            vo2MaxPercentile: Int? = nil,
            trainingTier: Int,
            trainingTierName: String,
            longevityTier: String?,
            isTrainingForEvent: Bool = false,
            eventName: String? = nil,
            eventDate: Date? = nil,
            weeksUntilEvent: Int? = nil,
            targetWakeTime: Date? = nil
        ) {
            self.name = name
            self.age = age
            self.gender = gender
            self.primaryGoal = primaryGoal
            self.secondaryGoal = secondaryGoal
            self.activityLevel = activityLevel
            self.experienceLevel = experienceLevel
            self.trainingDaysPerWeek = trainingDaysPerWeek
            self.minutesPerSession = minutesPerSession
            self.currentActivities = currentActivities
            self.constraints = constraints
            self.sleepAverage = sleepAverage
            self.vo2Max = vo2Max
            self.hrv = hrv
            self.rhr = rhr
            self.weight = weight
            self.height = height
            self.proteinGrams = proteinGrams
            self.stepCount = stepCount
            self.bodyweight = bodyweight
            self.trainingTier = trainingTier
            self.trainingTierName = trainingTierName
            self.longevityTier = longevityTier
            self.isTrainingForEvent = isTrainingForEvent
            self.eventName = eventName
            self.eventDate = eventDate
            self.weeksUntilEvent = weeksUntilEvent
            self.targetWakeTime = targetWakeTime
            self.vo2MaxPercentile = vo2MaxPercentile
            
            // Auto-calculate targets from bodyweight if not explicitly provided
            if let pt = proteinTarget {
                self.proteinTarget = pt
            } else if let bw = bodyweight, bw > 0 {
                self.proteinTarget = Int(bw * 0.8)
            } else {
                self.proteinTarget = nil
            }
            
            if let ht = hydrationTarget {
                self.hydrationTarget = ht
            } else if let bw = bodyweight, bw > 0 {
                self.hydrationTarget = Int(bw * 0.5)
            } else {
                self.hydrationTarget = nil
            }
        }
    }

    
    // MARK: - Generate Phase 1 Plan
    static func generatePhase1Plan(
        user: UserContext,
        deficiencies: [PriorityAssessment]
    ) -> String {
        
        // Build deficiency contexts
        let deficiencyContext = buildDeficiencyContextWithNuance(
            deficiencies: deficiencies,
            user: user
        )
        
        // ⭐ BUILD GOOD ENOUGH THRESHOLDS
        let goodEnoughThresholds = buildGoodEnoughThresholdsSection()
        
        let adequateContext = DeficiencyAssessment.buildAdequateMetricsContext(
            sleepHours: user.sleepAverage,
            proteinGrams: user.proteinGrams,
            bodyWeight: user.weight,
            vo2Max: user.vo2Max,
            hrv: user.hrv,
            rhr: user.rhr,
            steps: user.stepCount,
            activityLevel: user.activityLevel,
            age: user.age,
            isMale: user.gender?.lowercased() == "male"
        )
        
        // Check data availability
        let availability = DeficiencyAssessment.checkDataAvailability(
            sleepHours: user.sleepAverage,
            proteinGrams: user.proteinGrams,
            vo2Max: user.vo2Max,
            hrv: user.hrv,
            rhr: user.rhr,
            steps: user.stepCount
        )
        
        let dataCompletenessContext = buildDataCompletenessContext(availability: availability)
        
        // Get tier-specific configuration
        let tierConfig = getTierConfiguration(tier: user.trainingTier)
        
        // Build the full prompt with Master System Prompt embedded
        return """
        \(buildSystemPrompt(user: user))
        
        ---
        
        ## YOUR TASK: Generate Phase 1 Longevity Plan
        
        Create a personalized longevity plan for \(user.name) based on their profile and Training Tier (\(user.trainingTierName)).
        
        \(buildTierSpecificInstructions(user: user, config: tierConfig))

        \(buildTrainingVsHabitsInstructions())
        
        \(dataCompletenessContext)
        
        \(deficiencyContext)
        
        \(goodEnoughThresholds)
        
        \(adequateContext)
        
        \(buildSleepBedtimeInstructions(user: user, deficiencies: deficiencies))
        
        \(buildProteinPrescriptionRules())
        
        \(user.isTrainingForEvent ? buildEventInstructions(user: user) : "")
        
        Return ONLY valid JSON in this EXACT format:
        
        {
          "personalized_rationale": "\(buildRationaleInstructions(user: user))",
          
          "non_negotiables": [
            \(buildNonNegotiableTemplate(count: tierConfig.maxNonNegotiables))
          ]
        }
        
        \(buildOutputRules(user: user, config: tierConfig))
        """
    }
    
    // MARK: - Tier Configuration
    
    struct TierConfiguration {
        let maxNonNegotiables: Int
        let allowedCardioProtocols: [String]
        let allowedStrengthFrequency: String
        let toneGuidance: String
        let focusAreas: [String]
        let restrictions: [String]
    }
    
    private static func getTierConfiguration(tier: Int) -> TierConfiguration {
        switch tier {
        case 0: // Recovery
            return TierConfiguration(
                maxNonNegotiables: 2,
                allowedCardioProtocols: ["Approved movement only", "Walking if cleared", "None"],
                allowedStrengthFrequency: "Only PT-approved exercises",
                toneGuidance: "Maximum encouragement. Celebrate any progress. Focus on healing.",
                focusAreas: ["Sleep optimization", "Nutrition for healing (protein 1.6g/kg)", "Stress management", "Light exposure"],
                restrictions: [
                    "DO NOT prescribe any exercise not explicitly cleared by medical professional",
                    "DO NOT include intensity of any kind",
                    "DO NOT include progressive overload",
                    "Focus on recovery modalities: sleep, breathwork, yoga nidra, meditation"
                ]
            )
            
        case 1: // Beginner
            return TierConfiguration(
                maxNonNegotiables: 2,
                allowedCardioProtocols: ["Walking", "Light cycling", "Swimming"],
                allowedStrengthFrequency: "0-2x/week, bodyweight or very light resistance",
                toneGuidance: "High encouragement. Build confidence through small wins. Celebrate consistency.",
                focusAreas: ["Sleep optimization", "Daily movement (walking, steps)", "Basic habit formation"],
                restrictions: [
                    "DO NOT prescribe complex training programs",
                    "DO NOT prescribe high-intensity intervals (Norwegian 4x4, etc.)",
                    "DO NOT prescribe multiple supplements beyond basics",
                    "Keep tracking simple - adherence only, not detailed metrics"
                ]
            )
            
        case 2: // Active
            return TierConfiguration(
                maxNonNegotiables: 3,
                allowedCardioProtocols: ["Zone 2 (30-40 min)", "Simple intervals (1-2 min work, 2-3 min rest)"],
                allowedStrengthFrequency: "2-3x/week, compound movements",
                toneGuidance: "Balanced encouragement and accountability. Acknowledge progress as expected outcome of effort.",
                focusAreas: ["Sleep optimization", "Protein target (1.6g/kg)", "Consistent strength training", "Zone 2 cardio base"],
                restrictions: [
                    "DO NOT prescribe Norwegian 4x4 or advanced interval protocols",
                    "DO NOT prescribe periodized training yet",
                    "DO NOT prescribe HRV-guided adjustments"
                ]
            )
            
        case 3: // Advanced
            return TierConfiguration(
                maxNonNegotiables: 4,
                allowedCardioProtocols: ["Zone 2 (40-50 min)", "3-min intervals (85-90% HR)", "Norwegian 4x4 if ready"],
                allowedStrengthFrequency: "3x/week, progressive overload with clear metrics",
                toneGuidance: "More accountability, less cheerleading. Data-driven feedback. Call out gaps directly.",
                focusAreas: ["Progressive overload with metrics", "Protein optimization", "VO2 max progression", "Recovery optimization"],
                restrictions: [
                    "Norwegian 4x4 only if user has been consistent with 3-min intervals for 4+ weeks",
                    "Include deload week recommendations"
                ]
            )
            
        case 4: // Beast Mode
            return TierConfiguration(
                maxNonNegotiables: 5,
                allowedCardioProtocols: ["Norwegian 4x4 (4x4 min at 85-95% HR)", "Zone 2 (45-60 min)", "Threshold work"],
                allowedStrengthFrequency: "3-4x/week, periodized, auto-regulation",
                toneGuidance: "Minimal celebration. Maximum accountability. Focus on metrics and optimization.",
                focusAreas: ["Periodized strength", "VO2 max optimization", "Advanced recovery (sauna, cold)", "HRV-guided adjustments"],
                restrictions: [
                    "Include deload weeks every 4-6 weeks",
                    "Include HRV-based intensity modifications"
                ]
            )
            
        default:
            return getTierConfiguration(tier: 1) // Default to Beginner
        }
    }
    
    // MARK: - Build System Prompt
    
    private static func buildSystemPrompt(user: UserContext) -> String {
        """
        You are atlas's AI longevity coach. Your mission is to help \(user.name) build sustainable habits that extend healthspan and lifespan through evidence-based interventions.
        
        ## WHO YOU ARE
        
        You are a direct, evidence-based longevity coach. You filter out fitness industry noise and deliver only research-backed interventions proven to extend healthspan and lifespan.
        
        Core Mantras:
        - "Live better for longer" - Focus on healthspan, not just lifespan
        - "Wherever you are, the next step is yours" - Meet people where they are
        - "Progress from here, not from perfect" - Sustainable improvement over ideal plans
        - "Process over outcome" - Focus on daily disciplines, release attachment to exact results
        
        You are NOT:
        - A cheerleader who celebrates basic adherence with excessive praise
        - A pushover who makes excuses for users
        - A generic motivational poster spouting vague encouragement
        - An overly cautious advisor who hedges every statement
        
        ## USER PROFILE
        
        Name: \(user.name)
        Age: \(user.age)
        Training Tier: \(user.trainingTier) (\(user.trainingTierName))
        \(user.longevityTier != nil ? "Longevity Tier: \(formatLongevityTier(user.longevityTier!))" : "")
        
        Primary Goal: \(formatGoal(user.primaryGoal))
        Secondary Goal: \(formatGoal(user.secondaryGoal))
        Activity Level: \(user.activityLevel)
        Experience Level: \(user.experienceLevel)
        Training Days Available: \(user.trainingDaysPerWeek)/week
        Minutes Per Session: \(user.minutesPerSession)
        Current Activities: \(user.currentActivities.isEmpty ? "None" : user.currentActivities)
        Constraints: \(user.constraints ?? "None")
        
        Metrics (30-day averages):
        - Sleep Average: \(formatOptional(user.sleepAverage, suffix: " hours"))
        - VO2 Max: \(formatOptional(user.vo2Max))
        - HRV: \(formatOptional(user.hrv, suffix: " ms"))
        - RHR: \(formatOptional(user.rhr, suffix: " bpm"))
        - Weight: \(formatOptional(user.weight, suffix: " lbs"))
        - Daily Steps: \(formatOptional(user.stepCount, suffix: " steps"))
        - Protein: \(formatOptional(user.proteinGrams, suffix: "g/day"))
        
        ## INTERVENTION HIERARCHY
        
        Apply in this order, adjusting based on user context:
        
        1. SLEEP (7-9 hours) - Foundation. Poor sleep negates other interventions.
        2. CARDIOVASCULAR FITNESS (VO2 Max) - Strongest longevity predictor.
        3. STRENGTH TRAINING (90+ min/week) - Preserves muscle, metabolic health.
        4. BODY COMPOSITION (Protein priority) - Muscle mass > BMI for longevity.
        5. RECOVERY & STRESS - HRV tracking, evidence-based recovery.
        
        ## EVIDENCE TIERS - WHAT TO RECOMMEND
        
        TIER 1 (Strong Evidence - Recommend Freely):
        - Sleep 7-9 hours, progressive resistance training, VO2 max training (tier-appropriate)
        - Protein 1.6-2.2g/kg, creatine 5g daily, vitamin D if deficient
        - Cold exposure 30-60 sec daily, sauna 4-7x/week when accessible
        
        TIER 4 (NEVER Recommend):
        - OTC testosterone boosters, fat burners, detox protocols
        - "Muscle confusion" training, extreme calorie restriction
        - Proprietary supplement blends without research
        """
    }

    // MARK: - Training vs Daily Habits Distinction
    
    private static func buildTrainingVsHabitsInstructions() -> String {
        """
        ## CRITICAL DISTINCTION: Training vs. Daily Movement Habits
        
        The TrainingProgram system handles structured workouts separately. DO NOT include these as non-negotiables:
        
        ❌ NEVER INCLUDE (handled by TrainingProgram):
        - Strength training / resistance training / weight lifting sessions
        - Structured cardio workouts (running programs, interval sessions)
        - Sport-specific training (marathon prep, event training)
        - Anything requiring gym time or dedicated workout blocks
        - Progressive strength programs
        - Periodized training blocks
        
        ✅ VALID DAILY MOVEMENT NON-NEGOTIABLES (you CAN prescribe):
        - Daily step goals (e.g., "Walk 7,500 steps daily")
        - Stretching / mobility work (e.g., "5-minute morning stretch")
        - Active lifestyle habits (e.g., "Take stairs", "Park farther away")
        - Low-intensity movement (e.g., "10-minute post-meal walk")
        - Recovery activities (e.g., "Daily foam rolling", "Evening stretching")
        
        ✅ OTHER VALID NON-NEGOTIABLES:
        - Sleep optimization (e.g., "Sleep 7+ hours", "In bed by 10 PM")
        - Nutrition habits (e.g., "Eat 140g protein", "Drink 80oz water")
        - Recovery/stress (e.g., "Morning sunlight", "Caffeine cutoff 2 PM")
        - Lifestyle habits (e.g., "No screens 1h before bed")
        
        EXCEPTION: If user is in EVENT TRAINING MODE, one non-negotiable MUST be the event training reminder (see Event Training Instructions).
        """
    }
    
    // MARK: - Data Completeness Context
    
    private static func buildDataCompletenessContext(availability: MetricAvailability) -> String {
        """
        ## DATA COMPLETENESS: \(Int(availability.completeness * 100))%
        
        Available metrics (\(availability.availableMetrics)/\(availability.totalMetrics)): \(availability.unknownMetrics.isEmpty ? "All metrics available ✅" : "")
        \(availability.unknownMetrics.isEmpty ? "" : "Unknown: \(availability.unknownMetrics.joined(separator: ", "))")
        
        Completeness Level: \(availability.completenessLevel)
        
        ## HANDLING UNKNOWN METRICS
        
        **High completeness (≥70% = 5+ metrics known):**
        - Proceed with normal deficiency-based plan
        - Acknowledge gaps: "We don't have your [metric] data yet, but based on your goals..."
        - Make conservative assumptions for unknowns
        
        **Medium completeness (40-70% = 3-4 metrics known):**
        - Focus on known deficiencies
        - Prescribe foundational habits that work regardless (e.g., "Walk 30 min daily")
        - Mention: "As we gather more data, we'll refine your plan"
        
        **Low completeness (<40% = 0-2 metrics known):**
        - Build profile-based plan using goals, activity level, constraints
        - Prescribe universal fundamentals: sleep consistency, daily movement, protein awareness
        - Explain: "Your plan will become more personalized as Apple Health tracks your metrics"
        
        EXAMPLES:
        
        **High Completeness (Sleep, HRV, RHR known; Protein, VO2 unknown):**
        ✅ CORRECT: "Your sleep (6.2h) and recovery metrics (HRV 42ms, RHR 78) show you're overreached. We don't have your protein data yet, but given your 'build muscle' goal, adequate protein is critical. Start with sleep optimization and 140g protein daily (0.8g/lb for your weight)."
        
        **Low Completeness (Only age, goals, activity level):**
        ✅ CORRECT: "You're 34, moderately active, focused on longevity. Without baseline metrics yet, we're starting with universal fundamentals: 7+ hours sleep, 7,500 steps daily, and strength training 2x/week. As Apple Health gathers your data over the next week, we'll personalize your plan further."
        """
    }
    
    // MARK: - Build Deficiency Context with Nuance
    static func buildContextualModifiers(
        sleepHours: Double?,
        sleepLevel: DeficiencyLevel,
        hrv: Double?,
        hrvLevel: DeficiencyLevel,
        rhr: Double?,
        rhrLevel: DeficiencyLevel,
        age: Int,
        isMale: Bool
    ) -> [String: [ContextualModifier]] {
        
        var modifiers: [String: [ContextualModifier]] = [:]
        
        // Sleep context
        if sleepLevel == .deficient {
            var sleepMods: [ContextualModifier] = []
            
            if hrvLevel == .optimal && rhrLevel == .optimal {
                sleepMods.append(ContextualModifier(
                    description: "Recovery metrics (HRV \(String(format: "%.0f", hrv ?? 0))ms, RHR \(String(format: "%.0f", rhr ?? 0))bpm) are excellent despite borderline sleep duration",
                    impactLevel: "mitigating"
                ))
            }
            
            if let hours = sleepHours, hours >= 6.5 {
                sleepMods.append(ContextualModifier(
                    description: "Sleep duration (\(String(format: "%.1f", hours))h) is close to 7h threshold - marginal deficiency",
                    impactLevel: "mitigating"
                ))
            }
            
            if !sleepMods.isEmpty {
                modifiers["Sleep"] = sleepMods
            }
        }
        
        // HRV context
        if hrvLevel == .deficient && sleepLevel == .critical {
            modifiers["HRV"] = [ContextualModifier(
                description: "Low HRV likely caused by severe sleep deprivation - addressing sleep should improve HRV",
                impactLevel: "compounding"
            )]
        }
        
        return modifiers
    }

    // MARK: - Build Deficiency Context with Nuance (COMPLETE UPDATED VERSION)
    static func buildDeficiencyContextWithNuance(
        deficiencies: [PriorityAssessment],
        user: LongevityPlanPrompts.UserContext
    ) -> String {
        
        // Build contextual modifiers
        let sleepLevel = DeficiencyAssessment.assessSleep(averageHours: user.sleepAverage)
        let hrvLevel = DeficiencyAssessment.assessHRV(
            value: user.hrv, 
            age: user.age, 
            isMale: user.gender?.lowercased() == "male"
        )
        let rhrLevel = DeficiencyAssessment.assessRHR(value: user.rhr)
        
        let modifiers = DeficiencyAssessment.buildContextualModifiers(
            sleepHours: user.sleepAverage,
            sleepLevel: sleepLevel,
            hrv: user.hrv,
            hrvLevel: hrvLevel,
            rhr: user.rhr,
            rhrLevel: rhrLevel,
            age: user.age,
            isMale: user.gender?.lowercased() == "male"
        )
        
        // ⭐ NEW: Filter deficiencies based on minimum delta rules
        var prescribableDeficiencies: [PriorityAssessment] = []
        var skippedDeficiencies: [PriorityAssessment] = []
        
        for deficiency in deficiencies {
            let shouldPrescribe = shouldPrescribeHabit(
                metric: deficiency.metric,
                level: deficiency.level,
                currentValue: deficiency.currentValue,
                targetValue: deficiency.targetValue,
                user: user
            )
            
            if shouldPrescribe {
                prescribableDeficiencies.append(deficiency)
            } else {
                skippedDeficiencies.append(deficiency)
            }
        }
        
        // Build context string for prescribable deficiencies
        let prescribableContext = buildContextString(
            deficiencies: prescribableDeficiencies,
            modifiers: modifiers
        )
        
        // Build header
        var fullContext = """
        ## DEFICIENCY ANALYSIS - PRESCRIBABLE PRIORITIES
        
        """
        
        // Add prescribable deficiencies
        if !prescribableDeficiencies.isEmpty {
            fullContext += prescribableContext
        } else {
            fullContext += """
            ✅ ALL METRICS IN ADEQUATE OR OPTIMAL RANGE
            
            No deficiencies requiring intervention. Focus on:
            - Maintaining current practices
            - Progressive overload in training
            - Optimizing already-adequate metrics toward optimal range
            """
        }
        
        // Add skipped deficiencies section if any exist
        if !skippedDeficiencies.isEmpty {
            fullContext += """
            
            
            ## ⚠️ SKIPPED METRICS (BELOW MINIMUM DELTA - DO NOT PRESCRIBE)
            
            The following metrics are technically "deficient" but the gap is too small to warrant a non-negotiable habit slot. DO NOT prescribe habits for these. Instead, ACKNOWLEDGE them in your rationale.
            
            """
            
            for skip in skippedDeficiencies {
                let skipReason = getSkipReason(
                    metric: skip.metric,
                    currentValue: skip.currentValue,
                    targetValue: skip.targetValue,
                    user: user
                )
                
                fullContext += """
                \(skip.level.emoji) \(skip.metric)
                   Current: \(skip.currentValue ?? "Unknown")
                   Target: \(skip.targetValue ?? "Unknown")
                   WHY SKIPPED: \(skipReason)
                   WHAT TO SAY: Acknowledge in rationale - "\(getAcknowledgmentText(skip, user: user))"
                
                """
            }
            
            fullContext += """
            
            REMINDER: Focus your non-negotiables on the PRESCRIBABLE PRIORITIES above. These skipped metrics should be mentioned positively in your rationale to show you understand the user's full picture.
            """
        }
        
        return fullContext
    }

    // MARK: - Helper: Should Prescribe Habit
    private static func shouldPrescribeHabit(
        metric: String,
        level: DeficiencyLevel,
        currentValue: String?,
        targetValue: String?,
        user: LongevityPlanPrompts.UserContext
    ) -> Bool {
        
        // Critical deficiencies ALWAYS get prescribed
        if level == .critical {
            return true
        }
        
        // Adequate/Optimal metrics NEVER get prescribed
        if level == .adequate || level == .optimal {
            return false
        }
        
        // For deficient metrics, apply minimum delta rules
        switch metric {
        case "Protein":
            guard let current = extractNumericValue(from: currentValue),
                  let target = extractNumericValue(from: targetValue) else {
                return true  // Default to prescribing if we can't parse
            }
            
            let delta = abs(target - current)
            // Only prescribe if gap is >20g
            return delta > 20
            
        case "Daily Steps":
            guard let current = extractNumericValue(from: currentValue) else {
                return true
            }
            
            // If ≥7500 steps AND user is moderately/very active, skip
            if current >= 7500 {
                let activityLevel = user.activityLevel.lowercased()
                let isActive = activityLevel.contains("moderate") || 
                              activityLevel.contains("very") ||
                              activityLevel.contains("active")
                return !isActive  // Only prescribe if they're sedentary/lightly active
            }
            
            return true  // <7500 steps always needs intervention
            
        case "Sleep":
            guard let current = extractNumericValue(from: currentValue) else {
                return true
            }
            
            // Only prescribe if <7h average
            // (Consistency-based sleep habits handled separately via bedtime logic)
            return current < 7.0
            
        case "Movement/Activity":
            // Activity level deficiency always prescribable
            return true
            
        case "Cardiovascular Fitness", "VO2 Max":
            // VO2 Max deficiency always prescribable
            return true
            
        case "Recovery/Stress Management", "HRV":
            // Check if it's compounding with sleep deficiency
            // If sleep is critical and HRV is deficient, sleep will fix HRV
            if level == .deficient && user.sleepAverage != nil && user.sleepAverage! < 6.0 {
                return false  // Skip HRV, sleep will fix it
            }
            return true
            
        case "Resting Heart Rate", "RHR":
            // RHR deficiency always prescribable (except if critical, which is handled above)
            return true
            
        default:
            return true
        }
    }

    // MARK: - Helper: Extract Numeric Value from String
    private static func extractNumericValue(from string: String?) -> Double? {
        guard let str = string else { return nil }
        
        // Remove all non-numeric characters except decimal point
        let filtered = str.filter { $0.isNumber || $0 == "." }
        
        // Handle cases like "170g" → "170", "6.2h" → "6.2"
        if let firstNumber = filtered.split(separator: " ").first {
            return Double(firstNumber)
        }
        
        return Double(filtered)
    }

    // MARK: - Helper: Get Skip Reason
    private static func getSkipReason(
        metric: String,
        currentValue: String?,
        targetValue: String?,
        user: LongevityPlanPrompts.UserContext
    ) -> String {
        
        switch metric {
        case "Protein":
            guard let current = extractNumericValue(from: currentValue),
                  let target = extractNumericValue(from: targetValue) else {
                return "Unable to calculate gap"
            }
            let delta = abs(target - current)
            return "Gap is only \(Int(delta))g (minimum delta is 20g). User is already at \(String(format: "%.1f", current / (user.weight ?? 175)))g/lb - adequate range."
            
        case "Daily Steps":
            guard let current = extractNumericValue(from: currentValue) else {
                return "Unable to parse step count"
            }
            let activityLevel = user.activityLevel
            return "User averages \(Int(current)) steps/day (above 7500 threshold) AND is \(activityLevel). Focus on structured movement instead of marginal step increases."
            
        case "Sleep":
            guard let current = extractNumericValue(from: currentValue) else {
                return "Unable to parse sleep hours"
            }
            return "Sleep duration is \(String(format: "%.1f", current))h (borderline but close to 7h threshold). Focus on bigger gaps first."
            
        case "Recovery/Stress Management", "HRV":
            return "HRV deficiency is likely secondary to sleep deprivation. Addressing sleep (currently \(user.sleepAverage != nil ? String(format: "%.1f", user.sleepAverage!) : "unknown")h) will improve HRV."
            
        default:
            return "Below minimum intervention threshold"
        }
    }

    // MARK: - Helper: Get Acknowledgment Text
    private static func getAcknowledgmentText(
        _ deficiency: PriorityAssessment,
        user: LongevityPlanPrompts.UserContext
    ) -> String {
        
        switch deficiency.metric {
        case "Protein":
            guard let current = extractNumericValue(from: deficiency.currentValue),
                  let weight = user.weight else {
                return "Your protein intake is already adequate"
            }
            let ratio = current / weight
            return "Your protein intake (\(Int(current))g) is already excellent at \(String(format: "%.1f", ratio))g/lb"
            
        case "Daily Steps":
            guard let current = extractNumericValue(from: deficiency.currentValue) else {
                return "Your daily steps are already good"
            }
            return "Your steps (\(Int(current))/day) show good baseline movement"
            
        case "Sleep":
            guard let current = extractNumericValue(from: deficiency.currentValue) else {
                return "Your sleep is borderline adequate"
            }
            return "Your sleep (\(String(format: "%.1f", current))h) is close to optimal range"
            
        case "Recovery/Stress Management", "HRV":
            return "Your HRV will improve as we address sleep quality"
            
        default:
            return "Your \(deficiency.metric.lowercased()) is already adequate"
        }
    }

    // MARK: - Build Context String (Existing function - unchanged)
    static func buildContextString(
        deficiencies: [PriorityAssessment],
        modifiers: [String: [ContextualModifier]]
    ) -> String {
        if deficiencies.isEmpty {
            return """
            ✅ ALL METRICS IN ADEQUATE OR OPTIMAL RANGE
            
            No critical deficiencies detected. Focus on:
            - Maintaining current practices
            - Progressive overload in training
            - Optimizing already-adequate metrics toward optimal range
            """
        }
        
        return deficiencies.enumerated().map { index, assessment in
            var assessmentString = """
            \(assessment.level.emoji) Priority #\(index + 1): \(assessment.metric)
               Status: \(assessment.level.rawValue)
               Current: \(assessment.currentValue ?? "Unknown")
               Target: \(assessment.targetValue ?? "Unknown")
               Reason: \(assessment.reasoning)
            """
            
            // Add contextual modifiers if they exist
            if let mods = modifiers[assessment.metric], !mods.isEmpty {
                assessmentString += "\n           Context:"
                for mod in mods {
                    assessmentString += "\n           • \(mod.description)"
                }
            }
            
            // Add AI decision guidance
            if assessment.level == .critical {
                assessmentString += "\n           ⚠️ MANDATORY INTERVENTION - Must prescribe regardless of other factors"
            } else if !modifiers[assessment.metric, default: []].isEmpty {
                assessmentString += "\n           💡 AI DECISION REQUIRED - Consider context when prioritizing"
            }
            
            return assessmentString
        }.joined(separator: "\n\n")
    }
    
    // MARK: - Sleep Bedtime Instructions
    
    private static func buildSleepBedtimeInstructions(user: UserContext, deficiencies: [PriorityAssessment]) -> String {
        
        // Check if sleep is deficient
        let hasSleepDeficiency = deficiencies.contains { $0.metric == "Sleep" }
        
        guard hasSleepDeficiency, let wakeTime = user.targetWakeTime else {
            return ""
        }
        
        // Calculate prescribed bedtime (8 hours before wake + 15 min buffer)
        let calendar = Calendar.current
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let totalMinutesBack = (8 * 60) + 15  // 8 hours + 15 min to fall asleep
        
        let bedtimeMinutes = (wakeComponents.hour! * 60 + wakeComponents.minute!) - totalMinutesBack
        let adjustedBedtimeMinutes = bedtimeMinutes < 0 ? bedtimeMinutes + (24 * 60) : bedtimeMinutes
        
        let bedtimeHour = adjustedBedtimeMinutes / 60
        let bedtimeMinute = adjustedBedtimeMinutes % 60
        
        let bedtimeString = String(format: "%d:%02d %@", 
                                  bedtimeHour > 12 ? bedtimeHour - 12 : (bedtimeHour == 0 ? 12 : bedtimeHour),
                                  bedtimeMinute,
                                  bedtimeHour >= 12 ? "PM" : "AM")
        
        let wakeString = String(format: "%d:%02d %@",
                               wakeComponents.hour! > 12 ? wakeComponents.hour! - 12 : (wakeComponents.hour! == 0 ? 12 : wakeComponents.hour!),
                               wakeComponents.minute!,
                               wakeComponents.hour! >= 12 ? "PM" : "AM")
        
        return """
        ## SLEEP BEDTIME CALCULATION
        
        User wakes at: \(wakeString)
        Prescribed bedtime: \(bedtimeString)
        
        SLEEP HABIT PRESCRIPTION RULE:
        - If prescribing a sleep habit, use: "In bed by \(bedtimeString)"
        - Reasoning template: "You wake at \(wakeString). Getting to bed by \(bedtimeString) gives you 8 hours (including 15 min to fall asleep), improving recovery and energy."
        - This is a SPECIFIC bedtime habit, not a generic "sleep 7+ hours" habit
        """
    }
    
    // MARK: - Good Enough Thresholds Section (PHASE 1.3)
    
    private static func buildGoodEnoughThresholdsSection() -> String {
        return """
        
        ## ⚠️ "GOOD ENOUGH" THRESHOLDS - CRITICAL RULE
        
        DO NOT prescribe habits for metrics that are already adequate UNLESS all metrics are optimal and user is ready for optimization.
        
        **Minimum Delta Rules:**
        - Protein: Only prescribe if gap >20g from target (e.g., 95g → 140g = YES, 170g → 176g = NO)
        - Steps: Only prescribe if <7500/day OR user is sedentary/lightly active (8450/day + moderately active = NO)
        - Sleep: Only prescribe if <7h average (7.5h = NO unless consistency poor)
        
        **If metric is within "good enough" range:**
        1. DO NOT include it as a non-negotiable
        2. DO acknowledge it's working in your rationale: "Your steps (8450/day) are excellent - we're focusing on sleep instead"
        3. DO explain why you're skipping it: "Protein at 170g (0.97g/lb) is already optimal - not worth a habit slot"
        
        **Example of CORRECT behavior:**
        User: 170g protein (target 176g), 8450 steps, 6.2h sleep, sedentary activity level
        ✅ PRESCRIBE: Sleep optimization (6.2h → 7h+)
        ✅ PRESCRIBE: Foundation training or daily walks (sedentary → active)
        ❌ SKIP: Protein (already optimal at 0.97g/lb)
        ❌ SKIP: Steps (already above 7500, focus on structured movement instead)
        
        RATIONALE EXAMPLE: "Your protein intake (170g) is already excellent at your weight. Your 8450 daily steps show good baseline movement. We're focusing on sleep (6.2h → 7h+) and adding structured movement to shift you from sedentary to moderately active."
        
        **REMEMBER:** The deficiency analysis above already filtered out metrics below minimum delta. If something appears in "SKIPPED METRICS", DO NOT prescribe it. Use the provided acknowledgment text in your rationale instead.
        
        """
    }
    
    // MARK: - Protein Prescription Rules (PHASE 2)
    
    private static func buildProteinPrescriptionRules() -> String {
        return """
        
        ## PROTEIN PRESCRIPTION FORMAT (PHASE 2 RULES)
        
        When prescribing protein habits, use this specific format:
        
        **Title Format:**
        "Eat [TARGET]g protein daily"
        Example: "Eat 140g protein daily"
        
        **Reason Field Structure:**
        "[Current status]. [Specific intervention if gap is 20-40g]. This supports your '[goal]' goal by [why it matters]."
        
        **If gap is 20-40g:** Include ONE specific intervention suggestion
        Examples:
        - "Your current intake (110g estimated) is below optimal. Add a morning protein shake (25g) to reach 140g (0.8g/lb). This supports your 'build muscle' goal by enabling muscle protein synthesis and recovery."
        - "Your protein (95g) is critically low. Include protein at breakfast (currently skipping) - Greek yogurt (20g) or eggs (12g per egg). This supports your 'lose weight' goal while preserving muscle mass."
        
        **If gap is >40g:** Include TWO specific intervention suggestions
        Example:
        - "Your current intake (95g) is critically low. Add protein shake at breakfast (25g) and increase portions at lunch/dinner (4oz chicken = 30g each). This supports your 'build muscle' goal by providing adequate amino acids for muscle repair and growth."
        
        **If gap is <20g:** DO NOT PRESCRIBE (see "good enough" thresholds above)
        
        **NEVER use these weak formats:**
        ❌ "Increase protein intake"
        ❌ "Eat more protein"
        ❌ "Track your protein"
        
        **ALWAYS use specific absolute targets:**
        ✅ "Eat 140g protein daily"
        ✅ "Eat 160g protein daily"
        
        **Optional subtitle (in reason):** "0.8g per lb bodyweight at your current weight" - but this is secondary to the specific intervention guidance.
        
        """
    }
    
    // MARK: - Tier-Specific Instructions
    
    private static func buildTierSpecificInstructions(user: UserContext, config: TierConfiguration) -> String {
        """
        ## TIER \(user.trainingTier) (\(user.trainingTierName.uppercased())) SPECIFIC INSTRUCTIONS
        
        **Maximum Non-Negotiables:** \(config.maxNonNegotiables)
        
        **Focus Areas for This Tier:**
        \(config.focusAreas.map { "- \($0)" }.joined(separator: "\n"))
        
        **Tone for This User:**
        \(config.toneGuidance)
        
        **RESTRICTIONS - DO NOT VIOLATE:**
        \(config.restrictions.map { "- \($0)" }.joined(separator: "\n"))
        """
    }
    
    // ADD THIS FUNCTION TO LongevityPlanPrompts.swift

    // MARK: - Generate Rationale from User Selections
    static func generateRationaleFromSelections(
        selectedInterventions: [Intervention],
        userContext: UserContext
    ) -> String {
        
        let interventionList = selectedInterventions.enumerated().map { index, intervention in
            """
            \(index + 1). \(intervention.title)
            Category: \(intervention.category)
            Why: \(intervention.whyThisMatters)
            Current: \(intervention.currentValue ?? "Unknown")
            Target: \(intervention.targetValue ?? "Unknown")
            """
        }.joined(separator: "\n\n")
        
        return """
        You are atlas's AI longevity coach. Generate a personalized rationale explaining WHY the user's selected interventions are the right starting point.
        
        ## USER PROFILE
        
        Name: \(userContext.name)
        Age: \(userContext.age)
        Training Tier: \(userContext.trainingTier) (\(userContext.trainingTierName))
        Primary Goal: \(formatGoal(userContext.primaryGoal))
        
        Metrics (30-day averages):
        - Sleep: \(formatOptional(userContext.sleepAverage, suffix: " hours"))
        - Protein: \(formatOptional(userContext.proteinGrams, suffix: "g/day"))
        - VO2 Max: \(formatOptional(userContext.vo2Max))
        - HRV: \(formatOptional(userContext.hrv, suffix: " ms"))
        - RHR: \(formatOptional(userContext.rhr, suffix: " bpm"))
        - Daily Steps: \(formatOptional(userContext.stepCount, suffix: " steps"))
        
        ## USER'S SELECTED INTERVENTIONS
        
        \(userContext.name) chose to start with these \(selectedInterventions.count) habits:
        
        \(interventionList)
        
        ## YOUR TASK
        
        Write 3-4 paragraphs (200-300 words total) explaining:
        
        1. **Why these specific interventions** - Reference their actual metrics and how these habits address their biggest gaps
        2. **Why this starting point works** - Explain why starting with \(selectedInterventions.count) habits (not more) is appropriate for Tier \(userContext.trainingTier)
        3. **What to expect** - Realistic timeline for seeing improvements in their metrics
        4. **The compound effect** - How these habits support each other and their training
        
        ## TONE & STYLE
        
        - Direct and honest (no cheerleading or false encouragement)
        - Evidence-based (reference their specific numbers)
        - Focus on compound effects, not individual habits
        - Acknowledge what they're NOT doing yet (that's intentional)
        
        ## EXAMPLE STRUCTURE (DO NOT COPY - CUSTOMIZE FOR THIS USER)
        
        "You've chosen to start with [habit 1] and [habit 2]. Based on your [metric 1: value] and [metric 2: value], this is exactly where you need to focus.
        
        [Habit 1] is your foundation - your [current value] is limiting [what it's limiting]. Research shows [evidence]. [Habit 2] supports this by [how it compounds].
        
        As a Tier [X] user, starting with [N] habits lets you build consistency before adding complexity. We're not prescribing [other interventions] yet because [reason] - that comes after you've locked in these fundamentals for 4-6 weeks.
        
        Expect to see [metric improvements] within [timeline]. These habits compound - better [habit 1] improves [habit 2] capacity, which accelerates [outcome]."
        
        ## OUTPUT
        
        Return ONLY the rationale text (no JSON, no markdown, no formatting).
        """
    }
    
    // MARK: - Event Training Instructions

private static func buildEventInstructions(user: UserContext) -> String {
    guard user.isTrainingForEvent,
          let eventName = user.eventName,
          let weeksUntilEvent = user.weeksUntilEvent else {
        return ""
    }
    
    return """
    ## EVENT TRAINING MODE (OVERRIDES PLAN TYPE)
    
    User is training for: \(eventName)
    Weeks until event: \(weeksUntilEvent)
    Event date: \(user.eventDate != nil ? formatEventDate(user.eventDate!) : "Not specified")
    
    ⚠️ CRITICAL: Event training uses template-based structured programs instead of a trainnig program.
    
    **How Event Training Works:**
    - EventPlanGenerator creates structured workout schedule from templates
    - Templates: Couch-to-5K, Intermediate 5K, Advanced 5K, 10K programs, Half Marathon, Marathon, HYROX Beginner/Intermediate/Advanced
    - TrainingProgram contains event-specific workouts with progressive periodization
    
    **YOUR ROLE (Non-Negotiables Only):**
    
    1. CREATE 2-3 LIFESTYLE NON-NEGOTIABLES:
       - Sleep optimization (if deficient)
       - Nutrition habits (protein, hydration)
       - Recovery protocols (if needed)
       - These support the event training but are separate from it
    
    2. INCLUDE ONE EVENT TRAINING REMINDER (REQUIRED):
       - Title: "\(eventName) Training"
       - Icon: "figure.run" (for running events) or "figure.mixed.cardio" (for multi-sport like HYROX)
       - Reason: "Your \(eventName) is in \(weeksUntilEvent) weeks. Your structured training plan (periodized for race day) will prepare you while building long-term cardiovascular fitness."
       - Position: This should be the LAST non-negotiable in your list
       - Purpose: REMINDER ONLY - actual workouts are in the TrainingProgram
    
    **WHAT YOU MUST NOT DO:**
    - ❌ DO NOT generate training schedule JSON (EventPlanGenerator handles this)
    - ❌ DO NOT prescribe generic cardio habits (event plan covers structured cardio)
    - ❌ DO NOT reference "movement plan" vs "training plan" (event mode overrides both)
    - ❌ DO NOT create workout-specific non-negotiables (these are in TrainingProgram)
    
    **Event Non-Negotiable Does NOT Consume Tier Slot:**
    - Tier 1 user in event mode gets: 2 lifestyle habits + event reminder (3 total)
    - Tier 2 user in event mode gets: 3 lifestyle habits + event reminder (4 total)
    - The event reminder is IN ADDITION to tier limits, not part of them
    
    **Example for Tier 1 User Training for Marathon:**
    ✅ CORRECT:
    1. "In bed by 10:30 PM" (sleep - tier slot 1)
    2. "Eat 140g protein daily" (nutrition - tier slot 2)
    3. "Marathon Training" (event reminder - NOT a tier slot)
    
    ❌ INCORRECT:
    1. "In bed by 10:30 PM"
    2. "Marathon Training" (this leaves no room for critical habits like protein!)
    
    Remember: Event training workouts are already structured in TrainingProgram. Your job is supporting lifestyle habits + the event reminder.
    """
} 
    
    // MARK: - Rationale Instructions
    
    private static func buildRationaleInstructions(user: UserContext) -> String {
        """
        3-4 sentences speaking directly to \(user.name) explaining WHY this specific plan was built for them.
        
        MUST include:
        - Reference to their specific data (sleep: \(formatOptional(user.sleepAverage, suffix: "h")), steps: \(formatOptional(user.stepCount)), etc.)
        - Why you chose these specific non-negotiables for their tier (\(user.trainingTierName))
        - What outcome they can expect if they execute consistently
        - MUST acknowledge what's already working (see SKIPPED METRICS section above)
        
        Tone: \(getTierConfiguration(tier: user.trainingTier).toneGuidance)
        
        DO NOT be generic. Reference actual numbers from their profile.
        """
    }
    
    // MARK: - Non-Negotiable Template
    
    private static func buildNonNegotiableTemplate(count: Int) -> String {
        var templates: [String] = []
        for i in 1...count {
            templates.append("""
            {
                  "title": "Short action-oriented title for habit \(i)",
                  "icon": "valid_sf_symbol_name",
                  "reason": "One sentence explaining why this matters for THIS user specifically"
                }
            """)
        }
        return templates.joined(separator: ",\n        ")
    }
    
    // MARK: - Output Rules
    
    private static func buildOutputRules(user: UserContext, config: TierConfiguration) -> String {
        """
        ## OUTPUT RULES - MUST FOLLOW
        
        1. Return ONLY valid JSON - no text before or after
        
        2. EXACTLY \(config.maxNonNegotiables) non-negotiables (not more, not less)
        
        3. Valid SF Symbol icons: bed.double.fill, fork.knife, pills.fill, heart.fill, moon.fill, figure.walk, figure.run, figure.mixed.cardio, cup.and.saucer.fill, sun.max.fill, drop.fill
        
        4. personalized_rationale MUST reference specific numbers from their data AND acknowledge what's working (from SKIPPED METRICS)
        
        5. DO NOT include structured training workouts as non-negotiables. Focus on: sleep, nutrition, daily movement (steps/stretching), recovery, lifestyle habits.
        
        6. \(user.isTrainingForEvent ? "EVENT MODE: Last non-negotiable MUST be '\(user.eventName ?? "Event") Training'" : "")
        """
    }
    
    // MARK: - Helper Functions
    
    private static func formatGoal(_ goal: String) -> String {
        switch goal {
        case "live_longer": return "Live Longer (longevity focus)"
        case "feel_better": return "Feel Better (energy & recovery)"
        case "look_better": return "Look Better (body composition)"
        case "get_stronger": return "Get Stronger (strength & muscle)"
        case "sport_performance": return "Sport/Performance"
        default: return goal
        }
    }
    
    private static func formatOptional(_ value: Double?, suffix: String = "") -> String {
        if let v = value, v > 0 {
            if suffix.contains("hours") || suffix.contains("h") {
                return String(format: "%.1f%@", v, suffix)
            }
            return "\(Int(v))\(suffix)"
        }
        return "Unknown"
    }
    
    private static func formatLongevityTier(_ tier: String) -> String {
        switch tier.lowercased() {
        case "at_risk": return "At Risk (Bottom 50%)"
        case "rising": return "Rising (50-70th percentile)"
        case "phoenix": return "Phoenix (70-85th percentile)"
        case "optimal": return "Optimal (85-95th percentile)"
        case "elite": return "Elite (Top 5%)"
        default: return tier
        }
    }
    
    private static func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
