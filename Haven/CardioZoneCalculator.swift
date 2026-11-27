import Foundation

struct CardioZoneCalculator {
    
    // MARK: - Calculate Heart Rate Zones
    static func calculateZones(age: Int, restingHR: Double? = nil) -> HeartRateZones {
        let maxHR = Double(220 - age)
        
        // Karvonen Formula if resting HR is available
        if let rhr = restingHR {
            let hrReserve = maxHR - rhr
            
            return HeartRateZones(
                zone1: HeartRateZone(
                    name: "Recovery",
                    min: Int(rhr + (hrReserve * 0.50)),
                    max: Int(rhr + (hrReserve * 0.60)),
                    purpose: "Active recovery, warm-up"
                ),
                zone2: HeartRateZone(
                    name: "Aerobic Base",
                    min: Int(rhr + (hrReserve * 0.60)),
                    max: Int(rhr + (hrReserve * 0.70)),
                    purpose: "Fat burning, endurance building"
                ),
                zone3: HeartRateZone(
                    name: "Tempo",
                    min: Int(rhr + (hrReserve * 0.70)),
                    max: Int(rhr + (hrReserve * 0.80)),
                    purpose: "Aerobic capacity"
                ),
                zone4: HeartRateZone(
                    name: "Threshold",
                    min: Int(rhr + (hrReserve * 0.80)),
                    max: Int(rhr + (hrReserve * 0.90)),
                    purpose: "Lactate threshold training"
                ),
                zone5: HeartRateZone(
                    name: "VO2 Max",
                    min: Int(rhr + (hrReserve * 0.90)),
                    max: Int(maxHR),
                    purpose: "Maximum effort, anaerobic"
                )
            )
        } else {
            // Simple % of max HR method
            return HeartRateZones(
                zone1: HeartRateZone(
                    name: "Recovery",
                    min: Int(maxHR * 0.50),
                    max: Int(maxHR * 0.60),
                    purpose: "Active recovery, warm-up"
                ),
                zone2: HeartRateZone(
                    name: "Aerobic Base",
                    min: Int(maxHR * 0.60),
                    max: Int(maxHR * 0.70),
                    purpose: "Fat burning, endurance building"
                ),
                zone3: HeartRateZone(
                    name: "Tempo",
                    min: Int(maxHR * 0.70),
                    max: Int(maxHR * 0.80),
                    purpose: "Aerobic capacity"
                ),
                zone4: HeartRateZone(
                    name: "Threshold",
                    min: Int(maxHR * 0.80),
                    max: Int(maxHR * 0.90),
                    purpose: "Lactate threshold training"
                ),
                zone5: HeartRateZone(
                    name: "VO2 Max",
                    min: Int(maxHR * 0.90),
                    max: Int(maxHR),
                    purpose: "Maximum effort, anaerobic"
                )
            )
        }
    }
    
    // MARK: - Determine Zone from Heart Rate
    static func determineZone(heartRate: Int, zones: HeartRateZones) -> Int {
        if heartRate >= zones.zone5.min { return 5 }
        if heartRate >= zones.zone4.min { return 4 }
        if heartRate >= zones.zone3.min { return 3 }
        if heartRate >= zones.zone2.min { return 2 }
        return 1
    }
    
    // MARK: - Verify Zone 2 Session
    static func verifyZone2Session(
        avgHeartRate: Double,
        targetZone: HeartRateZone,
        duration: Int
    ) -> Zone2Verification {
        let withinZone = Int(avgHeartRate) >= targetZone.min && Int(avgHeartRate) <= targetZone.max
        let longEnough = duration >= 30 // At least 30 minutes
        
        var feedback: String
        if withinZone && longEnough {
            feedback = "Perfect Zone 2 session! You stayed in the aerobic zone and built your base."
        } else if !withinZone && Int(avgHeartRate) > targetZone.max {
            feedback = "Heart rate was too high for Zone 2. Slow down - this should feel conversational."
        } else if !withinZone && Int(avgHeartRate) < targetZone.min {
            feedback = "Heart rate was too low. Pick up the pace slightly to hit Zone 2."
        } else if !longEnough {
            feedback = "Good effort, but aim for 30+ minutes to get full Zone 2 benefits."
        } else {
            feedback = "Keep working on staying in your target zone consistently."
        }
        
        return Zone2Verification(
            withinZone: withinZone,
            durationAdequate: longEnough,
            feedback: feedback,
            avgHeartRate: Int(avgHeartRate),
            targetMin: targetZone.min,
            targetMax: targetZone.max
        )
    }
    
    // MARK: - Detect VO2 Max Session
    static func detectVO2MaxSession(
        avgHeartRate: Double,
        maxHeartRate: Double,
        duration: Int,
        zones: HeartRateZones
    ) -> Bool {
        // VO2 Max session characteristics:
        // - Average HR in Zone 4-5
        // - Max HR reached Zone 5
        // - Duration 15-30 minutes
        
        let avgInHighZone = Int(avgHeartRate) >= zones.zone4.min
        let maxInZone5 = Int(maxHeartRate) >= zones.zone5.min
        let appropriateDuration = duration >= 15 && duration <= 45
        
        return avgInHighZone && maxInZone5 && appropriateDuration
    }
}

// MARK: - Supporting Types

struct HeartRateZones {
    let zone1: HeartRateZone
    let zone2: HeartRateZone
    let zone3: HeartRateZone
    let zone4: HeartRateZone
    let zone5: HeartRateZone
}

struct HeartRateZone {
    let name: String
    let min: Int
    let max: Int
    let purpose: String
}

struct Zone2Verification {
    let withinZone: Bool
    let durationAdequate: Bool
    let feedback: String
    let avgHeartRate: Int
    let targetMin: Int
    let targetMax: Int
}