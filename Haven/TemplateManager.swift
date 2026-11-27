import Foundation
import SwiftData

class TemplateManager {
    
    // MARK: - Load Templates from Bundle
    
    static func loadTemplatesFromBundle(modelContext: ModelContext) async {
        print("🔵 [TemplateManager] Loading templates from bundle...")
        
        // Check if templates already exist
        let descriptor = FetchDescriptor<EventTemplate>()
        let existingCount = (try? modelContext.fetch(descriptor).count) ?? 0
        
        if existingCount > 0 {
            print("✅ [TemplateManager] Templates already loaded (\(existingCount) templates)")
            return
        }
        
        // DEBUG: Print bundle resource path
        print("🔍 [DEBUG] Bundle resource path: \(Bundle.main.resourcePath ?? "nil")")
        
        let templateFiles = [
            "5k_couch_to_5k_8week",
            "5k_intermediate_6week",
            "5k_advanced_6week",
            "10k_couch_to_10k_12week",
            "10k_intermediate_8week",
            "10k_advanced_8week",
            "half_marathon_couch_to_half_16week",
            "half_marathon_intermediate_12week",
            "half_marathon_advanced_12week",
            "marathon_intermediate_16week",
            "hyrox_couch_to_hyrox_16week",
            "hyrox_intermediate_12week",
            "hyrox_advanced_8week"
        ]
        
        var loadedCount = 0
        
        for fileName in templateFiles {
            print("🔍 [DEBUG] Looking for: \(fileName)")
            
            guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
                print("   ❌ Not found: \(fileName)")
                continue
            }
            
            print("   ✅ Found: \(url.path)")
            
            guard let data = try? Data(contentsOf: url) else {
                print("   ❌ Failed to read data from file")
                continue
            }
            
            print("   📦 Data size: \(data.count) bytes")
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("   ❌ Failed to parse JSON")
                continue
            }
            
            print("   ✅ JSON parsed successfully")
            
            // Parse template JSON
            guard let eventType = json["eventType"] as? String,
                  let experienceLevel = json["experienceLevel"] as? String,
                  let weekDuration = json["weekDuration"] as? Int,
                  let weeksArray = json["weeks"] as? [[String: Any]] else {
                print("   ⚠️ [TemplateManager] Invalid JSON structure in \(fileName)")
                continue
            }
            
            // Create EventTemplate
            let template = EventTemplate(
                eventType: eventType,
                experienceLevel: experienceLevel,
                weekDuration: weekDuration
            )
            
            template.minRunningCapability = json["minRunningCapability"] as? String ?? ""
            template.maxRunningCapability = json["maxRunningCapability"] as? String ?? ""
            template.requiresRecentRace = json["requiresRecentRace"] as? Bool ?? false
            template.requiresStrengthBase = json["requiresStrengthBase"] as? Bool ?? false
            template.templateDescription = json["description"] as? String ?? ""
            
            // Store phases
            if let phases = json["phases"] as? [String: [Int]],
               let phasesData = try? JSONSerialization.data(withJSONObject: phases),
               let phasesString = String(data: phasesData, encoding: .utf8) {
                template.phasesJSON = phasesString
            }
            
            // Store full plan
            if let weeksData = try? JSONSerialization.data(withJSONObject: weeksArray),
               let weeksString = String(data: weeksData, encoding: .utf8) {
                template.fullPlanJSON = weeksString
            }
            
            modelContext.insert(template)
            loadedCount += 1
            print("   ✅ [TemplateManager] Loaded: \(fileName)")
        }
        
        // Save all templates to database
        try? modelContext.save()
        print("✅ [TemplateManager] Loaded \(loadedCount) templates into database")
    }
    
    // MARK: - Find Best Template
    
    static func findBestTemplate(
        eventType: String,
        assessment: UserCapabilityAssessment,
        weekDuration: Int,
        modelContext: ModelContext
    ) -> EventTemplate? {
        
        let descriptor = FetchDescriptor<EventTemplate>(
            predicate: #Predicate { $0.eventType == eventType }
        )
        
        guard let allTemplates = try? modelContext.fetch(descriptor) else {
            print("❌ [TemplateManager] Failed to fetch templates")
            return nil
        }
        
        print("🔍 [TemplateManager] Found \(allTemplates.count) templates for \(eventType)")
        
        var bestMatch: EventTemplate?
        var bestScore = -999 // Allow negative scores
        
        for template in allTemplates {
            let score = scoreTemplate(
                template: template,
                assessment: assessment,
                weekDuration: weekDuration
            )
            
            print("   📊 \(template.experienceLevel) (\(template.weekDuration)w) - Score: \(score)")
            
            if score > bestScore {
                bestScore = score
                bestMatch = template
            }
        }
        
        if let match = bestMatch {
            let confidence = getConfidenceLevel(score: bestScore)
            print("✅ [TemplateManager] Best match: \(match.experienceLevel) \(match.eventType)")
            print("   🎯 Confidence: \(confidence) (Score: \(bestScore))")
        } else {
            print("❌ [TemplateManager] No suitable template found")
        }
        
        return bestMatch
    }
    
    // MARK: - Score Template
    
    private static func scoreTemplate(
        template: EventTemplate,
        assessment: UserCapabilityAssessment,
        weekDuration: Int
    ) -> Int {
        var score = 0
        
        // Running capability match (50 points)
        let userCapability = assessment.runningCapability
        let capabilityOrder = ["cannot_run_10min", "10_15min", "20_30min", "30_45min", "45_60min", "60plus"]
        
        if let userIndex = capabilityOrder.firstIndex(of: userCapability),
           let minIndex = capabilityOrder.firstIndex(of: template.minRunningCapability),
           let maxIndex = capabilityOrder.firstIndex(of: template.maxRunningCapability) {
            
            if userIndex >= minIndex && userIndex <= maxIndex {
                score += 50 // Perfect capability match
            } else if userIndex == minIndex - 1 || userIndex == maxIndex + 1 {
                score += 25 // Adjacent capability (one level off)
            } else {
                // Penalty for being far from capability range
                let distance = min(abs(userIndex - minIndex), abs(userIndex - maxIndex))
                score -= (distance * 10)
            }
        }
        
        // Week duration match (30 points)
        let weekDiff = abs(weekDuration - template.weekDuration)
        if weekDiff == 0 {
            score += 30 // Perfect duration match
        } else if weekDiff <= 2 {
            score += 20 // Close duration match
        } else if weekDiff <= 4 {
            score += 10 // Acceptable duration match
        } else {
            // Slight penalty for requiring large bridge plan
            score -= (weekDiff - 4) * 2
        }
        
        // Recent race experience (20 points)
        if template.requiresRecentRace {
            let hasRelevantRace = assessment.recentRaces.contains { race in
                race.contains(template.eventType) || 
                (template.eventType == "half_marathon" && race.contains("10k")) ||
                (template.eventType == "marathon" && race.contains("half_marathon"))
            }
            if hasRelevantRace {
                score += 20 // Has required race experience
            } else {
                score -= 15 // Missing required race experience
            }
        } else {
            score += 10 // Bonus for beginner-friendly templates
        }
        
        return score
    }
    
    // MARK: - Confidence Level
    
    private static func getConfidenceLevel(score: Int) -> String {
        switch score {
        case 80...Int.max: return "Perfect Match"
        case 50...79: return "Good Match"
        case 20...49: return "Acceptable Match"
        default: return "Fallback Match"
        }
    }
}

// MARK: - Template Matching Criteria
struct TemplateCriteria: Codable {
    let runningCapability: String?
    let recentRaces: [String]?
    let strengthFrequency: [String]?
    let weekDuration: [Int]?
}