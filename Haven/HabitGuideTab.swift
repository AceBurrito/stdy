import SwiftUI
import SwiftData

struct HabitGuideTab: View {
    let habit: Habit
    
    // Check if this is a user-input habit (skill practice / creative flow)
    private var isUserInputHabit: Bool {
        habit.interventionId == "daily_skill_practice" || habit.interventionId == "creative_flow_time"
    }
    
    private var hasGuide: Bool {
        guard let guide = habit.howToGuide, !guide.isEmpty else { return false }
        return true
    }
    
    private var hasCitation: Bool {
        guard let citation = habit.researchCitation, !citation.isEmpty else { return false }
        return true
    }
    
    // Check if guide mentions YouTube, apps, or resources
    private var hasVideoRecommendations: Bool {
        guard let guide = habit.howToGuide else { return false }
        return guide.lowercased().contains("youtube") ||
               guide.lowercased().contains("video") ||
               guide.lowercased().contains("apps:")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Why This Matters — always shown
                whySection
                
                // How to Do It — hidden for user-input habits, shown when guide exists
                if !isUserInputHabit && hasGuide {
                    howToSection
                }
                
                // Resource recommendations (if guide mentions YouTube/apps)
                if hasVideoRecommendations {
                    resourcesSection
                }
                
                // Research citation
                if hasCitation {
                    researchSection
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Why This Matters
    
    private var whySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why This Matters")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.atlasText)
            
            Text(whyText)
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)
                .lineSpacing(6)
        }
    }
    
    // Pull from intervention library for richer "why" text, fallback to habit.details
    private var whyText: String {
        if let id = habit.interventionId,
           let intervention = InterventionLibrary.allInterventions.first(where: { $0.id == id }) {
            return intervention.whyTemplate
        }
        return habit.details.isEmpty ? "This habit supports your longevity goals." : habit.details
    }
    
    // MARK: - How to Do It
    
    private var howToSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Do It")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.atlasText)
            
            Text(habit.howToGuide ?? "")
                .font(.system(size: 15))
                .foregroundColor(.atlasTextMuted)
                .lineSpacing(6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
    
    // MARK: - Resources
    
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Helpful Resources")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.atlasText)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(extractResources(), id: \.self) { resource in
                    ResourceRow(resource: resource)
                }
            }
        }
    }
    
    // MARK: - Research
    
    private var researchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Research")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.atlasText)
            
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasPrimary)
                    .padding(.top, 2)
                
                Text(habit.researchCitation ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                    .lineSpacing(4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.atlasPrimary.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Helpers
    
    private func extractResources() -> [String] {
        guard let guide = habit.howToGuide else {
            return ["Search '\(habit.title) tutorial' on YouTube"]
        }
        
        var resources: [String] = []
        let lines = guide.components(separatedBy: "\n")
        for line in lines {
            if line.lowercased().contains("youtube:") ||
               line.lowercased().contains("apps:") ||
               line.lowercased().contains("recommended:") {
                resources.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        return resources.isEmpty ? ["Search '\(habit.title) tutorial' on YouTube"] : resources
    }
}

// MARK: - Resource Row
struct ResourceRow: View {
    let resource: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconForResource)
                .font(.system(size: 14))
                .foregroundColor(.atlasPrimary)
                .frame(width: 20)
            
            Text(resource)
                .font(.system(size: 14))
                .foregroundColor(.atlasText)
            
            Spacer()
            
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12))
                .foregroundColor(.atlasTextMuted)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }
    
    private var iconForResource: String {
        let lowercased = resource.lowercased()
        if lowercased.contains("youtube") || lowercased.contains("video") {
            return "play.rectangle.fill"
        } else if lowercased.contains("app") {
            return "app.fill"
        } else {
            return "link"
        }
    }
}

#Preview {
    let habit = Habit(
        title: "Morning Sunlight",
        details: "Morning sunlight exposure anchors your circadian rhythm.",
        pillar: "Sleep",
        howToGuide: "Step outside for 10 minutes within 1 hour of waking. Face east if possible. No sunglasses. Cloudy days still effective.",
        researchCitation: "Zeitzer et al. (2000) - Light exposure and circadian rhythms: PMID 10742677",
        interventionId: "morning_sunlight_exposure"
    )
    
    HabitGuideTab(habit: habit)
        .background(Color.atlasBackground)
}
