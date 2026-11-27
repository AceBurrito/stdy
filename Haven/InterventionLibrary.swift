import Foundation

// MARK: - Intervention Template

struct InterventionTemplate: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let category: InterventionCategory
    let baseImpactScore: Int
    let whyTemplate: String
    let researchCitation: String
    let targetValue: String
    let deficiencyTrigger: DeficiencyTrigger?
    let requiresCalculation: Bool
    let howToGuide: String?
    let tierRequirement: Int?           // Minimum tier required (nil = all tiers)
    
    // NEW: User input support for personalized habits
    let requiresUserInput: Bool         // true = prompt user for custom name/details
    let userInputPrompt: String?        // e.g. "What are you learning or practicing?"
    let userInputPlaceholder: String?   // e.g. "Guitar, Spanish, woodworking..."
    let userInputDurationOptions: [Int]? // e.g. [15, 20, 30, 45] minutes
    
    // Default init preserving backward compatibility
    init(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        category: InterventionCategory,
        baseImpactScore: Int,
        whyTemplate: String,
        researchCitation: String,
        targetValue: String,
        deficiencyTrigger: DeficiencyTrigger?,
        requiresCalculation: Bool,
        howToGuide: String?,
        tierRequirement: Int?,
        requiresUserInput: Bool = false,
        userInputPrompt: String? = nil,
        userInputPlaceholder: String? = nil,
        userInputDurationOptions: [Int]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.baseImpactScore = baseImpactScore
        self.whyTemplate = whyTemplate
        self.researchCitation = researchCitation
        self.targetValue = targetValue
        self.deficiencyTrigger = deficiencyTrigger
        self.requiresCalculation = requiresCalculation
        self.howToGuide = howToGuide
        self.tierRequirement = tierRequirement
        self.requiresUserInput = requiresUserInput
        self.userInputPrompt = userInputPrompt
        self.userInputPlaceholder = userInputPlaceholder
        self.userInputDurationOptions = userInputDurationOptions
    }
}

// MARK: - Categories

enum InterventionCategory: String, CaseIterable {
    case sleep = "Sleep"
    case nutrition = "Nutrition"
    case recovery = "Recovery"
    case movement = "Movement"
    case lifestyle = "Lifestyle"
    case longevityFundamentals = "Longevity Fundamentals"
}

// MARK: - Deficiency Triggers

enum DeficiencyTrigger {
    case lowSleep               // <7h average
    case sleepQuality           // Duration OK but quality issues
    case lowProtein             // <0.6g/lb
    case lowVO2Max              // <50th percentile for age/gender
    case lowHRV                 // Age-adjusted (e.g., <40ms at age 40)
    case lowSteps               // <6,000/day
    case sedentary              // Desk job, minimal movement
    case highStress             // Self-reported or HRV variability
    case metabolic              // Blood sugar, insulin issues
    case cardiovascular         // BP, lipids, inflammation
    case recovery               // Training 4+x/week, need recovery support
    case aging                  // Age-related (40+, 50+, etc.)
    case cognitiveDecline       // NEW: Purpose/engagement related
}

// MARK: - Intervention Library

class InterventionLibrary {
    
    // MARK: - Full Intervention Library
    static let allInterventions: [InterventionTemplate] = [
        
        // ==========================================
        // SLEEP OPTIMIZATION (8)
        // ==========================================
        
        InterventionTemplate(
            id: "morning_sunlight_exposure",
            title: "Morning Sunlight",
            subtitle: "10 minutes within 1 hour of waking",
            icon: "sun.max.fill",
            category: .sleep,
            baseImpactScore: 88,
            whyTemplate: "Morning sunlight exposure anchors your circadian rhythm by triggering cortisol awakening response and suppressing residual melatonin. Even 10 minutes of natural light within the first hour of waking significantly improves sleep quality and daytime alertness.",
            researchCitation: "Zeitzer et al. (2000) - Light exposure and circadian rhythms: PMID 10742677",
            targetValue: "10 min within 1hr of waking",
            deficiencyTrigger: .sleepQuality,
            requiresCalculation: false,
            howToGuide: "Step outside for 10 minutes within 1 hour of waking. Face east if possible. No sunglasses. Cloudy days still effective.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "caffeine_cutoff",
            title: "Caffeine Cutoff",
            subtitle: "No caffeine after 2 PM",
            icon: "cup.and.saucer.fill",
            category: .sleep,
            baseImpactScore: 70,
            whyTemplate: "Caffeine has a 6-hour half-life and can reduce sleep quality even when total duration seems adequate. Your {sleepHours}h sleep duration is {sleepQuality}, but optimizing caffeine timing can improve sleep quality and deep sleep phases.",
            researchCitation: "Drake et al. (2013) - Caffeine effects on sleep: PMID 24235903",
            targetValue: "Last caffeine by 2 PM",
            deficiencyTrigger: .sleepQuality,
            requiresCalculation: false,
            howToGuide: "Calculate 6 hours before your target bedtime. If you sleep at 10 PM, last caffeine should be by 4 PM (we recommend 2 PM to be safe).",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "screen_limits_before_bed",
            title: "Digital Sunset",
            subtitle: "No screens 1 hour before bed",
            icon: "iphone.slash",
            category: .sleep,
            baseImpactScore: 75,
            whyTemplate: "Blue light from screens suppresses melatonin production by up to 50%, delaying sleep onset and reducing sleep quality. Even with blue light filters, engaging content keeps your mind activated when it should be winding down.",
            researchCitation: "Chang et al. (2015) - Evening use of light-emitting eReaders: PMID 25535358",
            targetValue: "All screens off 60 min before bed",
            deficiencyTrigger: .sleepQuality,
            requiresCalculation: false,
            howToGuide: "Set phone to Do Not Disturb 60 min before bed. Charge phone outside bedroom. Use paper books, journaling, or conversation instead.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "consistent_sleep_schedule",
            title: "Sleep Schedule",
            subtitle: "Wake/sleep within ±30 minutes daily",
            icon: "clock.fill",
            category: .sleep,
            baseImpactScore: 82,
            whyTemplate: "Your body's circadian rhythm thrives on consistency. Varying sleep/wake times by more than 30 minutes (even on weekends) disrupts metabolic health, increases inflammation, and reduces cognitive performance.",
            researchCitation: "Chaput et al. (2020) - Sleep timing and consistency: PMID 32054160",
            targetValue: "±30 min consistency",
            deficiencyTrigger: .sleepQuality,
            requiresCalculation: false,
            howToGuide: "Choose a realistic wake time you can maintain 7 days/week. Set alarm for same time daily. Go to bed when naturally tired.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "magnesium_glycinate",
            title: "Magnesium Glycinate",
            subtitle: "400mg before bed",
            icon: "pills.fill",
            category: .sleep,
            baseImpactScore: 68,
            whyTemplate: "Magnesium deficiency is common (nearly 50% of US adults) and impairs sleep quality by disrupting GABA neurotransmitter function. Magnesium glycinate specifically improves sleep onset, depth, and reduces nighttime awakenings.",
            researchCitation: "Abbasi et al. (2012) - Magnesium supplementation on insomnia: PMID 23853635",
            targetValue: "400mg before bed",
            deficiencyTrigger: .sleepQuality,
            requiresCalculation: false,
            howToGuide: "Take 400mg magnesium glycinate (NOT oxide) 30-60min before bed. Start with 200mg if new to supplementation.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "morning_walk",
            title: "Morning Walk",
            subtitle: "10 minutes outdoors after waking",
            icon: "figure.walk",
            category: .sleep,
            baseImpactScore: 85,
            whyTemplate: "A short walk within the first hour of waking combines three powerful interventions: morning light exposure to anchor circadian rhythm, gentle movement to clear adenosine, and cortisol regulation that improves both daytime alertness and nighttime sleep quality.",
            researchCitation: "Mead et al. (2009) - Exercise and well-being: PMID 20479481; Zeitzer et al. (2000) - Light and circadian rhythms: PMID 10742677",
            targetValue: "10 min walk within 1hr of waking",
            deficiencyTrigger: .sleepQuality,
            requiresCalculation: false,
            howToGuide: "Step outside within an hour of waking. Walk at a comfortable pace for 10 minutes. No sunglasses. Can combine with morning sunlight habit. Fasted is fine.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "nasal_breathing",
            title: "Nasal Breathing",
            subtitle: "10 minutes conscious practice daily",
            icon: "nose",
            category: .sleep,
            baseImpactScore: 74,
            whyTemplate: "Nasal breathing increases nitric oxide production, improves oxygen uptake by 10-15%, lowers blood pressure, and significantly improves sleep quality by reducing snoring and sleep apnea events. Conscious daily practice trains the habit to carry over into sleep.",
            researchCitation: "Dallam et al. (2018) - Nasal breathing during exercise: PMID 29395837; Nestor (2020) - Breath: The New Science of a Lost Art",
            targetValue: "10 min conscious nasal breathing",
            deficiencyTrigger: .sleepQuality,
            requiresCalculation: false,
            howToGuide: "Set a 10-minute timer. Breathe only through your nose, slow and steady. Practice during walks, stretching, or while reading. Tape mouth at night with surgical tape if comfortable (helps train nighttime nasal breathing).",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "evening_wind_down",
            title: "Wind-Down Routine",
            subtitle: "20-minute pre-sleep ritual",
            icon: "moon.fill",
            category: .sleep,
            baseImpactScore: 76,
            whyTemplate: "A consistent pre-sleep routine signals your brain to begin the transition to sleep. Combining dim lighting, relaxation, and screen avoidance in a repeatable sequence improves sleep onset latency and overall sleep quality within 2-3 weeks.",
            researchCitation: "Irish et al. (2015) - Role of sleep hygiene in promoting public health: PMID 25454674",
            targetValue: "20 min routine nightly",
            deficiencyTrigger: .sleepQuality,
            requiresCalculation: false,
            howToGuide: "Build a 20-minute sequence you can repeat nightly: dim lights, light stretching or reading, brush teeth, brief journaling or gratitude practice. Same order each night. The consistency is what trains your brain.",
            tierRequirement: nil
        ),
        
        // ==========================================
        // NUTRITION & SUPPLEMENTATION (8)
        // ==========================================
        
        InterventionTemplate(
            id: "protein_target",
            title: "Protein Target",
            subtitle: "{target}g daily (0.8g/lb)",
            icon: "fork.knife",
            category: .nutrition,
            baseImpactScore: 85,
            whyTemplate: "As a {age}-year-old focused on longevity, adequate protein intake (0.8g/lb bodyweight) is critical for maintaining muscle mass. Muscle mass is the strongest predictor of healthy aging and all-cause mortality after age 40.",
            researchCitation: "Bauer et al. (2013) - Protein intake and muscle mass in aging: PMID 23343671",
            targetValue: "{calculated}",
            deficiencyTrigger: .lowProtein,
            requiresCalculation: true,
            howToGuide: "Track protein for 3 days to establish baseline. Aim for 30-40g per meal. Prioritize complete proteins (meat, fish, eggs, dairy, whey).",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "protein_breakfast",
            title: "30g Protein Breakfast",
            subtitle: "Front-load protein in first meal",
            icon: "sunrise.fill",
            category: .nutrition,
            baseImpactScore: 80,
            whyTemplate: "Distributing protein evenly across meals — starting with 30g+ at breakfast — stimulates muscle protein synthesis more effectively than back-loading protein at dinner. Morning protein also improves satiety, reduces cravings, and stabilizes blood sugar throughout the day.",
            researchCitation: "Mamerow et al. (2014) - Dietary protein distribution and muscle protein synthesis: PMID 24477298",
            targetValue: "30g+ protein at breakfast",
            deficiencyTrigger: .lowProtein,
            requiresCalculation: false,
            howToGuide: "Quick options: 4 eggs (24g) + Greek yogurt (15g), protein shake with milk (30-40g), cottage cheese bowl with nuts (30g+). Prep the night before if mornings are rushed.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "antioxidant_rich_foods",
            title: "Antioxidant-Rich Foods",
            subtitle: "One serving of berries, dark chocolate, or green tea daily",
            icon: "leaf.circle.fill",
            category: .nutrition,
            baseImpactScore: 79,
            whyTemplate: "Foods high in polyphenols — naturally occurring compounds in berries, dark chocolate, green tea, and colorful vegetables — are the strongest dietary predictor of reduced cardiovascular mortality. These compounds reduce inflammation, improve blood vessel function, and protect against cellular aging.",
            researchCitation: "Grosso et al. (2017) - Dietary polyphenols and mortality: PMID 28359256",
            targetValue: "1+ serving daily",
            deficiencyTrigger: .cardiovascular,
            requiresCalculation: false,
            howToGuide: "Pick one daily: a handful of blueberries or mixed berries, 1-2 squares of dark chocolate (70%+), 2-3 cups of green tea, or a colorful salad. Variety is good but consistency matters more.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "hydration_target",
            title: "Hydration Goal",
            subtitle: "{target}oz daily (0.5oz per lb)",
            icon: "drop.fill",
            category: .nutrition,
            baseImpactScore: 78,
            whyTemplate: "Even mild dehydration (1-2% body weight) impairs cognitive performance, physical performance, and mood. Adequate hydration supports cardiovascular function, temperature regulation, and cellular metabolism.",
            researchCitation: "Armstrong et al. (2007) - Mild dehydration affects mood: PMID 22190027",
            targetValue: "{calculated}",
            deficiencyTrigger: nil,
            requiresCalculation: true,
            howToGuide: "Drink 16-24oz upon waking. Keep water bottle visible. Front-load hydration (most by 2 PM). Urine should be pale yellow.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "creatine_supplementation",
            title: "Creatine Monohydrate",
            subtitle: "5g daily",
            icon: "bolt.fill",
            category: .nutrition,
            baseImpactScore: 80,
            whyTemplate: "Creatine is one of the most researched supplements with proven benefits for muscle strength, cognitive function, and neuroprotection. 5g daily increases muscle creatine stores by 20-40%, improving strength, power, and potentially brain health as you age.",
            researchCitation: "Rawson & Venezia (2011) - Creatine in elderly and cognitive function: PMID 21394604",
            targetValue: "5g daily",
            deficiencyTrigger: .recovery,
            requiresCalculation: false,
            howToGuide: "Mix 5g creatine monohydrate in water or protein shake. Take daily (no loading phase needed). Expect 2-5lb water weight gain (normal and beneficial).",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "omega3_supplementation",
            title: "Omega-3 Fatty Acids",
            subtitle: "2-3g EPA/DHA daily",
            icon: "fish.fill",
            category: .nutrition,
            baseImpactScore: 83,
            whyTemplate: "Omega-3 fatty acids (EPA/DHA) reduce inflammation, improve cardiovascular health, and are associated with 20-30% reduction in cardiovascular mortality. Most people consume insufficient omega-3s from diet alone.",
            researchCitation: "Mozaffarian & Wu (2011) - Omega-3 and cardiovascular disease: PMID 22074852",
            targetValue: "2-3g EPA/DHA daily",
            deficiencyTrigger: .cardiovascular,
            requiresCalculation: false,
            howToGuide: "Take 2-3g combined EPA+DHA daily. Check label for actual EPA/DHA content. Nordic Naturals, Carlson Labs are quality brands. Take with food.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "vitamin_d_supplementation",
            title: "Vitamin D3",
            subtitle: "2000-4000 IU daily",
            icon: "sun.max.fill",
            category: .nutrition,
            baseImpactScore: 76,
            whyTemplate: "Vitamin D deficiency (<30 ng/mL) affects ~40% of US adults and is associated with increased risk of cardiovascular disease, cancer, and all-cause mortality. Supplementation is necessary for most people, especially in winter months.",
            researchCitation: "Holick (2011) - Vitamin D deficiency: PMID 17634462",
            targetValue: "2000-4000 IU daily",
            deficiencyTrigger: nil,
            requiresCalculation: false,
            howToGuide: "Take 2000-4000 IU vitamin D3 (not D2) daily with fatty meal. Get blood level tested (25-hydroxyvitamin D). Target 40-60 ng/mL.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "meal_timing",
            title: "Eating Window",
            subtitle: "Finish last meal 3hrs before bed",
            icon: "clock.arrow.circlepath",
            category: .nutrition,
            baseImpactScore: 72,
            whyTemplate: "Eating close to bedtime impairs sleep quality, increases overnight blood sugar, and disrupts metabolic processes that rely on overnight fasting. A 3-hour buffer allows digestion to complete before sleep.",
            researchCitation: "St-Onge et al. (2016) - Meal timing and cardiovascular disease: PMID 27749084",
            targetValue: "Last meal 3hrs before bed",
            deficiencyTrigger: .metabolic,
            requiresCalculation: false,
            howToGuide: "Calculate bedtime minus 3 hours = last meal cutoff. If you sleep at 10 PM, finish dinner by 7 PM. Water and herbal tea are fine.",
            tierRequirement: nil
        ),
        
        // ==========================================
        // RECOVERY & HRV OPTIMIZATION (8)
        // ==========================================
        
        InterventionTemplate(
            id: "resonant_breathing",
            title: "Resonant Breathing",
            subtitle: "5-10 minutes daily (5-6 breaths/min)",
            icon: "wind",
            category: .recovery,
            baseImpactScore: 82,
            whyTemplate: "Resonant breathing at 5-6 breaths per minute is the most effective breathwork protocol for increasing HRV and activating parasympathetic (rest/recovery) nervous system. With your current HRV of {hrv}ms, 10 minutes daily can improve HRV by 20-30% within 8 weeks.",
            researchCitation: "Lehrer et al. (2020) - Heart rate variability biofeedback: PMID 32517071",
            targetValue: "5-10 min daily, 5-6 breaths/min",
            deficiencyTrigger: .lowHRV,
            requiresCalculation: false,
            howToGuide: "Sit comfortably. Breathe in through nose for 5 seconds, out for 5 seconds. Repeat for 5-10 minutes. Apps: Breathwrk, Breath Ball.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "sauna_protocol",
            title: "Sauna Sessions",
            subtitle: "15-20 minutes, 4x per week",
            icon: "flame.fill",
            category: .recovery,
            baseImpactScore: 90,
            whyTemplate: "Regular sauna use (4-7x/week, 15-20 minutes, 174°F+) is associated with 40% reduction in cardiovascular mortality and 40% reduction in all-cause mortality. Benefits include improved cardiovascular function, reduced inflammation, and enhanced heat shock protein production.",
            researchCitation: "Laukkanen et al. (2015) - Sauna bathing and cardiovascular mortality: PMID 25705824",
            targetValue: "4-7 sessions/week, 15-20 min",
            deficiencyTrigger: nil,
            requiresCalculation: false,
            howToGuide: "Use dry sauna at 174-194°F. Start with 10 min if new, work up to 20 min. Hydrate before/after. 4x/week minimum for mortality benefits.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "cold_shower_finish",
            title: "Cold Shower Finish",
            subtitle: "30-60 seconds cold at end of shower",
            icon: "shower.fill",
            category: .recovery,
            baseImpactScore: 75,
            whyTemplate: "Ending your shower with 30-60 seconds of cold water activates the sympathetic nervous system, increases norepinephrine by 200-300%, reduces inflammation, and improves mood and alertness. Regular cold showers reduce sick days by 29%. This is the most accessible form of cold exposure — no equipment needed.",
            researchCitation: "Buijze et al. (2016) - Cold showering and health: PMID 26928557",
            targetValue: "30-60 sec cold to finish shower",
            deficiencyTrigger: .lowHRV,
            requiresCalculation: false,
            howToGuide: "At the end of your normal shower, turn water to cold (as cold as available). Start with 15 seconds, add 15 seconds each week until you reach 60 seconds. Breathe steadily through the nose. Focus on relaxing into the discomfort.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "cold_plunge",
            title: "Cold Plunge",
            subtitle: "2-3 minutes at 50-59°F",
            icon: "snowflake",
            category: .recovery,
            baseImpactScore: 82,
            whyTemplate: "Cold water immersion at 50-59°F for 2-3 minutes provides a stronger hormetic stress response than cold showers — increasing norepinephrine by up to 530%, significantly improving HRV, reducing systemic inflammation, and accelerating recovery between training sessions.",
            researchCitation: "Šrámek et al. (2000) - Cold water immersion and catecholamine response: PMID 10751106; Buijze et al. (2016): PMID 26928557",
            targetValue: "2-3 min at 50-59°F",
            deficiencyTrigger: .lowHRV,
            requiresCalculation: false,
            howToGuide: "Water temperature 50-59°F (10-15°C). Submerge to shoulders. Start with 1 minute, build to 3 minutes over 2-3 weeks. Breathe slowly through the nose. Avoid within 4 hours of strength training (blunts hypertrophy signal).",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "meditation_practice",
            title: "Daily Meditation",
            subtitle: "10-20 minutes daily",
            icon: "brain.head.profile",
            category: .recovery,
            baseImpactScore: 80,
            whyTemplate: "Regular meditation practice reduces stress, improves HRV, lowers blood pressure, and is associated with improved immune function and reduced inflammation. 10-20 minutes daily shows measurable benefits within 8 weeks.",
            researchCitation: "Pascoe et al. (2017) - Mindfulness and physiological stress markers: PMID 28153588",
            targetValue: "10-20 min daily",
            deficiencyTrigger: .highStress,
            requiresCalculation: false,
            howToGuide: "Start with 5 minutes. Sit comfortably, focus on breath. When mind wanders, gently return. Apps: Headspace, Calm, Insight Timer.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "foam_rolling",
            title: "Self-Myofascial Release",
            subtitle: "10 minutes daily (foam rolling)",
            icon: "figure.rolling",
            category: .recovery,
            baseImpactScore: 68,
            whyTemplate: "Regular foam rolling improves range of motion, reduces muscle soreness, enhances recovery between training sessions, and may improve arterial function. 10 minutes daily supports tissue quality and recovery capacity.",
            researchCitation: "Wiewelhove et al. (2019) - Foam rolling effects on performance: PMID 30580468",
            targetValue: "10 min daily",
            deficiencyTrigger: .recovery,
            requiresCalculation: false,
            howToGuide: "Spend 1-2 minutes per major muscle group. Roll slowly, pause on tender spots for 30-60 seconds. Do AFTER workouts or before bed.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "progressive_relaxation",
            title: "Progressive Relaxation",
            subtitle: "10 minutes before bed",
            icon: "bed.double.fill",
            category: .recovery,
            baseImpactScore: 71,
            whyTemplate: "Progressive muscle relaxation (systematically tensing and releasing muscle groups) reduces stress, improves sleep quality, and lowers blood pressure. Particularly effective for stress-related sleep issues.",
            researchCitation: "Toussaint et al. (2021) - Progressive muscle relaxation effectiveness: PMID 33522111",
            targetValue: "10 min before bed",
            deficiencyTrigger: .highStress,
            requiresCalculation: false,
            howToGuide: "Lie down. Starting with feet, tense muscle group for 5 seconds, release for 30 seconds. Move up body systematically.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "five_minute_journal",
            title: "5-Minute Journal",
            subtitle: "Morning intentions + evening reflection",
            icon: "book.fill",
            category: .recovery,
            baseImpactScore: 73,
            whyTemplate: "Combining morning intention-setting with evening gratitude and reflection improves mental health, reduces stress, enhances sleep quality, and strengthens goal-directed behavior. The structured format takes under 5 minutes and creates measurable psychological benefits within 3 weeks.",
            researchCitation: "Wood et al. (2010) - Gratitude and well-being: PMID 20066114; Emmons & McCullough (2003) - Counting blessings: PMID 14610439",
            targetValue: "5 min daily (AM + PM)",
            deficiencyTrigger: .highStress,
            requiresCalculation: false,
            howToGuide: "Morning (2 min): Write 3 things you're grateful for + 1 intention for the day. Evening (3 min): Write 1 win from today + 1 thing you'd improve. Keep journal by your bed.",
            tierRequirement: nil
        ),
        
        // ==========================================
        // MOVEMENT & MOBILITY (8)
        // ==========================================
        
        InterventionTemplate(
            id: "daily_steps_target",
            title: "Daily Steps",
            subtitle: "8,000-10,000 steps daily",
            icon: "figure.walk",
            category: .movement,
            baseImpactScore: 83,
            whyTemplate: "Daily step count is one of the strongest predictors of longevity. Each 1,000 steps above 4,000 reduces mortality risk by 6-8%. For your moderately active lifestyle, 8,000-10,000 steps daily optimizes NEAT and cardiovascular health without overtraining risk.",
            researchCitation: "Paluch et al. (2022) - Daily steps and all-cause mortality: PMID 35363218",
            targetValue: "8,000-10,000 steps daily",
            deficiencyTrigger: .lowSteps,
            requiresCalculation: false,
            howToGuide: "Track with Apple Watch or iPhone. Break into chunks: 2,000 steps morning walk, 3,000 lunch walk, 3,000 evening walk. Walking meetings count.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "post_meal_walks",
            title: "Post-Meal Walking",
            subtitle: "10-15 minute walk after meals",
            icon: "figure.walk",
            category: .movement,
            baseImpactScore: 77,
            whyTemplate: "Brief walks after meals (especially dinner) improve glucose control by 20-30%, reduce post-meal blood sugar spikes, and improve insulin sensitivity. Particularly powerful for metabolic health and diabetes prevention.",
            researchCitation: "Reynolds et al. (2016) - Walking after meals and postprandial glycaemia: PMID 27747394",
            targetValue: "10-15 min after meals",
            deficiencyTrigger: .metabolic,
            requiresCalculation: false,
            howToGuide: "Set phone reminder for 5-10 minutes after meals. Walk at comfortable pace for 10-15 minutes. Even 5 minutes helps. Biggest difference after dinner.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "mobility_routine",
            title: "Mobility Work",
            subtitle: "15 minutes daily",
            icon: "figure.flexibility",
            category: .movement,
            baseImpactScore: 75,
            whyTemplate: "Daily mobility work maintains joint health, reduces injury risk, improves movement quality, and supports active lifestyle into later decades. 15 minutes daily prevents age-related mobility decline and improves functional capacity.",
            researchCitation: "Multiple studies on flexibility/mobility and aging (compiled evidence)",
            targetValue: "15 min daily",
            deficiencyTrigger: .recovery,
            requiresCalculation: false,
            howToGuide: "Focus on hips, thoracic spine, shoulders, ankles. YouTube: Tom Merrick, Squat University, GMB Fitness. Do after training or before bed.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "dead_hang_practice",
            title: "Dead Hang Practice",
            subtitle: "1-2 minutes accumulated daily",
            icon: "hand.raised.fill",
            category: .movement,
            baseImpactScore: 81,
            whyTemplate: "Grip strength is one of the strongest predictors of all-cause mortality — each 5kg decline is associated with a 16% increase in mortality risk. Dead hangs are the most effective daily grip training: they build forearm and hand strength, decompress the spine, and improve shoulder health simultaneously.",
            researchCitation: "Celis-Morales et al. (2018) - Grip strength associations with outcomes: PMID 29867156; Suni et al. (2014) - Hanging and shoulder health",
            targetValue: "1-2 min accumulated daily",
            deficiencyTrigger: .aging,
            requiresCalculation: false,
            howToGuide: "Find a bar you can hang from (pull-up bar, playground, door frame bar). Hang with relaxed shoulders. Start with 3 sets of 15-20 seconds, build to 3 sets of 30+ seconds. Accumulate 1-2 minutes total daily.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "deep_squat_hold",
            title: "Deep Squat Hold",
            subtitle: "5-10 minutes accumulated daily",
            icon: "figure.strengthtraining.functional",
            category: .movement,
            baseImpactScore: 78,
            whyTemplate: "The ability to get up from the floor without using your hands is a strong predictor of mortality — the sitting-rising test shows each point lost associates with 21% increased mortality risk. Daily deep squat holds maintain the hip, knee, and ankle mobility that most adults lose by age 40, preserving functional independence.",
            researchCitation: "de Brito et al. (2012) - Sitting-rising test and mortality: PMID 23242910",
            targetValue: "5-10 min accumulated daily",
            deficiencyTrigger: .aging,
            requiresCalculation: false,
            howToGuide: "Squat as deep as comfortable with feet flat on the ground. Hold the bottom position. Start with 30-second holds, accumulate 5-10 minutes throughout the day. Hold onto a doorframe or counter for balance if needed. Do while brushing teeth, waiting for coffee, watching TV.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "balance_training",
            title: "Balance Practice",
            subtitle: "5 minutes daily balance exercises",
            icon: "figure.mind.and.body",
            category: .movement,
            baseImpactScore: 78,
            whyTemplate: "Balance declines with age and is a strong predictor of falls, fractures, and mortality in older adults. Regular balance training prevents decline, improves stability, and maintains independence. Falls are a leading cause of injury and death in people over 65.",
            researchCitation: "Sherrington et al. (2019) - Exercise for preventing falls: PMID 31476245",
            targetValue: "5 min daily balance work",
            deficiencyTrigger: .aging,
            requiresCalculation: false,
            howToGuide: "Single-leg stands (30-60 sec each leg, eyes open then closed), tandem walk (heel-to-toe), single-leg deadlifts. Brush teeth standing on one leg.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "yoga_practice",
            title: "Yoga Sessions",
            subtitle: "2-3x per week, 30-45 minutes",
            icon: "figure.yoga",
            category: .movement,
            baseImpactScore: 76,
            whyTemplate: "Regular yoga practice improves flexibility, balance, strength, and reduces stress. Associated with improved cardiovascular health, reduced inflammation, and enhanced cognitive function. 2-3x/week shows measurable benefits.",
            researchCitation: "Gothe et al. (2019) - Yoga effects on brain health: PMID 30893749",
            targetValue: "2-3 sessions/week, 30-45 min",
            deficiencyTrigger: .highStress,
            requiresCalculation: false,
            howToGuide: "Start with beginner-friendly styles (Hatha, Yin). YouTube: Yoga with Adriene, Breathe and Flow. Apps: Down Dog.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "limiting_sitting",
            title: "Movement Breaks",
            subtitle: "Stand and move every 30-60 minutes",
            icon: "figure.stand",
            category: .movement,
            baseImpactScore: 76,
            whyTemplate: "Prolonged sitting is associated with increased mortality risk independent of exercise. Breaking up sitting every 30-60 minutes improves metabolic health, reduces back pain, and partially mitigates the cardiovascular risk of sedentary work.",
            researchCitation: "Ekelund et al. (2016) - Sitting time and mortality: PMID 27475271",
            targetValue: "Move every 30-60 min",
            deficiencyTrigger: .sedentary,
            requiresCalculation: false,
            howToGuide: "Set timer for 30-minute intervals. Stand, walk, or stretch for 2-5 minutes each hour. Take phone calls standing or walking. Walking meetings when possible.",
            tierRequirement: nil
        ),
        
        // ==========================================
        // LIFESTYLE & PURPOSE (6)
        // ==========================================
        
        InterventionTemplate(
            id: "nature_exposure",
            title: "Time in Nature",
            subtitle: "20 minutes outdoors daily",
            icon: "leaf.fill",
            category: .lifestyle,
            baseImpactScore: 75,
            whyTemplate: "Spending 120+ minutes per week in nature is associated with significantly better health and well-being. Nature exposure reduces cortisol, lowers blood pressure, improves mood, and enhances immune function. 20 minutes daily exceeds the threshold for measurable benefits.",
            researchCitation: "White et al. (2019) - 120 minutes per week in nature: PMID 31120470",
            targetValue: "20+ min outdoors daily",
            deficiencyTrigger: .highStress,
            requiresCalculation: false,
            howToGuide: "Walk, sit, or exercise outdoors for 20+ minutes daily. Local parks count. Combine with morning walk, lunch break, or evening stroll. Green spaces preferred.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "daily_skill_practice",
            title: "Daily Skill Practice",
            subtitle: "15-30 minutes practicing a skill",
            icon: "sparkles",
            category: .lifestyle,
            baseImpactScore: 80,
            whyTemplate: "Actively learning and practicing a skill — an instrument, language, craft, or sport — forces neuroplasticity and builds cognitive reserve that protects against age-related cognitive decline. A strong sense of purpose through mastery is associated with a 15% reduction in all-cause mortality and up to 7 additional years of life expectancy.",
            researchCitation: "Hill & Turiano (2014) - Purpose in life and mortality: PMID 24630623; Boyle et al. (2010) - Purpose and Alzheimer's risk: PMID 20308813",
            targetValue: "15-30 min daily practice",
            deficiencyTrigger: .cognitiveDecline,
            requiresCalculation: false,
            howToGuide: "Choose something with progressive challenge — not passive consumption. Practice with intention to improve. Track progress weekly.",
            tierRequirement: nil,
            requiresUserInput: true,
            userInputPrompt: "What are you learning or practicing?",
            userInputPlaceholder: "Guitar, Spanish, woodworking, chess...",
            userInputDurationOptions: [15, 20, 30, 45]
        ),
        
        InterventionTemplate(
            id: "creative_flow_time",
            title: "Creative Flow Time",
            subtitle: "30 minutes on a personal project",
            icon: "lightbulb.fill",
            category: .lifestyle,
            baseImpactScore: 78,
            whyTemplate: "Deep, uninterrupted work on a personal project induces a flow state that reduces cortisol, lowers inflammation markers, and strengthens neural connectivity. Beyond the cognitive benefits, having a project you care about provides the sense of purpose that Blue Zones research links to 7 additional years of life expectancy.",
            researchCitation: "Buettner (2008) - Blue Zones and purpose: ISBN 978-1426202742; Csikszentmihalyi (1990) - Flow and optimal experience",
            targetValue: "30+ min deep work on project",
            deficiencyTrigger: .cognitiveDecline,
            requiresCalculation: false,
            howToGuide: "Block 30+ minutes of uninterrupted time. Phone on Do Not Disturb. Work on something you're building — code, writing, art, a business, a garden. The key is personal investment and progressive challenge.",
            tierRequirement: nil,
            requiresUserInput: true,
            userInputPrompt: "What's your project?",
            userInputPlaceholder: "Side business, novel, app, garden, restoration...",
            userInputDurationOptions: [20, 30, 45, 60]
        ),
        
        InterventionTemplate(
            id: "fiber_intake",
            title: "Fiber Target",
            subtitle: "30-40g daily",
            icon: "leaf.fill",
            category: .lifestyle,
            baseImpactScore: 79,
            whyTemplate: "High fiber intake (30-40g/day) is associated with 15-30% reduction in all-cause mortality. Fiber supports gut health, metabolic function, cardiovascular health, and satiety.",
            researchCitation: "Reynolds et al. (2019) - Carbohydrate quality and health: PMID 30638909",
            targetValue: "30-40g daily",
            deficiencyTrigger: .metabolic,
            requiresCalculation: false,
            howToGuide: "Prioritize whole foods: vegetables (5+ servings), fruits (2-3), legumes, whole grains. Track for 3 days to baseline. Add gradually to avoid digestive discomfort.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "processed_food_limitation",
            title: "Whole Foods Priority",
            subtitle: "<10% calories from ultra-processed",
            icon: "cart.fill",
            category: .lifestyle,
            baseImpactScore: 81,
            whyTemplate: "Ultra-processed foods are associated with increased risk of obesity, cardiovascular disease, cancer, and all-cause mortality. Each 10% increase in processed food intake associates with a 14% increase in mortality risk.",
            researchCitation: "Srour et al. (2019) - Ultra-processed food and cardiovascular disease: PMID 31537451",
            targetValue: "<10% from processed foods",
            deficiencyTrigger: .metabolic,
            requiresCalculation: false,
            howToGuide: "Cook from whole ingredients 80%+ of meals. Avoid foods with >5 ingredients or ingredients you can't pronounce. Batch cook for convenience.",
            tierRequirement: nil
        ),
        
        InterventionTemplate(
            id: "dental_hygiene",
            title: "Daily Flossing",
            subtitle: "Floss once daily",
            icon: "mouth.fill",
            category: .lifestyle,
            baseImpactScore: 73,
            whyTemplate: "Periodontal (gum) disease is linked to cardiovascular disease, diabetes, and systemic inflammation. Daily flossing reduces gum disease risk by 40% and is associated with reduced systemic inflammation. Oral health is a surprisingly strong predictor of overall health and longevity.",
            researchCitation: "Chapple et al. (2018) - Lifestyle interaction with dental caries and periodontal diseases: PMID 29926491",
            targetValue: "Floss once daily",
            deficiencyTrigger: nil,
            requiresCalculation: false,
            howToGuide: "Floss before brushing. Use proper technique (C-shape around each tooth, below gum line). Water flossers (Waterpik) are an effective alternative.",
            tierRequirement: nil
        ),
    ]
    
    // MARK: - Get Interventions by Category
    static func getInterventions(for category: InterventionCategory) -> [InterventionTemplate] {
        return allInterventions.filter { $0.category == category }
    }
    
    // MARK: - Get All Available Interventions (ignoring deprecated tier system)
    static func getAllAvailableInterventions() -> [InterventionTemplate] {
        return allInterventions
    }
    
    // MARK: - Get Interventions Requiring User Input
    static func getInterventionsRequiringInput() -> [InterventionTemplate] {
        return allInterventions.filter { $0.requiresUserInput }
    }
}