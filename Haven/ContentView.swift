import SwiftUI
import SwiftData

// Brand Colors
extension Color {
    static let atlasPrimary = Color(hex: "#5BA4A4")      // Teal (main)
    static let atlasAccent = Color(hex: "#E07856")       // Coral (warm complement)
    static let atlasBackground = Color(hex: "#1C1C1E")   // Dark background
    static let atlasText = Color.white                   // White text
    static let atlasTextMuted = Color(hex: "#8E8E93")    // iOS system gray
    static let atlasAmber = Color(hex: "#FFC26A")
    static let atlasCardDark = Color(hex: "#1F1F23")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Query private var profiles: [UserProfile]
    @State private var showDataCollection = false
    
    var userProfile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        MainTabView()
            .preferredColorScheme(.dark)
    }
    
    var welcomeScreen: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                Image("atlasLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                
                Text("atlas")
                    .font(.system(size: 42, weight: .light))
                    .foregroundColor(.atlasText)
                    .tracking(4)
                
                Text("Build sustainable longevity habits\nwith evidence-based coaching")
                    .font(.system(size: 16, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.atlasTextMuted)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
                
                Spacer()
                
                Button(action: {
                    showDataCollection = true
                }) {
                    Text("Get Started")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.atlasBackground)
                        .tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.atlasPrimary)
                        .cornerRadius(2)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(PurchaseManager.shared)
        .preferredColorScheme(.dark)
}